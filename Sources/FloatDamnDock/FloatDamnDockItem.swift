import SwiftUI

/// How a tab shows in the bar and the menu
public struct FloatDamnDockItem {
  public var title: String
  /// An SF Symbol; the open tab shows its fill variant
  public var systemImage: String
  /// Something waiting in the tab: a dot on its icon in the bar, the count in the menu
  public var badge: Int
  /// What the dot says to VoiceOver; the count when nil
  public var badgeLabel: String?

  public init(_ title: String, systemImage: String, badge: Int = 0, badgeLabel: String? = nil) {
    self.title = title
    self.systemImage = systemImage
    self.badge = badge
    self.badgeLabel = badgeLabel
  }
}

/// Where the bar stands
public enum FloatDamnDockPlacement: Sendable {
  /// Along the bottom at compact width, at the side at regular width
  case automatic
  /// A pill along the bottom whose last slot unfolds the menu
  case bottom
  /// Stood up at the side of the pages, every tab in it
  case side
}

/// A round glass button beside the bar, for the app's main action
struct DockAccessory {
  let title: String
  let systemImage: String
  let identifier: String
  let action: () -> Void
}

/// The row on top of the menu (who is signed in, say), a way somewhere that is not a tab
struct DockMenuHeader {
  let title: String
  let identifier: String
  let action: () -> Void
  let label: AnyView
}

/// Everything the bars know beyond the selection, handed down from `FloatDamnDockView`
struct TabBarModel<Tab: Hashable> {
  var pinned: [Tab]
  var menu: [Tab]
  var item: (Tab) -> FloatDamnDockItem
  var onReselect: ((Tab) -> Void)?
  var accessory: DockAccessory?
  var menuHeader: DockMenuHeader?

  /// Opens the tab; the open tab's own slot calls `onReselect` (back to its root, say)
  func open(_ tab: Tab, selection: Binding<Tab>) {
    if selection.wrappedValue == tab {
      onReselect?(tab)
    } else {
      selection.wrappedValue = tab
    }
  }

  /// The tab's accessibility identifier suffix
  static func identifier(_ tab: Tab) -> String { String(describing: tab) }
}
