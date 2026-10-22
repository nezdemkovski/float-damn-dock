@testable import FloatDamnDock
import Testing
import UIKit

@MainActor @Suite("Keyboard dock visibility", .serialized)
struct KeyboardTests {
  @Test func observerWaitsForDismissalAndStopsWhenRemoved() {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = UIViewController()
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    var changes: [Bool] = []
    let probe = DockKeyboardObserver.Probe { changes.append($0) }
    window.rootViewController?.view.addSubview(probe)
    let center = NotificationCenter.default
    func frame(_ rect: CGRect, local: Bool = true) {
      center.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil, userInfo: [
        UIResponder.keyboardFrameEndUserInfoKey: rect,
        UIResponder.keyboardIsLocalUserInfoKey: local,
      ])
    }
    let keyboard = CGRect(x: 0, y: 530, width: 402, height: 344)
    frame(keyboard, local: false)
    #expect(changes.isEmpty)
    frame(keyboard)
    #expect(changes.last == true)
    frame(CGRect(x: 0, y: 874, width: 402, height: 344))
    center.post(name: UIResponder.keyboardWillHideNotification, object: nil)
    #expect(changes.last == true)
    center.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    #expect(changes.last == false)
    frame(keyboard)
    #expect(changes.last == true)
    center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    #expect(changes.last == false)
    probe.stop()
    let count = changes.count
    frame(keyboard)
    #expect(changes.count == count)
  }

  @Test func dockedKeyboardAndAccessoryCoverBottom() {
    let window = CGRect(x: 0, y: 0, width: 402, height: 874)
    #expect(DockKeyboardObserver.coversBottom(CGRect(x: 0, y: 530, width: 402, height: 344), in: window))
    #expect(DockKeyboardObserver.coversBottom(CGRect(x: 0, y: 820, width: 402, height: 54), in: window))
    #expect(!DockKeyboardObserver.coversBottom(CGRect(x: 0, y: 874, width: 402, height: 344), in: window))
    #expect(!DockKeyboardObserver.coversBottom(.zero, in: window))
  }

  @Test func floatingAndOtherWindowKeyboardsLeaveDockAlone() {
    let window = CGRect(x: 0, y: 0, width: 800, height: 1000)
    #expect(!DockKeyboardObserver.coversBottom(CGRect(x: 300, y: 450, width: 300, height: 250), in: window))
    #expect(!DockKeyboardObserver.coversBottom(CGRect(x: 300, y: 750, width: 300, height: 250), in: window))
    #expect(!DockKeyboardObserver.coversBottom(CGRect(x: 900, y: 750, width: 800, height: 250), in: window))
  }
}
