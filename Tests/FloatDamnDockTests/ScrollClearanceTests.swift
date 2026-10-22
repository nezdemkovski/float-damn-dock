@testable import FloatDamnDock
import SwiftUI
import Testing
import UIKit

@MainActor @Observable private final class ScrollModel {
  var path: [Int] = []
}

private struct EndMarker: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.tag = 38197
    return view
  }
  func updateUIView(_ view: UIView, context: Context) {}
}

private struct ScrollingPage: View {
  var list = false
  var body: some View {
    if list {
      List {
        ForEach(0..<40) { Text("Row \($0)").frame(height: 50) }
        EndMarker().frame(height: 30)
      }
    } else {
      ScrollView {
        VStack {
          ScrollView(.horizontal) { Color.red.frame(width: 1200, height: 50) }.frame(height: 60)
          ForEach(0..<40) { Text("Row \($0)").frame(height: 50) }
          EndMarker().frame(height: 30)
        }
      }
    }
  }
}

private struct ClearanceHarness: View {
  @Bindable var model: ScrollModel
  var navigation = true
  var body: some View {
    FloatDamnDockView(selection: .constant(0), pinned: [0], menu: [0]) { _ in
      FloatDamnDockItem("Home", systemImage: "house")
    } page: { _ in
      if navigation {
        NavigationStack(path: $model.path) {
          ScrollingPage().navigationDestination(for: Int.self) { _ in ScrollingPage(list: true) }
        }
      } else {
        ScrollingPage()
      }
    }
    .placement(.bottom)
  }
}

@MainActor @Suite("Scroll clearance", .serialized)
struct ScrollClearanceTests {
  @Test func lastContentClearsDockOnRootAndPushedPages() async throws {
    let model = ScrollModel()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = UIHostingController(rootView: ClearanceHarness(model: model))
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    try await Task.sleep(for: .milliseconds(500))
    await check(window, page: "root")
    let horizontal = descendants(window).compactMap { $0 as? UIScrollView }
      .first { $0.contentSize.width > $0.bounds.width + 100 }
    #expect(horizontal != nil)
    #expect((horizontal?.contentInset.bottom ?? 0) < 2, "Nested horizontal rails must not gain dock padding")
    #expect((horizontal?.contentSize.height ?? 0) <= 60, "Nested rail content must keep its own height")
    model.path.append(1)
    try await Task.sleep(for: .milliseconds(500))
    await check(window, page: "pushed List")
  }

  @Test func plainAndNavigationPagesUseCustomDockHeightExactlyOnce() async throws {
    var style = FloatDamnDockStyle()
    style.metrics.height = 72
    style.metrics.verticalPadding = 14
    for navigation in [false, true] {
      let model = ScrollModel()
      let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
      window.rootViewController = UIHostingController(rootView:
        ClearanceHarness(model: model, navigation: navigation).floatDamnDockStyle(style))
      window.makeKeyAndVisible()
      defer { window.isHidden = true }
      try await Task.sleep(for: .milliseconds(400))
      await check(window, page: "custom dock navigation=\(navigation)", height: style.metrics.dockHeight, exact: true)
    }
  }

  @Test func keyboardRemovesClearanceAndRestoresItAfterDismissal() async throws {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = UIHostingController(rootView: ClearanceHarness(model: ScrollModel()))
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    try await Task.sleep(for: .milliseconds(400))
    window.makeKey()
    NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
      userInfo: [UIResponder.keyboardFrameEndUserInfoKey: CGRect(x: 0, y: 530, width: 402, height: 344)])
    try await Task.sleep(for: .milliseconds(200))
    await check(window, page: "keyboard removes dock clearance", height: 0, exact: true)
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    try await Task.sleep(for: .milliseconds(200))
    await check(window, page: "dismissal restores dock clearance", exact: true)
  }

  private func check(_ window: UIWindow, page: String,
    height: CGFloat = FloatDamnDockStyle().metrics.dockHeight, exact: Bool = false) async {
    for _ in 0..<6 {
      for scroll in descendants(window).compactMap({ $0 as? UIScrollView })
        where scroll.contentSize.height > scroll.bounds.height + 100 {
        scroll.setContentOffset(CGPoint(x: 0, y: max(-scroll.adjustedContentInset.top,
          scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
      }
      window.layoutIfNeeded()
      try? await Task.sleep(for: .milliseconds(100))
    }
    let markers = descendants(window).filter { $0.tag == 38197 && $0.window != nil }
    let dockTop = window.bounds.maxY - window.safeAreaInsets.bottom - height
    let frames = markers.map { $0.convert($0.bounds, to: window) }
    print("CLEARANCE \(page) dockTop=\(dockTop) markers=\(frames)")
    #expect(frames.contains { $0.maxY <= dockTop + 1 && $0.maxY > 0 }, "Last row must clear dock on \(page)")
    if exact { #expect(frames.contains { abs($0.maxY - dockTop) < 2 }, "Reserve the dock exactly once on \(page)") }
  }

  private func descendants(_ view: UIView) -> [UIView] {
    [view] + view.subviews.flatMap(descendants)
  }
}
