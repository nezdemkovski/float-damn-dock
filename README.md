# FloatingTabBar

A floating Liquid Glass tab bar for SwiftUI, in place of the system's.

- **Bottom (compact width):** a glass pill of your pinned tabs. Its last slot unfolds a menu with every tab: the pill grows into a card, and folds back the same way.
- **Side (regular width):** the bar stands up beside the pages and holds every tab.
- **Scrub:** hold a finger down and slide across the bar. The highlight rides under the finger, a soft light follows it, a tick marks each tab it crosses, and lifting opens the tab under it. Hold on the last slot to unfold the menu, then keep sliding into it.
- Tabs you have opened stay alive under the open one, so each keeps its place.
- The open page can hand the bar a search. The bar gets a round search button and turns into the field.

Requires iOS 26 and Swift 6.

## Usage

```swift
import FloatingTabBar

FloatingTabView(selection: $tab, pinned: [.home, .search, .inbox], menu: Tab.allCases) { tab in
  FloatingTabItem(tab.title, systemImage: tab.symbol, badge: tab == .inbox ? unread : 0)
} page: { tab in
  NavigationStack(path: $paths[tab]) { page(for: tab) }
}
.accessory("New post", systemImage: "plus") { composing = true }
.onReselect { tab in paths[tab] = NavigationPath() }
.menuHeader("Profile", isPresented: user != nil) { showProfile() } label: { ProfileRow() }
```

A page offers its search to the bar:

```swift
List(results) { … }
  .floatingTabBarSearch("Search", text: $query, source: model)
```

`floatingTabBarClearance` in the environment is the space the bottom bar covers. Scrolling pages run under it, behind the scroll-edge blur. A fixed canvas should reserve it.

## Styling

Every color and metric lives in `FloatingTabBarStyle`, and each one has a system default:

```swift
var style = FloatingTabBarStyle()
style.highlight = .white.opacity(0.14)
style.glassTint = .black
style.menuTintOpacity = 0.6
style.height = 56
style.badge = .orange

content.floatingTabBarStyle(style)
```

The bar's own words (More, the search button, the menu's scrim) come from `FloatingTabBarLabels`. The defaults are English, so pass localized labels with `floatingTabBarLabels(_:)`.

To use your own search field, pass `.searchField { field in MyField(field) }`. The field should take focus when it appears, call `field.focusChanged` as its focus changes, and call `field.close` to put the bar back.

## Accessibility identifiers

| Element | Identifier |
| --- | --- |
| Tab in the bar | `tabbar.<tab>` |
| Last slot (opens the menu) | `tabbar.more` |
| Search button | `tabbar.search` |
| Accessory | `tabbar.<identifier>` |
| Menu row | `sections.<tab>` |
| Menu header | `sections.<identifier>` |

`<tab>` is `String(describing: tab)`, so an enum case gives its name.

## Scrub on its own

```swift
HStack { ForEach(items) { ItemView($0).scrubItem($0.id) } }
  .scrubGroup(Item.ID.self, selected: selection, highlight: .capsule, follows: .finger) { selection = $0 }
```
