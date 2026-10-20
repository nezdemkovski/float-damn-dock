import SwiftUI

/// Everything about the bar that can be tuned, each with a default: its colors, its metrics,
/// its motion, and how the finger's slide behaves. Set it once over the bar (or the whole app)
/// with `floatDamnDockStyle(_:)`, changing only what differs:
///
/// ```swift
/// extension FloatDamnDockStyle {
///   static var brand: Self {
///     var style = Self()
///     style.colors.highlight = .white.opacity(0.14)
///     style.metrics.height = 56
///     style.scrub.holdDuration = .milliseconds(300)
///     return style
///   }
/// }
/// ```
public struct FloatDamnDockStyle: Sendable {
  public var colors = Colors()
  public var metrics = Metrics()
  public var motion = Motion()
  public var scrub = Scrub()

  public init() {}

  public struct Colors: Sendable {
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

    public init() {}
  }

  public struct Metrics: Sendable {
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
    /// The unread dot, and where it sits from the icon's top trailing corner
    public var badgeDotSize: CGFloat = 8
    public var badgeDotOffset = CGSize(width: 4, height: -3)
    /// Between the open overflow tab's icon and the chevrons beside it
    public var overflowIconSpacing: CGFloat = 7
    public var menuRowHeight: CGFloat = 44
    public var menuRowSpacing: CGFloat = 2
    /// The size of a menu row's title at the default Dynamic Type size; it scales with it
    public var menuLabelSize: CGFloat = 17
    /// The column a menu row's icon sits in, and the space after it
    public var menuIconWidth: CGFloat = 22
    public var menuIconSpacing: CGFloat = 12
    public var menuPadding: CGFloat = 8

    public init() {}

    /// The space the bar takes at the foot of the pages, with its padding
    public var dockHeight: CGFloat { height + 2 * verticalPadding }
  }

  public struct Motion: Sendable {
    /// A tap on the last slot first presses the pill down toward it, this far
    public var press: Animation = .easeOut(duration: 0.06)
    public var pressedScale = CGSize(width: 0.84, height: 0.55)
    /// The pill growing into the menu after a tap, and under a finger still down
    public var menuOpen: Animation = .spring(duration: 0.38, bounce: 0.12)
    public var menuOpenUnderFinger: Animation = .smooth(duration: 0.28)
    public var menuClose: Animation = .smooth(duration: 0.24)
    /// The bar's icons leaving as the menu opens, and coming back a beat after it folds
    public var iconsFade: Animation = .easeOut(duration: 0.12)
    public var iconsReturnDelay: TimeInterval = 0.06
    public var iconsBlur: CGFloat = 4
    /// The menu's rows: in from the top one after another as it opens, out together as it
    /// folds
    public var rowsIn: Animation = .easeOut(duration: 0.16)
    public var rowsOut: Animation = .easeOut(duration: 0.1)
    public var headerDelay: TimeInterval = 0.04
    public var firstRowDelay: TimeInterval = 0.06
    public var rowStagger: TimeInterval = 0.018
    public var rowsBlur: CGFloat = 3
    /// The pages dimming under the open menu
    public var scrim: Animation = .easeOut(duration: 0.2)
    /// The search button coming and going with the page's search
    public var searchButton: Animation = .smooth(duration: 0.25)

    public init() {}
  }

  public struct Scrub: Sendable {
    /// How long a finger rests on a tab, or a row of the menu, before it opens there without
    /// lifting (and the last slot unfolds the menu)
    public var holdDuration: Duration = .milliseconds(250)
    /// How long a finger stays still before the highlight and the light show under it, so a
    /// quick tap does not flash them
    public var feedbackDelay: Duration = .milliseconds(120)
    /// A slide shorter than this is still a tap
    public var tapSlop: CGFloat = 8
    /// After a hold, the finger has to slide this far before it moves the highlight again
    public var restSlop: CGFloat = 12
    /// The highlight riding under the finger, and lifting a little while it is held
    public var highlightRide: Animation = .spring(duration: 0.22, bounce: 0)
    public var highlightLift: Animation = .easeOut(duration: 0.1)
    public var highlightBrightness: Double = 0.035
    public var highlightShadowOpacity: Double = 0.16
    public var highlightShadowRadius: CGFloat = 5
    /// The soft light under the finger: its reach, its strength at the center, and its fade
    public var lightRadius: CGFloat = 130
    public var lightIntensity: Double = 0.09
    public var lightFade: Animation = .easeOut(duration: 0.3)

    public init() {}
  }
}

/// The words the bar says itself, for assistive technologies and its search button.
/// The defaults are English; pass localized ones with `floatDamnDockLabels(_:)`.
public struct FloatDamnDockLabels: Sendable {
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
  @Entry public var floatDamnDockStyle = FloatDamnDockStyle()
  @Entry public var floatDamnDockLabels = FloatDamnDockLabels()
  /// The space the bottom bar covers at the foot of the pages. Scrolling pages run under it,
  /// behind the scroll-edge blur; a fixed canvas reserves it.
  @Entry public var floatDamnDockClearance: CGFloat = 0
}

extension View {
  public func floatDamnDockStyle(_ style: FloatDamnDockStyle) -> some View {
    environment(\.floatDamnDockStyle, style)
  }

  public func floatDamnDockLabels(_ labels: FloatDamnDockLabels) -> some View {
    environment(\.floatDamnDockLabels, labels)
  }
}
