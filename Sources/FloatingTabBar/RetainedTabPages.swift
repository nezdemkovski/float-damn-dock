import SwiftUI

/// Every tab opened so far, alive under the open one (as the system's tab view keeps them), so
/// each keeps its place: a tab is built when first opened and kept after. Both shells (the
/// bottom one and the side one) lay their bar over or beside these.
struct RetainedTabPages<Tab: Hashable, Page: View>: View {
  let selection: Tab
  let page: (Tab) -> Page
  @State private var visited: [Tab] = []

  var body: some View {
    ZStack {
      ForEach(visited, id: \.self) { tab in
        let open = selection == tab
        page(tab)
          .opacity(open ? 1 : 0)
          .allowsHitTesting(open)
          .accessibilityHidden(!open)
          .zIndex(open ? 1 : 0)
          // A search field from a hidden tab would fight the open one for the keyboard
          .environment(\.floatingTabIsOpen, open)
          // Retained tabs keep their view trees alive. Only the visible one may configure
          // the shared bar, or a search field from a hidden tab would keep it compressed.
          .transformPreference(FloatingTabSearchKey.self) { search in
            if !open { search = nil }
          }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onChange(of: selection, initial: true) { _, tab in
      if !visited.contains(tab) { visited.append(tab) }
    }
  }
}
