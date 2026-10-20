import SwiftUI

/// Shared timings for the press, surface and returning bar content.
private enum Motion {
  static let press = Animation.easeOut(duration: 0.06)
  static let open = Animation.spring(duration: 0.38, bounce: 0.12)
  static let heldOpen = Animation.smooth(duration: 0.28)
  static let close = Animation.smooth(duration: 0.24)
  static let barFade = Animation.easeOut(duration: 0.12)
  /// The icons come back a beat after the card starts folding, so they land in the pill
  static let iconsReturnDelay: TimeInterval = 0.06
}

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
  @Environment(\.floatingTabBarStyle) private var style
  @Environment(\.floatingTabBarLabels) private var labels
  @Environment(\.scrubSession) private var scrub
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var glassNamespace
  @State private var dockWidth: CGFloat = 0
  @State private var searching = false
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
    ZStack(alignment: .bottom) {
      if let search, searching {
        BarSearchField(search: search, model: model) { searching = false }
          .frame(maxWidth: .infinity)
      } else {
        GlassEffectContainer(spacing: style.gap) { controls }
      }
    }
    // Search is replaced without retaining an outgoing focused field or glass surface.
    // The safe-area bar follows the system keyboard animation on its own.
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { dockWidth = $0 }
    .padding(.horizontal, style.horizontalPadding)
    .padding(.vertical, style.verticalPadding)
    .onChange(of: search?.source) { searching = false }
  }

  /// Keep the baseline of the pinned slots plus the last one when the last pinned tab gives
  /// its space to the separate search button. The removed slot plus the original gap must fit
  /// one button and two equal gaps.
  private var controlGap: CGFloat {
    guard reservesSearchSpace, dockWidth > 0 else { return style.gap }
    let accessories = model.accessory == nil ? 0 : style.height + style.gap
    let slotWidth = (dockWidth - accessories - 2 * style.inset) / CGFloat(model.pinned.count + 1)
    return max(0, (slotWidth + style.gap - style.height) / 2)
  }

  private var controls: some View {
    HStack(alignment: .bottom, spacing: 0) {
      morphing
        .transition(.opacity)
      if search != nil {
        // Keep its bottom-aligned geometry alive while the menu collapses. Native
        // glass renders outside ordinary opacity, so disable the material as well.
        dockButton(labels.search, symbol: "magnifyingglass", identifier: "search", visible: showsSearchButton) {
          unfolded = false
          searching = true
        }
        .frame(width: reservesSearchSpace ? style.height : 0, alignment: .trailing)
        .padding(.leading, reservesSearchSpace ? controlGap : 0)
      }
      if let accessory = model.accessory {
        dockButton(accessory.title, symbol: accessory.systemImage, identifier: accessory.identifier, action: accessory.action)
          .padding(.leading, controlGap)
      }
    }
    .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: search != nil)
  }

  private func dockButton(_ title: String, symbol: String, identifier: String, visible: Bool = true, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: style.buttonIconSize, weight: .regular))
        .foregroundStyle(style.label)
        .frame(width: style.height, height: style.height)
        .contentShape(Circle())
    }
      .buttonStyle(.plain)
      .opacity(visible ? 1 : 0)
      .glassEffect(visible ? .regular.interactive() : .identity, in: .circle)
      .allowsHitTesting(visible)
      .accessibilityHidden(!visible)
      .accessibilityLabel(title)
      .glassEffectID(identifier, in: glassNamespace)
      // Standalone buttons fade in place; only the navigation surface morphs into the menu.
      .glassEffectTransition(.identity)
      .accessibilityIdentifier("tabbar.\(identifier)")
      .transaction { transaction in
        // Exit before the surface expands; reappear in the shared closing transaction
        // so the glass keeps the same vertical origin as the bottom-aligned controls.
        if !visible { transaction.animation = reduceMotion ? nil : Motion.press }
      }
      .transition(.opacity)
  }

  /// Both contents stay mounted while the glass morphs between two stable surfaces. The
  /// menu is attached to the top; the bar icons return before the closing card reaches it.
  private var morphing: some View {
    let hitShape = RoundedRectangle(
      cornerRadius: expanded ? style.menuCornerRadius : style.height / 2,
      style: .continuous
    )
    let openHeight = max(menuHeight, style.height)
    return ZStack(alignment: .bottom) {
      GlassEffectContainer(spacing: 0) {
        // Keep both endpoints at their final geometry and let Liquid Glass morph between
        // them. Resizing the view that owns `glassEffect` makes the material resample its
        // backdrop once the spring settles, which causes a visible last-frame color jump.
        if expanded {
          glassSurface(
            height: openHeight,
            tint: style.glassTint.opacity(style.menuTintOpacity),
            shape: RoundedRectangle(cornerRadius: style.menuCornerRadius, style: .continuous)
          )
        } else {
          glassSurface(
            height: style.height,
            tint: style.glassTint.opacity(unfolded ? style.menuTintOpacity : style.barTintOpacity),
            shape: RoundedRectangle(cornerRadius: style.height / 2, style: .continuous)
          )
        }
      }
    }
    .frame(height: expanded ? openHeight : style.height, alignment: .bottom)
      .overlay(alignment: .top) {
        TabMenu(selection: $selection, unfolded: $unfolded, model: model, expanded: expanded)
          .fixedSize(horizontal: false, vertical: true)
          .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded(.up) } action: { height in
            if menuHeight != height { menuHeight = height }
          }
          .opacity(expanded ? 1 : 0)
          .animation(reduceMotion ? nil : .easeOut(duration: expanded ? 0.16 : 0.12), value: expanded)
      }
      .overlay {
        pill
          .allowsHitTesting(!unfolded)
          .animation(reduceMotion ? nil : Motion.barFade.delay(expanded ? 0 : Motion.iconsReturnDelay)) { content in
            content.opacity(expanded ? 0 : 1)
              .blur(radius: expanded && !reduceMotion ? 4 : 0)
          }
          .accessibilityElement(children: .contain)
          .accessibilityHidden(unfolded)
      }
      .frame(maxWidth: .infinity)
      .clipShape(hitShape)
      .scrubSurface(in: hitShape)
      .scaleEffect(x: menuPhase == .pressing ? 0.84 : 1, y: menuPhase == .pressing ? 0.55 : 1, anchor: .bottomTrailing)
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
      withAnimation(reduceMotion ? nil : Motion.close) { menuPhase = .closed }
      return
    }
    guard !reduceMotion else {
      menuPhase = .open
      return
    }
    guard menuPhase != .open, scrub?.point == nil else {
      withAnimation(Motion.heldOpen) { menuPhase = .open }
      return
    }
    let request = menuRequest
    withAnimation(Motion.press, completionCriteria: .logicallyComplete) {
      menuPhase = .pressing
    } completion: {
      guard request == menuRequest, unfolded else { return }
      withAnimation(Motion.open) { menuPhase = .open }
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
      // A finger that rests on the last slot unfolds the menu without lifting, and can slide
      // straight on into it
      holds: [.more], onHold: { _ in unfolded = true }
    ) { slot in
      switch slot {
      case .tab(let tab): model.open(tab, selection: $selection)
      case .more: unfolded = true
      }
    }
    .padding(style.inset)
    .frame(height: style.height)
  }

  /// The last slot: the chevrons that unfold the rest, with the open tab's icon beside them
  /// when it is one of those
  private var moreSlot: some View {
    let item = model.item(selection)
    return Button {
      unfolded = true
    } label: {
      HStack(spacing: 7) {
        if overflowSelected {
          Image(systemName: item.systemImage)
            .font(.system(size: style.iconSize, weight: .medium))
            .symbolVariant(.fill)
            .foregroundStyle(style.label)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
        // Small and light beside an icon, a little larger on its own
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: overflowSelected ? 9 : 13, weight: .medium))
          .foregroundStyle(overflowSelected ? style.tertiaryLabel : style.secondaryLabel)
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
