import FloatDamnDock
import SwiftUI
import Testing
import UIKit

@MainActor @Observable
private final class Harness {
  var tab = "home"
  var placement = FloatDamnDockPlacement.bottom
  /// How many times each page's own state was created
  var created: [String: Int] = [:]
}

/// A page that counts how often its own state comes into being
private struct CountingPage: View {
  let name: String
  let harness: Harness
  @State private var seen = false

  var body: some View {
    Text(name)
      .onAppear {
        guard !seen else { return }
        seen = true
        harness.created[name, default: 0] += 1
      }
  }
}

private struct HarnessView: View {
  @Bindable var harness: Harness

  var body: some View {
    FloatDamnDockView(selection: $harness.tab, pinned: ["home", "inbox"], menu: ["home", "inbox", "more"]) { tab in
      FloatDamnDockItem(tab, systemImage: "circle")
    } page: { tab in
      CountingPage(name: tab, harness: harness)
    }
    .placement(harness.placement)
  }
}

@MainActor
struct PlacementTests {
  private func settle() async {
    for _ in 0..<5 {
      try? await Task.sleep(for: .milliseconds(50))
    }
  }

  @Test func pagesKeepTheirStateAcrossPlacements() async throws {
    let harness = Harness()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 834, height: 1194))
    window.rootViewController = UIHostingController(rootView: HarnessView(harness: harness))
    window.makeKeyAndVisible()
    await settle()

    harness.tab = "inbox"
    await settle()
    #expect(harness.created == ["home": 1, "inbox": 1])

    harness.placement = .side
    await settle()
    harness.placement = .bottom
    await settle()
    harness.tab = "home"
    await settle()

    // Both opened tabs kept the state they had: nothing was built twice
    #expect(harness.created == ["home": 1, "inbox": 1])
    window.isHidden = true
  }
}
