import SwiftUI

/// Tabs with a floating Liquid Glass bar instead of the system's. Every tab opened so far
/// stays alive under the open one, so each keeps its place.
///
/// Along the bottom, the bar is a pill of the `pinned` tabs and a last slot that unfolds
/// the `menu` (every tab, in order) by growing the pill into a card. At the side, every tab
/// of the menu stands in the bar. A finger held down slides across either with the highlight
/// riding under it, and opens what it lifts from.
///
/// ```swift
/// FloatingTabView(selection: $tab, pinned: [.home, .search, .inbox], menu: Tab.allCases) { tab in
///   FloatingTabItem(tab.title, systemImage: tab.symbol, badge: tab == .inbox ? unread : 0)
/// } page: { tab in
///   NavigationStack { page(for: tab) }
/// }
/// .accessory("New post", systemImage: "plus") { composing = true }
/// .onReselect { tab in paths[tab] = NavigationPath() }
/// .floatingTabBarStyle(style)
/// ```
///
/// Pages offer a search to the bar with `floatingTabBarSearch(_:text:source:)`.
public struct FloatingTabView<Tab: Hashable, Page: View>: View {
  @Binding private var selection: Tab
  private let page: (Tab) -> Page
  private var model: TabBarModel<Tab>
  private var placement = FloatingTabBarPlacement.automatic
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  /// - Parameters:
  ///   - pinned: the tabs in the bottom pill, in order; the open tab, if it is not one of
  ///     them, shows in the last slot
  ///   - menu: every tab, in order, as the bottom bar's menu and the side bar list them
  ///   - item: how a tab shows
  ///   - page: a tab's page, built the first time it opens
  public init(
    selection: Binding<Tab>, pinned: [Tab], menu: [Tab],
    item: @escaping (Tab) -> FloatingTabItem,
    @ViewBuilder page: @escaping (Tab) -> Page
  ) {
    _selection = selection
    self.page = page
    model = TabBarModel(pinned: pinned, menu: menu, item: item)
  }

  public var body: some View {
    switch placement {
    case .bottom: bottom
    case .side: side
    case .automatic:
      if horizontalSizeClass == .regular { side } else { bottom }
    }
  }

  private var bottom: some View {
    BottomTabShell(selection: $selection, model: model, page: page)
  }

  private var side: some View {
    SideTabShell(selection: $selection, model: model, page: page)
  }
}

extension FloatingTabView {
  /// Where the bar stands; `.automatic` follows the horizontal size class
  public func placement(_ placement: FloatingTabBarPlacement) -> Self {
    var view = self
    view.placement = placement
    return view
  }

  /// Called when the open tab's own slot is tapped again (to take its stack to the root, say)
  public func onReselect(_ action: @escaping (Tab) -> Void) -> Self {
    var view = self
    view.model.onReselect = action
    return view
  }

  /// A round glass button beside the bar, for the app's main action. Its accessibility
  /// identifier is `tabbar.<identifier>`.
  public func accessory(
    _ title: String, systemImage: String, identifier: String = "accessory", action: @escaping () -> Void
  ) -> Self {
    var view = self
    view.model.accessory = FloatingTabAccessory(title: title, systemImage: systemImage, identifier: identifier, action: action)
    return view
  }

  /// A row on top of the bottom bar's menu, over a line (who is signed in, say), for a place
  /// that is not a tab. Picking it folds the menu. Its accessibility identifier is
  /// `sections.<identifier>`.
  public func menuHeader<Label: View>(
    _ title: String, identifier: String = "header", isPresented: Bool = true,
    action: @escaping () -> Void, @ViewBuilder label: () -> Label
  ) -> Self {
    var view = self
    view.model.menuHeader = isPresented
      ? FloatingMenuHeader(title: title, identifier: identifier, action: action, label: AnyView(label()))
      : nil
    return view
  }

  /// The field the bar turns into while the open page is searched, in place of the plain
  /// glass one
  public func searchField<Field: View>(@ViewBuilder _ field: @escaping (FloatingTabSearchField) -> Field) -> Self {
    var view = self
    view.model.searchField = { AnyView(field($0)) }
    return view
  }
}

/// The pages under the bottom bar; the system's bar, which would fold extra tabs into a "More"
/// page, is not used at all
private struct BottomTabShell<Tab: Hashable, Page: View>: View {
  @Binding var selection: Tab
  let model: TabBarModel<Tab>
  let page: (Tab) -> Page
  @State private var unfolded = false
  @State private var search: FloatingTabSearch?
  /// The one finger the bar and the menu share, so a slide carries from one into the other
  @State private var scrub = ScrubSession()
  @Environment(\.floatingTabBarStyle) private var style
  @Environment(\.floatingTabBarLabels) private var labels
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    pages
      .environment(\.floatingTabBarClearance, style.dockHeight)
      // Reserve the dock's space and extend the native progressive scroll-edge blur.
      .scrollEdgeEffectStyle(.soft, for: .bottom)
      // Respect the keyboard safe area so the dock's input remains above the keyboard.
      .safeAreaBar(edge: .bottom, spacing: 0) {
        BottomBar(selection: $selection, unfolded: $unfolded, model: model, search: search)
      }
      .onPreferenceChange(FloatingTabSearchKey.self) { search = $0 }
      .scrubSession(scrub)
      .sensoryFeedback(.selection, trigger: selection)
      .sensoryFeedback(.impact(weight: .light), trigger: unfolded)
  }

  private var pages: some View {
    RetainedTabPages(selection: selection, page: page)
      // The page under the unfolded menu stands still, so a finger sliding down the menu's
      // rows is not taken for a scroll of what is behind it
      .scrollDisabled(unfolded)
      // The page dims under the unfolded menu and a tap on it folds the menu; the bar, which
      // turns into the menu, lies over this
      .overlay {
        if unfolded {
          style.scrim
            .ignoresSafeArea()
            .onTapGesture { unfolded = false }
            .transition(.opacity)
            .accessibilityLabel(labels.dismissMenu)
            .accessibilityAddTraits(.isButton)
        }
      }
      .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: unfolded)
  }
}

/// The pages with the bar stood up at their side, every tab in it, and the page's search at
/// their foot
private struct SideTabShell<Tab: Hashable, Page: View>: View {
  @Binding var selection: Tab
  let model: TabBarModel<Tab>
  let page: (Tab) -> Page
  @State private var search: FloatingTabSearch?
  @State private var searching = false
  /// The finger the bar's slide follows
  @State private var scrub = ScrubSession()

  var body: some View {
    SideBarDock(selection: $selection, model: model, search: search, searching: $searching) {
      RetainedTabPages(selection: selection, page: page)
    }
    .onPreferenceChange(FloatingTabSearchKey.self) { search = $0 }
    .scrubSession(scrub)
    .sensoryFeedback(.selection, trigger: selection)
  }
}
