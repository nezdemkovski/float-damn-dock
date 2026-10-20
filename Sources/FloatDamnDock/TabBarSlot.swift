import SwiftUI

/// One icon of a floating bar; the highlight under the open one is the group's, so it can
/// ride under a finger
struct TabBarSlot: View {
  let item: FloatDamnDockItem
  let identifier: String
  let active: Bool
  var hidden = false
  let action: () -> Void
  @Environment(\.floatDamnDockStyle) private var style

  private var dot: Bool { item.badge > 0 }

  var body: some View {
    Button(action: action) {
      Image(systemName: item.systemImage)
        .font(.system(size: style.metrics.iconSize, weight: .medium))
        .symbolVariant(active ? .fill : .none)
        .foregroundStyle(active ? style.colors.label : style.colors.secondaryLabel)
        // Something waiting: the dot on the icon's shoulder
        .overlay(alignment: .topTrailing) {
          if dot {
            Circle().fill(style.colors.badge)
              .frame(width: style.metrics.badgeDotSize, height: style.metrics.badgeDotSize)
              .offset(style.metrics.badgeDotOffset)
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
