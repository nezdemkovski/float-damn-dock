import SwiftUI

/// The floating bar along the bottom: a glass pill of the pinned tabs with the open one under
/// a lighter pill, the last slot unfolding the menu of every tab, and the round buttons beside
/// it (the page's search, the app's accessory). Unfolding, the pill itself grows upward into
/// the menu's card (the icons blur away, the rows come in from the top) and folds back the
/// same way. A finger held down slides across the slots with the highlight riding under it;
/// held on the last slot, it unfolds the menu and slides on into its rows; it opens whatever
/// it lifts from.
struct BottomBar<Tab: Hashable>: View {
  @Binding var selection: Tab
  @Binding var unfolded: Bool
  let model: TabBarModel<Tab>
  let search: FloatingTabSearch?
  /// Puts the page's search field in the bar's place
  let openSearch: () -> Void
  @Environment(\.floatingTabBarStyle) private var style
  @Environment(\.floatingTabBarLabels) private var labels
  @Environment(\.scrubSession) private var scrub
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var glassNamespace
  @State private var menuPhase: MenuPhase = .closed
  /// Counts the unfold and fold requests, so a press that finishes after the next request
  /// does not open the menu
  @State private var menuRequest = 0
  @State private var menuHeight: CGFloat = 0

  /// One visual phase: compression and expansion cannot be active independently.
  private enum MenuPhase {
    case closed, pressing, open
  }

  private var expanded: Bool { menuPhase == .open }

  /// The last pinned tab gives its slot to the search button while the page has a search
  private var visibleTabs: [Tab] { search == nil ? model.pinned : Array(model.pinned.dropLast()) }
  // Width and height change in the same menu transaction, after the press feedback.
  private var reservesSearchSpace: Bool { search != nil && !expanded }
  // Hide the control during press feedback, before the navigation surface grows over it.
  private var showsSearchButton: Bool { reservesSearchSpace && !unfolded }
  /// The open tab is not pinned: it lives in the last slot
  private var overflowSelected: Bool { !visibleTabs.contains(selection) }

  /// What a slot holds, for the slide across them
  enum Slot: Hashable {
    case tab(Tab), more
  }

  /// The slot the highlight rests on
  private var current: Slot { overflowSelected ? .more : .tab(selection) }

  var body: some View {
    GlassEffectContainer(spacing: style.metrics.gap) { controls }
      .padding(.horizontal, style.metrics.horizontalPadding)
      .padding(.vertical, style.metrics.verticalPadding)
  }

  private var controls: some View {
    DockLayout(
      slots: model.pinned.count + 1, searchTakesSlot: reservesSearchSpace,
      inset: style.metrics.inset, gap: style.metrics.gap, button: style.metrics.height
    ) {
      morphing
        .dockRole(.pill)
        .transition(.opacity)
      if search != nil {
        // Stays laid out while the menu is open, so its glass keeps the bottom-aligned
        // origin; it leaves before the surface grows over it and comes back as it folds.
        GlassCircleButton(
          title: labels.search, systemImage: "magnifyingglass", identifier: "search",
          visible: showsSearchButton, hideAnimation: reduceMotion ? nil : style.motion.press,
          namespace: glassNamespace
        ) {
          unfolded = false
          openSearch()
        }
        .dockRole(.search)
        .transition(.opacity)
      }
      if let accessory = model.accessory {
        GlassCircleButton(
          title: accessory.title, systemImage: accessory.systemImage, identifier: accessory.identifier,
          namespace: glassNamespace, action: accessory.action
        )
        .dockRole(.accessory)
        .transition(.opacity)
      }
    }
    .animation(reduceMotion ? nil : style.motion.searchButton, value: search != nil)
  }

  /// Both contents stay mounted while the glass morphs between two stable surfaces. The
  /// menu is attached to the top; the bar icons return before the closing card reaches it.
  private var morphing: some View {
    let hitShape = RoundedRectangle(
      cornerRadius: expanded ? style.metrics.menuCornerRadius : style.metrics.height / 2,
      style: .continuous
    )
    let openHeight = max(menuHeight, style.metrics.height)
    return ZStack(alignment: .bottom) {
      GlassEffectContainer(spacing: 0) {
        // Keep both endpoints at their final geometry and let Liquid Glass morph between
        // them. Resizing the view that owns `glassEffect` makes the material resample its
        // backdrop once the spring settles, which causes a visible last-frame color jump.
        if expanded {
          glassSurface(
            height: openHeight,
            tint: style.colors.glassTint.opacity(style.colors.menuTintOpacity),
            shape: RoundedRectangle(cornerRadius: style.metrics.menuCornerRadius, style: .continuous)
          )
        } else {
          glassSurface(
            height: style.metrics.height,
            tint: style.colors.glassTint.opacity(unfolded ? style.colors.menuTintOpacity : style.colors.barTintOpacity),
            shape: RoundedRectangle(cornerRadius: style.metrics.height / 2, style: .continuous)
          )
        }
      }
    }
    .frame(height: expanded ? openHeight : style.metrics.height, alignment: .bottom)
      .overlay(alignment: .top) {
        TabMenu(selection: $selection, unfolded: $unfolded, model: model, expanded: expanded)
          .fixedSize(horizontal: false, vertical: true)
          .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded(.up) } action: { height in
            if menuHeight != height { menuHeight = height }
          }
          .opacity(expanded ? 1 : 0)
          .animation(reduceMotion ? nil : expanded ? style.motion.rowsIn : style.motion.rowsOut, value: expanded)
      }
      .overlay {
        pill
          .allowsHitTesting(!unfolded)
          .animation(reduceMotion ? nil : style.motion.iconsFade.delay(expanded ? 0 : style.motion.iconsReturnDelay)) { content in
            content.opacity(expanded ? 0 : 1)
              .blur(radius: expanded && !reduceMotion ? style.motion.iconsBlur : 0)
          }
          .accessibilityElement(children: .contain)
          .accessibilityHidden(unfolded)
      }
      .frame(maxWidth: .infinity)
      .clipShape(hitShape)
      .scrubSurface(in: hitShape)
      .scaleEffect(
        x: menuPhase == .pressing ? style.motion.pressedScale.width : 1,
        y: menuPhase == .pressing ? style.motion.pressedScale.height : 1,
        anchor: .bottomTrailing
      )
      .onChange(of: unfolded) { animateMenu() }
  }

  private func glassSurface<S: Shape>(height: CGFloat, tint: Color, shape: S) -> some View {
    Color.clear
      .frame(maxWidth: .infinity)
      .frame(height: height)
      .glassEffect(.regular.tint(tint).interactive(), in: shape)
      .glassEffectID("navigation", in: glassNamespace)
  }

  /// Folds or unfolds the card. A tap first presses the pill down toward the last slot and
  /// the card grows once that press has played out; a finger still down (a hold, a slide)
  /// grows it straight away, under the finger.
  private func animateMenu() {
    menuRequest += 1
    guard unfolded else {
      withAnimation(reduceMotion ? nil : style.motion.menuClose) { menuPhase = .closed }
      return
    }
    guard !reduceMotion else {
      menuPhase = .open
      return
    }
    guard menuPhase != .open, scrub?.point == nil else {
      withAnimation(style.motion.menuOpenUnderFinger) { menuPhase = .open }
      return
    }
    let request = menuRequest
    withAnimation(style.motion.press, completionCriteria: .logicallyComplete) {
      menuPhase = .pressing
    } completion: {
      guard request == menuRequest, unfolded else { return }
      withAnimation(style.motion.menuOpen) { menuPhase = .open }
    }
  }

  private var pill: some View {
    HStack(spacing: 0) {
      ForEach(visibleTabs, id: \.self) { tab in
        TabBarSlot(
          item: model.item(tab), identifier: TabBarModel<Tab>.identifier(tab),
          active: selection == tab, hidden: unfolded
        ) { model.open(tab, selection: $selection) }
          .scrubItem(Slot.tab(tab))
          .transition(.opacity)
      }
      moreSlot
        .scrubItem(Slot.more)
    }
    .scrubGroup(
      Slot.self, selected: current, highlight: .capsule, follows: .finger, isEnabled: !unfolded,
      // A finger that rests on a slot opens it without lifting; on the last slot it unfolds
      // the menu and can slide straight on into it
      holds: Set(visibleTabs.map(Slot.tab) + [.more]),
      onHold: { slot in
        switch slot {
        case .tab(let tab): if selection != tab { selection = tab }
        case .more: unfolded = true
        }
      }
    ) { slot in
      switch slot {
      case .tab(let tab): model.open(tab, selection: $selection)
      case .more: unfolded = true
      }
    }
    .padding(style.metrics.inset)
    .frame(height: style.metrics.height)
  }

  /// The last slot: the chevrons that unfold the rest, with the open tab's icon beside them
  /// when it is one of those
  private var moreSlot: some View {
    let item = model.item(selection)
    return Button {
      unfolded = true
    } label: {
      HStack(spacing: style.metrics.overflowIconSpacing) {
        if overflowSelected {
          Image(systemName: item.systemImage)
            .font(.system(size: style.metrics.iconSize, weight: .medium))
            .symbolVariant(.fill)
            .foregroundStyle(style.colors.label)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
        // Small and light beside an icon, a little larger on its own
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: overflowSelected ? 9 : 13, weight: .medium))
          .foregroundStyle(overflowSelected ? style.colors.tertiaryLabel : style.colors.secondaryLabel)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(overflowSelected ? item.title : labels.more)
    .accessibilityHint(labels.moreHint)
    .accessibilityAddTraits(overflowSelected ? .isSelected : [])
    .accessibilityIdentifier("tabbar.more")
    .accessibilityHidden(unfolded)
  }
}
