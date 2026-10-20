import SwiftUI

/// The bar's look: its colors, the glass tint, and its metrics. Set it once over the bar (or
/// the whole app) with `floatingTabBarStyle(_:)`; every value has a system default.
public struct FloatingTabBarStyle: Sendable {
  // Colors

  /// Icons and titles of the open tab, menu rows, the round buttons
  public var label: Color = .primary
  /// Icons of the tabs that are not open
  public var secondaryLabel: Color = .secondary
  /// The small chevrons beside the open overflow tab's icon
  public var tertiaryLabel: Color = Color(uiColor: .tertiaryLabel)
  /// The pill under the open tab, and under a sliding finger
  public var highlight: Color = Color(uiColor: .tertiarySystemFill)
  /// The soft light that follows a sliding finger
  public var glow: Color = .white
  /// What the glass is tinted with; the opacities below say how much
  public var glassTint: Color = Color(uiColor: .systemBackground)
  public var barTintOpacity: Double = 0.08
  public var menuTintOpacity: Double = 0.48
  /// Dims the pages under the open menu
  public var scrim: Color = .black.opacity(0.25)
  /// The line under the menu's header
  public var separator: Color = Color(uiColor: .separator)
  /// The unread dot on a tab's icon
  public var badge: Color = .red
  /// The capsule behind a menu row's count, and the count itself
  public var badgeFill: Color = .red
  public var onBadge: Color = .white

  // Metrics

  /// The pill's height, and the size of the round buttons beside it
  public var height: CGFloat = 50
  /// How far the open tab's pill sits inside the bar's
  public var inset: CGFloat = 5
  /// Between the pill and the round buttons
  public var gap: CGFloat = 8
  /// The menu's corners once the pill has grown into it
  public var menuCornerRadius: CGFloat = 18
  /// From the screen's edges to the bar, along it
  public var horizontalPadding: CGFloat = 16
  /// Above and below the bar, across it
  public var verticalPadding: CGFloat = 8
  public var iconSize: CGFloat = 17
  public var buttonIconSize: CGFloat = 21
  public var menuRowHeight: CGFloat = 44
  /// The size of a menu row's title at the default Dynamic Type size; it scales with it
  public var menuLabelSize: CGFloat = 17
  public var menuPadding: CGFloat = 8

  // Timing

  /// How long a finger rests on a tab, or a row of the menu, before it opens there without
  /// lifting (and the last slot unfolds the menu)
  public var holdDuration: Duration = .milliseconds(250)

  public init() {}

  /// The space the bar takes at the foot of the pages, with its padding
  public var dockHeight: CGFloat { height + 2 * verticalPadding }
}

/// The words the bar says itself, for assistive technologies and its search button.
/// The defaults are English; pass localized ones with `floatingTabBarLabels(_:)`.
public struct FloatingTabBarLabels: Sendable {
  /// The last slot, which unfolds every tab
  public var more = "More"
  public var moreHint = "Shows every tab"
  /// The dimmed pages under the open menu, which fold it
  public var dismissMenu = "Close the menu"
  /// The round button that opens the open page's search
  public var search = "Search"
  public var closeSearch = "Close search"
  public var clearSearch = "Clear search"

  public init() {}
}

extension EnvironmentValues {
  @Entry public var floatingTabBarStyle = FloatingTabBarStyle()
  @Entry public var floatingTabBarLabels = FloatingTabBarLabels()
  /// The space the bottom bar covers at the foot of the pages. Scrolling pages run under it,
  /// behind the scroll-edge blur; a fixed canvas reserves it.
  @Entry public var floatingTabBarClearance: CGFloat = 0
}

extension View {
  public func floatingTabBarStyle(_ style: FloatingTabBarStyle) -> some View {
    environment(\.floatingTabBarStyle, style)
  }

  public func floatingTabBarLabels(_ labels: FloatingTabBarLabels) -> some View {
    environment(\.floatingTabBarLabels, labels)
  }
}
