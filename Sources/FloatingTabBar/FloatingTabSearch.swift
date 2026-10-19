import SwiftUI

/// What the open page searches, handed to the bar: the bar owns the field and its focus
/// lifecycle. Pages offer it with `floatingTabBarSearch(_:text:source:isPresented:)`.
struct FloatingTabSearch: Equatable {
  let source: ObjectIdentifier
  let prompt: String
  let text: Binding<String>
  var onFocusChange: (Bool) -> Void

  static func == (lhs: Self, rhs: Self) -> Bool {
    // The field observes its binding directly; only a different source reconfigures the bar.
    lhs.source == rhs.source && lhs.prompt == rhs.prompt
  }
}

struct FloatingTabSearchKey: PreferenceKey {
  static var defaultValue: FloatingTabSearch? { nil }

  static func reduce(value: inout FloatingTabSearch?, nextValue: () -> FloatingTabSearch?) {
    value = nextValue() ?? value
  }
}

extension View {
  /// Offers this page's search to the bar: a round search button beside it (the last pinned
  /// tab gives up its slot) that turns the bar into the field. `source` tells one page's
  /// search from another's; only the open tab's page reaches the bar.
  public func floatingTabBarSearch(
    _ prompt: String, text: Binding<String>, source: AnyObject, isPresented: Bool = true,
    onFocusChange: @escaping (Bool) -> Void = { _ in }
  ) -> some View {
    preference(
      key: FloatingTabSearchKey.self,
      value: isPresented ? FloatingTabSearch(
        source: ObjectIdentifier(source), prompt: prompt, text: text, onFocusChange: onFocusChange
      ) : nil
    )
  }
}

/// What a custom search field gets from the bar (see `FloatingTabView.searchField(_:)`).
/// The field should take focus when it appears.
public struct FloatingTabSearchField {
  public let prompt: String
  public let text: Binding<String>
  /// Puts the bar back
  public let close: () -> Void
  /// Call it as the field gains and loses focus; losing it puts the bar back
  public let focusChanged: (Bool) -> Void
}

/// The search field in the bar's place: the app's own, or a plain glass one
struct BarSearchField<Tab: Hashable>: View {
  let search: FloatingTabSearch
  let model: TabBarModel<Tab>
  let close: () -> Void

  var body: some View {
    let field = FloatingTabSearchField(
      prompt: search.prompt, text: search.text, close: close,
      focusChanged: { focused in
        search.onFocusChange(focused)
        if !focused { close() }
      }
    )
    if let custom = model.searchField {
      custom(field)
    } else {
      DefaultSearchField(field: field)
    }
  }
}

/// A glass capsule with the field, and a round glass button that closes it
private struct DefaultSearchField: View {
  let field: FloatingTabSearchField
  @FocusState private var focused: Bool
  @Environment(\.floatingTabBarStyle) private var style
  @Environment(\.floatingTabBarLabels) private var labels

  var body: some View {
    HStack(spacing: style.gap) {
      HStack(spacing: 12) {
        Image(systemName: "magnifyingglass")
          .font(.system(.body, weight: .medium))
          .foregroundStyle(style.secondaryLabel)
        TextField(field.prompt, text: field.text)
          .focused($focused)
          .textFieldStyle(.plain)
          .foregroundStyle(style.label)
          .autocorrectionDisabled()
          .submitLabel(.search)
          .onSubmit { focused = false }
          .accessibilityIdentifier("tabbar.search.field")
        if !field.text.wrappedValue.isEmpty {
          Button(labels.clearSearch, systemImage: "xmark.circle.fill", role: .cancel) { field.text.wrappedValue = "" }
            .labelStyle(.iconOnly)
            .foregroundStyle(style.tertiaryLabel)
            .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity)
      .frame(height: style.height)
      .contentShape(.capsule)
      .glassEffect(.regular.tint(style.glassTint.opacity(style.barTintOpacity)).interactive(), in: .capsule)
      .simultaneousGesture(TapGesture().onEnded { focused = true })
      Button(action: field.close) {
        Image(systemName: "xmark")
          .font(.system(.body, weight: .medium))
          .foregroundStyle(style.label)
          .frame(width: style.height, height: style.height)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .glassEffect(.regular.tint(style.glassTint.opacity(style.barTintOpacity)).interactive(), in: .circle)
      .accessibilityLabel(labels.closeSearch)
      .accessibilityIdentifier("tabbar.search.close")
    }
    .task { focused = true }
    .onChange(of: focused) { _, value in field.focusChanged(value) }
    .onDisappear { field.focusChanged(false) }
  }
}
