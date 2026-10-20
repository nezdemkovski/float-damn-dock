import SwiftUI

/// What a view is to the dock's layout
enum DockRole {
  case pill, search, accessory
}

private struct DockRoleKey: LayoutValueKey {
  static let defaultValue = DockRole.accessory
}

extension View {
  func dockRole(_ role: DockRole) -> some View {
    layoutValue(key: DockRoleKey.self, value: role)
  }
}

/// The bottom dock: the pill takes the width the round buttons leave it, everything stands on
/// the bottom edge (the pill grows upward into the menu). The pill's slots keep one width
/// whether or not the page has a search: when the search button takes a place, the last
/// pinned tab leaves the pill, and its slot with the gap after it is shared between the
/// search button and the two equal gaps around it. Otherwise the search button sits hidden
/// at the pill's end, so it fades in and out in place.
struct DockLayout: Layout {
  /// The pill's slots at full width: the pinned tabs and the last slot
  let slots: Int
  /// The search button takes a slot's place
  let searchTakesSlot: Bool
  let inset: CGFloat
  let gap: CGFloat
  /// The round buttons' size
  let button: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? CGFloat(slots) * button
    let height = frames(width: width, subviews: subviews).map(\.height).max() ?? 0
    return CGSize(width: width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for (subview, frame) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.maxY - frame.height),
        proposal: ProposedViewSize(frame.size)
      )
    }
  }

  private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
    let roles = subviews.map { $0[DockRoleKey.self] }
    return spans(width: width, roles: roles).enumerated().map { index, span in
      // The pill grows upward into the menu; the round buttons keep their size
      let height = roles[index] == .pill
        ? subviews[index].sizeThatFits(ProposedViewSize(width: span.width, height: nil)).height
        : button
      return CGRect(x: span.x, y: 0, width: span.width, height: height)
    }
  }

  /// Where each view sits along the dock, in order: its leading edge and its width
  func spans(width: CGFloat, roles: [DockRole]) -> [(x: CGFloat, width: CGFloat)] {
    let accessories = CGFloat(roles.filter { $0 == .accessory }.count)
    let searchTakes = searchTakesSlot && roles.contains(.search)
    let slot = (width - accessories * (button + gap) - 2 * inset) / CGFloat(max(slots, 1))
    // The freed slot and its gap hold the search button between two equal gaps
    let spacing = searchTakes ? max(0, (slot + gap - button) / 2) : gap
    let pill = width - accessories * (button + spacing) - (searchTakes ? button + spacing : 0)

    var x: CGFloat = 0
    return roles.map { role in
      switch role {
      case .pill:
        defer { x += pill }
        return (x, pill)
      case .search where searchTakes:
        x += spacing
        defer { x += button }
        return (x, button)
      case .search:
        // Hidden under the pill's end, taking no width
        return (x - button, button)
      case .accessory:
        x += spacing
        defer { x += button }
        return (x, button)
      }
    }
  }
}
