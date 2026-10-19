import SwiftUI

/// One icon of a floating bar; the highlight under the open one is the group's, so it can
/// ride under a finger
struct TabBarSlot: View {
  let item: FloatingTabItem
  let identifier: String
  let active: Bool
  var hidden = false
  let action: () -> Void
  @Environment(\.floatingTabBarStyle) private var style

  private var dot: Bool { item.badge > 0 }

  var body: some View {
    Button(action: action) {
      Image(systemName: item.systemImage)
        .font(.system(size: style.iconSize, weight: .medium))
        .symbolVariant(active ? .fill : .none)
        .foregroundStyle(active ? style.label : style.secondaryLabel)
        // Something waiting: the dot on the icon's shoulder
        .overlay(alignment: .topTrailing) {
          if dot {
            Circle().fill(style.badge).frame(width: 8, height: 8)
              .offset(x: 4, y: -3)
              .transition(.scale.combined(with: .opacity))
          }
        }
        .animation(.snappy, value: dot)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(item.title)
    .accessibilityValue(dot ? item.badgeLabel ?? item.badge.formatted() : "")
    .accessibilityAddTraits(active ? .isSelected : [])
    .accessibilityIdentifier("tabbar.\(identifier)")
    .accessibilityHidden(hidden)
  }
}
