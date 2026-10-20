@testable import FloatingTabBar
import SwiftUI
import Testing
import UIKit

@MainActor @Observable
private final class SearchModel {
  var games = ""
  var lists = ""
  /// Which query the page binds the search to; the source stays the same
  var searchesLists = false
  var focusChanges: [String] = []
}

/// What the bar hands its search field
@MainActor
private final class FieldRecorder {
  var field: FloatingTabSearchField?
}

/// A page that offers its search, and the bar's field for it, wired as the shell wires them
private struct SearchHarness: View {
  @Bindable var model: SearchModel
  let recorder: FieldRecorder
  @State private var search: FloatingTabSearch?

  var body: some View {
    let section = model.searchesLists ? "lists" : "games"
    VStack {
      Color.clear
        .frame(height: 10)
        .floatingTabBarSearch(
          "Search", text: model.searchesLists ? $model.lists : $model.games, source: model,
          onFocusChange: { _ in model.focusChanges.append(section) }
        )
      if let search {
        BarSearchField(search: search, model: barModel) {}
      }
    }
    .onPreferenceChange(FloatingTabSearchKey.self) { search = $0 }
  }

  private var barModel: TabBarModel<String> {
    TabBarModel(
      pinned: [], menu: [], item: { FloatingTabItem($0, systemImage: "circle") },
      searchField: { field in
        recorder.field = field
        return AnyView(Color.clear)
      }
    )
  }
}

@MainActor
struct SearchTests {
  private func settle() async {
    for _ in 0..<5 {
      try? await Task.sleep(for: .milliseconds(50))
    }
  }

  @Test func barFollowsTheBindingAndCallbackTheSourceHandsItLast() async throws {
    let model = SearchModel()
    let recorder = FieldRecorder()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
    window.rootViewController = UIHostingController(rootView: SearchHarness(model: model, recorder: recorder))
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    await settle()

    let first = try #require(recorder.field)
    first.text.wrappedValue = "zelda"
    #expect(model.games == "zelda")

    // Same source, another query and another callback: the bar's field follows them
    model.searchesLists = true
    await settle()
    let field = try #require(recorder.field)
    field.text.wrappedValue = "favorites"
    #expect(model.lists == "favorites")
    #expect(model.games == "zelda")
    #expect(field.text.wrappedValue == "favorites")

    field.focusChanged(true)
    #expect(model.focusChanges.last == "lists")
  }
}
