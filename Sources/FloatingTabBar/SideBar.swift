import SwiftUI

/// Where the side bar may stand
enum SideBarHost {
  /// In the vertical bar column the system keeps beside the pages (an open iPhone Duo): at
  /// its foot as the system's own tabs would be, leaving the top to the status items and the
  /// pages' toolbar buttons, the pages keeping their full width
  case column
  /// Beside the pages, where there is no such column. Not over them: a horizontal safe-area
  /// inset does not reach through the navigation stacks, so the pages would run under the bar.
  case beside
}

/// The side bar in one of its two places, or nothing when the system's column puts it in the
/// other: the shell offers it in both, and exactly one shows it
struct SideBarHosting<Bar: View>: View {
  let host: SideBarHost
  @ViewBuilder let bar: Bar
  @Environment(\.floatingTabBarStyle) private var style

  var body: some View {
    if #available(iOS 27.1, *) {
      ColumnAwareSideBar(host: host, bar: bar)
    } else if host == .beside {
      bar.padding(.horizontal, style.verticalPadding)
    }
  }
}

@available(iOS 27.1, *)
private struct ColumnAwareSideBar<Bar: View>: View {
  let host: SideBarHost
  let bar: Bar
  @Environment(\.toolbarVerticalEdge) private var barEdge
  @Environment(\.floatingTabBarStyle) private var style

  var body: some View {
    switch (host, barEdge) {
    case (.column, let edge?):
      inColumn(edge: edge)
    case (.beside, nil):
      bar.padding(.horizontal, style.verticalPadding)
    default:
      EmptyView()
    }
  }

  private func inColumn(edge: HorizontalEdge) -> some View {
    GeometryReader { outer in
      let column = edge == .trailing ? outer.safeAreaInsets.trailing : outer.safeAreaInsets.leading
      GeometryReader { proxy in
        bar
          .frame(width: column)
          .padding(.top, statusBottom(in: proxy, column: column, edge: edge) + 12)
          .padding(.bottom, max(outer.safeAreaInsets.bottom, style.horizontalPadding))
          .frame(
            maxWidth: .infinity, maxHeight: .infinity,
            alignment: edge == .trailing ? .bottomTrailing : .bottomLeading
          )
      }
      .ignoresSafeArea(.container, edges: [.top, .bottom, edge == .trailing ? .trailing : .leading])
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
  /// Puts the page's search field at the pages' foot
  let openSearch: () -> Void
  @Environment(\.floatingTabBarStyle) private var style
  @Environment(\.floatingTabBarLabels) private var labels
  @Namespace private var glassNamespace

  var body: some View {
    VStack(spacing: style.gap) {
      pill
      if search != nil {
        GlassCircleButton(
          title: labels.search, systemImage: "magnifyingglass", identifier: "search", namespace: glassNamespace
        ) { openSearch() }
          .transition(.opacity)
      }
      if let accessory = model.accessory {
        GlassCircleButton(
          title: accessory.title, systemImage: accessory.systemImage, identifier: accessory.identifier,
          namespace: glassNamespace, action: accessory.action
        )
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
}
