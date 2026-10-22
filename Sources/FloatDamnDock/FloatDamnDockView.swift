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
/// FloatDamnDockView(selection: $tab, pinned: [.home, .search, .inbox], menu: Tab.allCases) { tab in
///   FloatDamnDockItem(tab.title, systemImage: tab.symbol, badge: tab == .inbox ? unread : 0)
/// } page: { tab in
///   NavigationStack { page(for: tab) }
/// }
/// .accessory("New post", systemImage: "plus") { composing = true }
/// .onReselect { tab in paths[tab] = NavigationPath() }
/// .floatDamnDockStyle(style)
/// ```
///
/// Pages offer a search to the bar with `floatDamnDockSearch(_:text:source:)`.
public struct FloatDamnDockView<Tab: Hashable, Page: View>: View {
  @Binding private var selection: Tab
  private let page: (Tab) -> Page
  private var model: TabBarModel<Tab>
  private var placement = FloatDamnDockPlacement.automatic
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  /// - Parameters:
  ///   - pinned: the tabs in the bottom pill, in order; the open tab, if it is not one of
  ///     them, shows in the last slot
  ///   - menu: every tab, in order, as the bottom bar's menu and the side bar list them
  ///   - item: how a tab shows
  ///   - page: a tab's page, built the first time it opens
  public init(
    selection: Binding<Tab>, pinned: [Tab], menu: [Tab],
    item: @escaping (Tab) -> FloatDamnDockItem,
    @ViewBuilder page: @escaping (Tab) -> Page
  ) {
    _selection = selection
    self.page = page
    model = TabBarModel(pinned: pinned, menu: menu, item: item)
  }

  public var body: some View {
    TabShell(selection: $selection, model: model, page: page, side: side)
  }

  private var side: Bool {
    switch placement {
    case .bottom: false
    case .side: true
    case .automatic: horizontalSizeClass == .regular
    }
  }
}

extension FloatDamnDockView {
  /// Where the bar stands; `.automatic` follows the horizontal size class
  public func placement(_ placement: FloatDamnDockPlacement) -> Self {
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
    view.model.accessory = DockAccessory(title: title, systemImage: systemImage, identifier: identifier, action: action)
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
      ? DockMenuHeader(title: title, identifier: identifier, action: action, label: AnyView(label()))
      : nil
    return view
  }
}

/// The pages and the bar around them, along the bottom or at the side. The pages stand in
/// the same place for both, so a change of placement (a window resized across the size
/// classes, a Duo opened or closed) keeps every opened tab and its state; only the bar and
/// what goes with it come and go. The system's bar, which would fold extra tabs into a "More"
/// page, is not used at all.
private struct TabShell<Tab: Hashable, Page: View>: View {
  @Binding var selection: Tab
  let model: TabBarModel<Tab>
  let page: (Tab) -> Page
  let side: Bool
  @State private var unfolded = false
  @State private var keyboardVisible = false
  /// The open page's search, handed down to the pages, which show its field
  @State private var search = DockSearchController()
  /// The one finger the bar and the menu share, so a slide carries from one into the other
  @State private var scrub = ScrubSession()
  @Environment(\.floatDamnDockStyle) private var style
  @Environment(\.floatDamnDockLabels) private var labels
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 0) {
      pages
        .overlay {
          if side { SideBarHosting(host: .column) { sideBar } }
        }
      if side { SideBarHosting(host: .beside) { sideBar } }
    }
    .background { DockKeyboardObserver { keyboardVisible = $0 }.allowsHitTesting(false) }
    .onChange(of: keyboardVisible) {
      if keyboardVisible { unfolded = false }
    }
    .onPreferenceChange(DockSearchKey.self) { search.offer($0) }
    .onChange(of: side) {
      unfolded = false
      search.close()
    }
    .scrubSession(scrub)
    .sensoryFeedback(.selection, trigger: selection)
    .sensoryFeedback(.impact(weight: .light), trigger: unfolded)
  }

  private var pages: some View {
    RetainedTabPages(selection: selection, page: page)
      // The shell owns one dock footprint for scroll content, even across NavigationStack.
      // Nested horizontal scrollers consume their own margins rather than inheriting it.
      .contentMargins(.bottom, side || keyboardVisible || search.isSearching ? 0 : style.metrics.dockHeight,
        for: .scrollContent)
      // The page under the unfolded menu stands still, so a finger sliding down the menu's
      // rows is not taken for a scroll of what is behind it
      .scrollDisabled(unfolded)
      // The page dims under the unfolded menu and a tap on it folds the menu; the bar, which
      // turns into the menu, lies over this
      .overlay {
        if unfolded {
          style.colors.scrim
            .ignoresSafeArea()
            .onTapGesture { unfolded = false }
            .transition(.opacity)
            .accessibilityLabel(labels.dismissMenu)
            .accessibilityAddTraits(.isButton)
        }
      }
      .animation(reduceMotion ? nil : style.motion.scrim, value: unfolded)
      .environment(\.floatDamnDockClearance, side || keyboardVisible ? 0 : style.metrics.dockHeight)
      .environment(\.dockSearchController, search)
      // Keep the native scroll-edge treatment; the dock itself floats over the viewport.
      .scrollEdgeEffectStyle(side ? .automatic : .soft, for: .bottom)
      // The open page's search field takes the dock's place, at the page's own foot
      .overlay(alignment: .bottom) {
        if !side && !search.isSearching && !keyboardVisible {
          BottomBar(
            selection: $selection, unfolded: $unfolded, model: model, search: search.offered,
            openSearch: search.open
          )
        }
      }
  }

  private var sideBar: SideBar<Tab> {
    SideBar(selection: $selection, model: model, search: search.offered, openSearch: search.open)
  }
}
