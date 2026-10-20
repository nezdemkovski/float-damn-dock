import SwiftUI

/// A round glass button beside a bar: the page's search, the app's accessory. Its
/// accessibility identifier is `tabbar.<identifier>`.
struct GlassCircleButton: View {
  let title: String
  let systemImage: String
  let identifier: String
  /// Hidden, it keeps its place (see `glassVisibility`)
  var visible = true
  /// The animation a hide plays in, ahead of whatever else changes with it
  var hideAnimation: Animation?
  let namespace: Namespace.ID
  let action: () -> Void
  @Environment(\.floatDamnDockStyle) private var style

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: style.metrics.buttonIconSize, weight: .regular))
        .foregroundStyle(style.colors.label)
        .frame(width: style.metrics.height, height: style.metrics.height)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .glassVisibility(visible, in: .circle, hideAnimation: hideAnimation)
    .accessibilityLabel(title)
    .glassEffectID(identifier, in: namespace)
    // Standalone buttons fade in place; only the navigation surface morphs.
    .glassEffectTransition(.identity)
    .accessibilityIdentifier("tabbar.\(identifier)")
  }
}

extension View {
  /// Interactive glass that can be hidden in place. Native glass renders outside ordinary
  /// opacity, so hiding takes the material away along with the content; a hidden view takes
  /// no touches and is gone for assistive technologies, but keeps its layout, so the glass
  /// around it does not move. `hideAnimation` replaces the animation of the hide itself.
  func glassVisibility(_ visible: Bool, in shape: some Shape, hideAnimation: Animation? = nil) -> some View {
    opacity(visible ? 1 : 0)
      .glassEffect(visible ? .regular.interactive() : .identity, in: shape)
      .allowsHitTesting(visible)
      .accessibilityHidden(!visible)
      .transaction { transaction in
        if !visible { transaction.animation = hideAnimation }
      }
  }
}
