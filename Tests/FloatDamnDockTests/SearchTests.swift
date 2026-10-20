@testable import FloatDamnDock
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

/// The field the page shows, as a style gets it
@MainActor
private final class FieldRecorder {
  var field: FloatDamnDockSearchField?
}

private struct RecordingFieldStyle: FloatDamnDockSearchFieldStyle {
  let recorder: FieldRecorder

  func makeBody(configuration: FloatDamnDockSearchField) -> some View {
    recorder.field = configuration
    return Color.clear.frame(height: 10)
  }
}

/// A page that offers its search under a shell's search controller, as the shell runs it
private struct SearchHarness: View {
  @Bindable var model: SearchModel
  let controller: DockSearchController
  let recorder: FieldRecorder
  var isOpenTab = true

  var body: some View {
    let section = model.searchesLists ? "lists" : "games"
    Color.clear
      .floatDamnDockSearch(
        "Search", text: model.searchesLists ? $model.lists : $model.games, source: model,
        onFocusChange: { _ in model.focusChanges.append(section) }
      )
      .environment(\.dockTabIsOpen, isOpenTab)
      .onPreferenceChange(DockSearchKey.self) { controller.offer($0) }
      .environment(\.dockSearchController, controller)
      .floatDamnDockSearchFieldStyle(RecordingFieldStyle(recorder: recorder))
  }
}

@MainActor
struct SearchTests {
  private func settle() async {
    for _ in 0..<5 {
      try? await Task.sleep(for: .milliseconds(50))
    }
  }

  private func host(_ view: some View) -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
    window.rootViewController = UIHostingController(rootView: view)
    window.makeKeyAndVisible()
    return window
  }

  @Test func fieldUsesTheBindingAndCallbackThePageGaveLast() async throws {
    let model = SearchModel()
    let controller = DockSearchController()
    let recorder = FieldRecorder()
    let window = host(SearchHarness(model: model, controller: controller, recorder: recorder))
    defer { window.isHidden = true }
    await settle()
    #expect(recorder.field == nil)

    controller.open()
    await settle()
    let first = try #require(recorder.field)
    first.text.wrappedValue = "zelda"
    #expect(model.games == "zelda")

    // Same source, another query and another callback: the field follows them
    model.searchesLists = true
    await settle()
    let field = try #require(recorder.field)
    field.text.wrappedValue = "favorites"
    #expect(model.lists == "favorites")
    #expect(model.games == "zelda")

    field.focusChanged(true)
    #expect(model.focusChanges.last == "lists")

    // Losing focus puts the bar back
    field.focusChanged(false)
    #expect(!controller.isSearching)
  }

  @Test func hiddenTabShowsNoField() async {
    let model = SearchModel()
    let controller = DockSearchController()
    let recorder = FieldRecorder()
    let window = host(SearchHarness(model: model, controller: controller, recorder: recorder, isOpenTab: false))
    defer { window.isHidden = true }
    await settle()

    controller.offer(DockSearch(source: ObjectIdentifier(model), prompt: "Search"))
    controller.open()
    await settle()
    #expect(recorder.field == nil)
  }

  @Test func anotherSearchClosesTheField() {
    let controller = DockSearchController()
    // Both sources stay alive, so their identifiers differ
    let games = SearchModel(), lists = SearchModel()
    let first = DockSearch(source: ObjectIdentifier(games), prompt: "Games")
    controller.offer(first)
    controller.open()
    #expect(controller.shows(first.source))

    controller.offer(DockSearch(source: ObjectIdentifier(lists), prompt: "Lists"))
    #expect(!controller.isSearching)
    controller.offer(nil)
    controller.open()
    #expect(!controller.isSearching)
  }
}
