import SwiftUI

/// The pages with the floating bar stood up at their side. Where the system keeps a vertical
/// bar (an open iPhone Duo), the bar lives in that column, at its foot as the system's own tabs
/// would be, leaving the top to the status items and the pages' toolbar buttons, and the pages
/// keep their full width; elsewhere it stands beside the pages.
struct SideBarDock<Tab: Hashable, Pages: View>: View {
  @Binding var selection: Tab
  let model: TabBarModel<Tab>
  /// What the open page searches, as the bottom bar gets it
  let search: FloatingTabSearch?
  @Binding var searching: Bool
  @ViewBuilder let pages: Pages
  @Environment(\.floatingTabBarStyle) private var style

  var body: some View {
    Group {
      if #available(iOS 27.1, *) {
        VerticalBarColumnDock(pages: searchablePages, bar: bar)
      } else {
        BesidePages(pages: searchablePages, bar: bar)
      }
    }
    .onChange(of: search?.source) { searching = false }
  }

  private var bar: SideBar<Tab> {
    SideBar(selection: $selection, model: model, search: search, searching: $searching)
  }

  /// The search field, floating at the foot of the pages while searching: the bar's column is
  /// too narrow to hold it
  private var searchablePages: some View {
    pages.safeAreaBar(edge: .bottom, spacing: 0) {
      if let search, searching {
        BarSearchField(search: search, model: model) { searching = false }
          .padding(.horizontal, style.horizontalPadding)
          .padding(.vertical, style.verticalPadding)
      }
    }
  }
}

/// The bar beside the pages rather than over them: a horizontal safe-area inset does not reach
/// through the navigation stacks, so the pages would run under the bar
private struct BesidePages<Pages: View, Bar: View>: View {
  let pages: Pages
  let bar: Bar
  @Environment(\.floatingTabBarStyle) private var style

  var body: some View {
    HStack(spacing: 0) {
      pages
      bar.padding(.horizontal, style.verticalPadding)
    }
  }
}

@available(iOS 27.1, *)
private struct VerticalBarColumnDock<Pages: View, Bar: View>: View {
  let pages: Pages
  let bar: Bar
  @Environment(\.toolbarVerticalEdge) private var barEdge
  @Environment(\.floatingTabBarStyle) private var style

  var body: some View {
    if let barEdge {
      pages.overlay {
        GeometryReader { outer in
          let column = barEdge == .trailing ? outer.safeAreaInsets.trailing : outer.safeAreaInsets.leading
          GeometryReader { proxy in
            bar
              .frame(width: column)
              .padding(.top, statusBottom(in: proxy, column: column, edge: barEdge) + 12)
              .padding(.bottom, max(outer.safeAreaInsets.bottom, style.horizontalPadding))
              .frame(
                maxWidth: .infinity, maxHeight: .infinity,
                alignment: barEdge == .trailing ? .bottomTrailing : .bottomLeading
              )
          }
          .ignoresSafeArea(.container, edges: [.top, .bottom, barEdge == .trailing ? .trailing : .leading])
        }
      }
    } else {
      BesidePages(pages: pages, bar: bar)
    }
  }

  /// The lowest point of the system items (time, status) that occlude the bar's column
  private func statusBottom(in proxy: GeometryProxy, column: CGFloat, edge: HorizontalEdge) -> CGFloat {
    let columnX = edge == .trailing ? proxy.size.width - column : 0
    let columnRect = CGRect(x: columnX, y: 0, width: column, height: proxy.size.height)
    return proxy.reservedRegions(kind: .occlusion)
      .map(\.frame)
      .filter { $0.intersects(columnRect) }
      .map(\.maxY)
      .max() ?? proxy.safeAreaInsets.top
  }
}

/// The floating bar stood up: the glass pill of icons with the open one under a lighter pill,
/// tall enough for every tab of the menu, then the search button when the page has a search
/// and the accessory. A finger held down slides along the icons with the highlight riding
/// under it and opens the one it lifts from.
struct SideBar<Tab: Hashable>: View {
  @Binding var selection: Tab
  let model: TabBarModel<Tab>
  let search: FloatingTabSearch?
  @Binding var searching: Bool
  @Environment(\.floatingTabBarStyle) private var style
  @Environment(\.floatingTabBarLabels) private var labels
  @Namespace private var glassNamespace

  var body: some View {
    VStack(spacing: style.gap) {
      pill
      if search != nil {
        circleButton(labels.search, symbol: "magnifyingglass", identifier: "search") { searching = true }
          .transition(.opacity)
      }
      if let accessory = model.accessory {
        circleButton(accessory.title, symbol: accessory.systemImage, identifier: accessory.identifier, action: accessory.action)
      }
    }
    .animation(.smooth(duration: 0.25), value: search != nil)
  }

  private var pill: some View {
    let shape = RoundedRectangle(cornerRadius: style.height / 2, style: .continuous)
    let height = CGFloat(model.menu.count) * (style.height - 2 * style.inset) + 2 * style.inset
    // The same surface as the bottom pill: clear glass at its final size in its own
    // container, the icons over it outside the glass pass so they keep their full contrast
    return GlassEffectContainer(spacing: 0) {
      Color.clear
        .frame(width: style.height, height: height)
        .glassEffect(.regular.tint(style.glassTint.opacity(style.barTintOpacity)).interactive(), in: shape)
        .glassEffectID("navigation", in: glassNamespace)
    }
      .overlay {
        VStack(spacing: 0) {
          ForEach(model.menu, id: \.self) { tab in
            TabBarSlot(item: model.item(tab), identifier: TabBarModel<Tab>.identifier(tab), active: selection == tab) {
              model.open(tab, selection: $selection)
            }
              .scrubItem(tab)
          }
        }
        .scrubGroup(Tab.self, selected: selection, highlight: .capsule, follows: .finger) {
          model.open($0, selection: $selection)
        }
        .padding(style.inset)
      }
      .clipShape(shape)
      .scrubSurface(in: shape)
  }

  /// A round glass button, as the bottom bar's search and accessory buttons
  private func circleButton(_ title: String, symbol: String, identifier: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: style.buttonIconSize, weight: .regular))
        .foregroundStyle(style.label)
        .frame(width: style.height, height: style.height)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .glassEffect(.regular.interactive(), in: .circle)
    .glassEffectID(identifier, in: glassNamespace)
    .accessibilityLabel(title)
    .accessibilityIdentifier("tabbar.\(identifier)")
  }
}
