import SwiftUI

/// Every tab, in the card the bar's pill grows into: the header on top when there is one,
/// then each tab with its icon (and its count). The rows come in from the top as the card
/// opens. A finger sliding along the rows takes the highlight with it and opens the row it
/// lifts from.
struct TabMenu<Tab: Hashable>: View {
  @Binding var selection: Tab
  @Binding var unfolded: Bool
  let model: TabBarModel<Tab>
  /// Content fades in after the surface starts expanding, and out as it collapses.
  let expanded: Bool
  @Environment(\.floatingTabBarStyle) private var style
  @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private enum Item: Hashable {
    case header, tab(Tab)
  }

  private var labelSize: CGFloat { style.menuLabelSize * textScale }

  var body: some View {
    VStack(spacing: 0) {
      if let header = model.menuHeader {
        headerRow(header)
          .scrubItem(Item.header)
        Rectangle().fill(style.separator).frame(height: 1)
          .padding(.horizontal, style.menuPadding)
      }
      VStack(spacing: 2) {
        // Keep the collection stable while the menu tracks a finger.
        ForEach(model.menu.indices, id: \.self) { index in
          let tab = model.menu[index]
          row(tab, index: index)
            .scrubItem(Item.tab(tab))
        }
      }
      .padding(style.menuPadding)
    }
    .scrubGroup(
      Item.self, selected: .tab(selection), highlight: .capsule, follows: .item,
      isEnabled: unfolded, tapOnly: [.header],
      // A finger that rests on a row opens it without lifting
      holds: Set(model.menu.map(Item.tab)), onHold: { pick($0) }
    ) { pick($0) }
    .frame(maxWidth: .infinity)
    .allowsHitTesting(unfolded)
    .accessibilityElement(children: .contain)
    .accessibilityHidden(!unfolded)
  }

  private func headerRow(_ header: FloatingMenuHeader) -> some View {
    Button {
      pick(.header)
    } label: {
      header.label
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(header.title)
    .accessibilityIdentifier("sections.\(header.identifier)")
    .animation(reveal(delay: 0.04)) { content in
      content.opacity(expanded ? 1 : 0)
        .blur(radius: expanded || reduceMotion ? 0 : 3)
    }
    .accessibilityHidden(!unfolded)
  }

  /// One tab; the rows fade in one after another from the top
  private func row(_ tab: Tab, index: Int) -> some View {
    let item = model.item(tab)
    let active = selection == tab
    return Button {
      pick(.tab(tab))
    } label: {
      HStack(spacing: 12) {
        Image(systemName: item.systemImage)
          .font(.system(size: style.iconSize - 1, weight: .medium))
          .symbolVariant(active ? .fill : .none)
          .frame(width: 22)
        Text(item.title).font(.system(size: labelSize, weight: .medium))
        Spacer(minLength: 8)
        if item.badge > 0 {
          Text(item.badge.formatted())
            .font(.system(.caption, weight: .bold).monospacedDigit())
            .foregroundStyle(style.onBadge)
            .padding(.horizontal, 6)
            .frame(minWidth: 21, minHeight: 21)
            .background(style.badgeFill, in: Capsule())
        }
      }
      .foregroundStyle(style.label)
      .padding(.horizontal, 14)
      .frame(minHeight: style.menuRowHeight)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(active ? .isSelected : [])
    .accessibilityValue(item.badge > 0 ? item.badge.formatted() : "")
    .accessibilityIdentifier("sections.\(TabBarModel<Tab>.identifier(tab))")
    .animation(reveal(delay: 0.06 + Double(index) * 0.018)) { content in
      content.opacity(expanded ? 1 : 0)
        .blur(radius: expanded || reduceMotion ? 0 : 3)
    }
    .accessibilityHidden(!unfolded)
  }

  private func reveal(delay: Double) -> Animation? {
    guard !reduceMotion else { return nil }
    return expanded ? .easeOut(duration: 0.16).delay(delay) : .easeOut(duration: 0.1)
  }

  /// Opens the tab (or the header's place) and folds the menu. A lift where a held finger
  /// unfolded the menu, without a slide, never reaches here: the finger only rested.
  private func pick(_ item: Item) {
    switch item {
    case .header:
      model.menuHeader?.action()
    case .tab(let tab):
      selection = tab
    }
    unfolded = false
  }
}
