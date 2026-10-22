import SwiftUI
import UIKit

/// Observe the keyboard in the dock's own window without disabling keyboard avoidance
/// for page content. A docked keyboard replaces the bottom navigation, not the page's
/// search field or its keyboard toolbar.
struct DockKeyboardObserver: UIViewRepresentable {
  var changed: (Bool) -> Void

  func makeUIView(context: Context) -> Probe {
    Probe(changed: changed)
  }

  func updateUIView(_ view: Probe, context: Context) {
    view.changed = changed
  }

  static func dismantleUIView(_ view: Probe, coordinator: ()) {
    view.stop()
  }

  static func coversBottom(_ keyboard: CGRect, in bounds: CGRect) -> Bool {
    let overlap = keyboard.intersection(bounds)
    return !overlap.isEmpty && overlap.maxY >= bounds.maxY - 1
      && overlap.width >= bounds.width * 0.8
  }

  final class Probe: UIView {
    var changed: (Bool) -> Void
    private var observers: [NSObjectProtocol] = []

    init(changed: @escaping (Bool) -> Void) {
      self.changed = changed
      super.init(frame: .zero)
      isUserInteractionEnabled = false
      for name in [UIResponder.keyboardWillChangeFrameNotification,
        UIResponder.keyboardDidChangeFrameNotification, UIResponder.keyboardDidHideNotification,
        UIApplication.didEnterBackgroundNotification] {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
          [weak self] notification in
          let isLocal = notification.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool != false
          let isHiding = notification.name == UIResponder.keyboardDidHideNotification
            || notification.name == UIApplication.didEnterBackgroundNotification
          let isChanging = notification.name == UIResponder.keyboardWillChangeFrameNotification
          let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
          MainActor.assumeIsolated {
            self?.receive(frame: frame, isLocal: isLocal, isHiding: isHiding, isChanging: isChanging)
          }
        })
      }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    isolated deinit { stop() }

    func stop() {
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
    }

    private func receive(frame: CGRect?, isLocal: Bool, isHiding: Bool, isChanging: Bool) {
      guard let window, isLocal else { return }
      guard !isHiding else {
        changed(false)
        return
      }
      guard window.isKeyWindow, let frame else { return }
      let local = window.convert(frame, from: window.screen.coordinateSpace)
      let covered = DockKeyboardObserver.coversBottom(local, in: window.bounds)
      // Hide before presentation, but return only once dismissal has actually finished.
      if covered || !isChanging { changed(covered) }
    }
  }
}
