import SwiftUI

/// What the open page offers to search, as the bar sees it: which search and its prompt.
/// Pages offer it with `floatingTabBarSearch(_:text:source:isPresented:)`. The page's binding
/// and callback never leave the page: as with the system's `searchable`, the field is the
/// page's own, shown in the bar's place while the shell says the search is open.
struct FloatingTabSearch: Equatable {
  let source: ObjectIdentifier
  let prompt: String
}

struct FloatingTabSearchKey: PreferenceKey {
  static var defaultValue: FloatingTabSearch? { nil }

  static func reduce(value: inout FloatingTabSearch?, nextValue: () -> FloatingTabSearch?) {
    value = nextValue() ?? value
  }
}

/// The open page's search as the shell runs it: the search on offer and whether its field is
/// up. The shell hands it down the environment (as the system hands down `isSearching` and
/// `dismissSearch`); the bar's search button opens it, the page's field closes it.
@MainActor @Observable
final class FloatingTabSearchController {
  /// The search the open page offers
  private(set) var offered: FloatingTabSearch?
  /// Its field is up, in the bar's place
  private(set) var isSearching = false

  /// Another search, or none, closes the field
  func offer(_ search: FloatingTabSearch?) {
    if search?.source != offered?.source { isSearching = false }
    offered = search
  }

  func open() {
    if offered != nil { isSearching = true }
  }

  func close() {
    isSearching = false
  }

  /// The field of this search is up
  func shows(_ source: ObjectIdentifier) -> Bool {
    isSearching && offered?.source == source
  }
}

extension EnvironmentValues {
  @Entry var floatingTabSearchController: FloatingTabSearchController?
  @Entry var floatingTabSearchFieldStyle: (any FloatingTabSearchFieldStyle)?
  /// The page's tab is the open one; retained pages of the others stay quiet
  @Entry var floatingTabIsOpen = true
}

extension View {
  /// Offers this page's search to the bar: a round search button beside it (the last pinned
  /// tab gives up its slot) that puts the page's search field in the bar's place. `source`
  /// tells one page's search from another's; only the open tab's page reaches the bar. The
  /// field uses `text` and `onFocusChange` as given here on each update of the page.
  public func floatingTabBarSearch(
    _ prompt: String, text: Binding<String>, source: AnyObject, isPresented: Bool = true,
    onFocusChange: @escaping (Bool) -> Void = { _ in }
  ) -> some View {
    modifier(SearchOffer(
      prompt: prompt, text: text, source: ObjectIdentifier(source), isPresented: isPresented,
      onFocusChange: onFocusChange
    ))
  }
}

/// Offers the search up to the bar, and shows the field at the page's foot while the shell
/// has it open
private struct SearchOffer: ViewModifier {
  let prompt: String
  let text: Binding<String>
  let source: ObjectIdentifier
  let isPresented: Bool
  let onFocusChange: (Bool) -> Void
  @Environment(\.floatingTabSearchController) private var controller
  @Environment(\.floatingTabSearchFieldStyle) private var fieldStyle
  @Environment(\.floatingTabIsOpen) private var isOpen
  @Environment(\.floatingTabBarStyle) private var style

  private var showsField: Bool {
    isPresented && isOpen && controller?.shows(source) == true
  }

  func body(content: Content) -> some View {
    content
      .preference(
        key: FloatingTabSearchKey.self,
        value: isPresented ? FloatingTabSearch(source: source, prompt: prompt) : nil
      )
      // The keyboard's safe area keeps the field above it
      .safeAreaBar(edge: .bottom, spacing: 0) {
        if showsField {
          field
            .padding(.horizontal, style.metrics.horizontalPadding)
            .padding(.vertical, style.metrics.verticalPadding)
        }
      }
  }

  @ViewBuilder private var field: some View {
    let field = FloatingTabSearchField(
      prompt: prompt, text: text, close: { controller?.close() },
      focusChanged: { focused in
        onFocusChange(focused)
        if !focused { controller?.close() }
      }
    )
    if let fieldStyle {
      styledField(fieldStyle, field)
    } else {
      DefaultSearchField(field: field)
    }
  }
}

/// Draws the search field in the bar's place, as a `ButtonStyle` draws a button. Set it with
/// `floatingTabSearchFieldStyle(_:)`; without one the field is a plain glass capsule.
public protocol FloatingTabSearchFieldStyle {
  associatedtype Body: View
  /// The field for the page's search. It should take focus when it appears, call
  /// `focusChanged` as its focus changes, and `close` to put the bar back.
  @ViewBuilder @MainActor func makeBody(configuration: FloatingTabSearchField) -> Body
}

extension View {
  /// The search field the bar's search puts in the bar's place, for every bar below
  public func floatingTabSearchFieldStyle(_ style: some FloatingTabSearchFieldStyle) -> some View {
    environment(\.floatingTabSearchFieldStyle, style)
  }
}

@MainActor private func styledField(_ style: some FloatingTabSearchFieldStyle, _ field: FloatingTabSearchField) -> AnyView {
  AnyView(style.makeBody(configuration: field))
}

/// What a search field style gets: the page's search
public struct FloatingTabSearchField {
  public let prompt: String
  public let text: Binding<String>
  /// Puts the bar back
  public let close: () -> Void
  /// Call it as the field gains and loses focus; losing it puts the bar back
  public let focusChanged: (Bool) -> Void
}

/// A glass capsule with the field, and a round glass button that closes it
private struct DefaultSearchField: View {
  let field: FloatingTabSearchField
  @FocusState private var focused: Bool
  @Environment(\.floatingTabBarStyle) private var style
  @Environment(\.floatingTabBarLabels) private var labels

  var body: some View {
    HStack(spacing: style.metrics.gap) {
      HStack(spacing: 12) {
        Image(systemName: "magnifyingglass")
          .font(.system(.body, weight: .medium))
          .foregroundStyle(style.colors.secondaryLabel)
        TextField(field.prompt, text: field.text)
          .focused($focused)
          .textFieldStyle(.plain)
          .foregroundStyle(style.colors.label)
          .autocorrectionDisabled()
          .submitLabel(.search)
          .onSubmit { focused = false }
          .accessibilityIdentifier("tabbar.search.field")
        if !field.text.wrappedValue.isEmpty {
          Button(labels.clearSearch, systemImage: "xmark.circle.fill", role: .cancel) { field.text.wrappedValue = "" }
            .labelStyle(.iconOnly)
            .foregroundStyle(style.colors.tertiaryLabel)
            .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity)
      .frame(height: style.metrics.height)
      .contentShape(.capsule)
      .glassEffect(.regular.tint(style.colors.glassTint.opacity(style.colors.barTintOpacity)).interactive(), in: .capsule)
      .simultaneousGesture(TapGesture().onEnded { focused = true })
      Button(action: field.close) {
        Image(systemName: "xmark")
          .font(.system(.body, weight: .medium))
          .foregroundStyle(style.colors.label)
          .frame(width: style.metrics.height, height: style.metrics.height)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .glassEffect(.regular.tint(style.colors.glassTint.opacity(style.colors.barTintOpacity)).interactive(), in: .circle)
      .accessibilityLabel(labels.closeSearch)
      .accessibilityIdentifier("tabbar.search.close")
    }
    .task { focused = true }
    .onChange(of: focused) { _, value in field.focusChanged(value) }
    .onDisappear { field.focusChanged(false) }
  }
}
