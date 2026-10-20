# Float, damn dock!

A floating Liquid Glass tab bar for SwiftUI, in place of the system's. Made for [Play, damn it!](https://playdamnit.com).

- **Bottom (compact width):** a glass pill of your pinned tabs. Its last slot unfolds a menu with every tab: the pill grows into a card, and folds back the same way.
- **Side (regular width):** the bar stands up beside the pages and holds every tab.
- **Scrub:** hold a finger down and slide across the bar. The highlight rides under the finger, a soft light follows it, a tick marks each tab it crosses, and lifting opens the tab under it. Rest the finger on a tab, or a row of the menu, and it opens there with a haptic tap, without lifting (`holdDuration` in the style says how long). Rest on the last slot to unfold the menu, then keep sliding into it.
- Tabs you have opened stay alive under the open one, so each keeps its place.
- The open page can hand the bar a search. The bar gets a round search button and turns into the field.

Requires iOS 26 and Swift 6.

## Installation

```swift
.package(url: "https://github.com/nezdemkovski/float-damn-dock", from: "0.1.0")
```

and add the `FloatDamnDock` product to your target.

## Usage

```swift
import FloatDamnDock

FloatDamnDockView(selection: $tab, pinned: [.home, .search, .inbox], menu: Tab.allCases) { tab in
  FloatDamnDockItem(tab.title, systemImage: tab.symbol, badge: tab == .inbox ? unread : 0)
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
  .floatDamnDockSearch("Search", text: $query, source: model)
```

`floatDamnDockClearance` in the environment is the space the bottom bar covers. Scrolling pages run under it, behind the scroll-edge blur. A fixed canvas should reserve it.

## Styling

Everything that can be tuned lives in `FloatDamnDockStyle`, and each value has a default. It has four groups:

- `colors`: labels, the highlight, the light under the finger, the glass tint and how strong it is, the scrim, badges.
- `metrics`: the bar's height, insets, gaps and paddings, icon sizes, the badge dot, the menu's rows and corners.
- `motion`: every animation and delay — the press, the pill growing into the menu and folding back, the icons leaving and returning, the rows coming in one after another, the scrim, the search button.
- `scrub`: the finger — how long a rest takes to open a tab (`holdDuration`), how soon the highlight shows, what counts as a slide, how the highlight rides and lifts, and the light's reach and strength.

Change only what differs, best as a preset of your own:

```swift
extension FloatDamnDockStyle {
  static var brand: Self {
    var style = Self()
    style.colors.highlight = .white.opacity(0.14)
    style.colors.glassTint = .black
    style.colors.menuTintOpacity = 0.6
    style.metrics.height = 56
    style.motion.menuOpen = .spring(duration: 0.3, bounce: 0.2)
    style.scrub.holdDuration = .milliseconds(300)
    return style
  }
}

content.floatDamnDockStyle(.brand)
```

The bar's own words (More, the search button, the menu's scrim) come from `FloatDamnDockLabels`. The defaults are English, so pass localized labels with `floatDamnDockLabels(_:)`.

To use your own search field, write a `FloatDamnDockSearchFieldStyle` and set it with `.floatDamnDockSearchFieldStyle(MyFieldStyle())`, the way you would set a `ButtonStyle`. Its `makeBody(configuration:)` gets the page's prompt and binding. The field should take focus when it appears, call `focusChanged` as its focus changes, and call `close` to put the bar back.

The field belongs to the page, as with the system's `searchable`. The bar only learns which search the page offers. The page's `text` binding and `onFocusChange` callback never leave the page, so the field always uses the ones the page passed last.

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
