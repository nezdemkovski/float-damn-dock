import Observation
import SwiftUI

/// Press and slide across a group of controls, as a menu is scrubbed: the group's highlight
/// leaves the chosen control and rides under the finger, a broad soft light follows
/// the finger, a tick marks each control the slide crosses, and lifting picks the one it is
/// on. A plain tap picks the control under it, with no tick. The group takes every touch on
/// its items, so their own buttons serve assistive input (VoiceOver, keyboards) only.
///
/// Groups on one screen share the finger through a `ScrubSession` in the environment: a slide
/// that starts in one group (the bar) carries on into another that comes up under it (the
/// sections popover), and the lift picks in whichever group it lands.
///
/// Mark each control with `scrubItem(id)` and the group that holds them with `scrubGroup`.
/// The highlight and the light take their colors from `floatingTabBarStyle`.
extension View {
  /// One control of a scrub group, known by its id
  public func scrubItem(_ id: some Hashable) -> some View {
    modifier(ScrubItem(id: AnyHashable(id)))
  }

  /// The surface that owns the finger for the groups inside it, when they share a session:
  /// a view that stays while the groups come and go (a bar that turns into a menu), so a slide
  /// carries across. It also owns the finger's light, clipped only to the surface shape.
  /// Without a shared session a group takes its own touches and draws its own light.
  public func scrubSurface(in shape: some Shape) -> some View {
    modifier(ScrubSurface(shape: shape))
  }

  /// The group: draws the highlight under the chosen (or the finger's) item
  /// and picks the item the finger lifts from. `tapOnly` items respond to a short tap but
  /// never join the drag highlight. `hovered` reports the item under the finger while down.
  public func scrubGroup<ID: Hashable>(
    _ type: ID.Type = ID.self, selected: ID?, highlight: ScrubHighlight, follows: ScrubFollow,
    isEnabled: Bool = true, ignoresHoverNear: CGPoint? = nil, hoverRadius: CGFloat = 0,
    tapOnly: Set<ID> = [], hovered: Binding<ID?>? = nil,
    pick: @escaping (ID) -> Void
  ) -> some View {
    modifier(ScrubGroup<ID>(
      selected: selected, highlight: highlight, follows: follows, isEnabled: isEnabled,
      ignoresHoverNear: ignoresHoverNear, hoverRadius: hoverRadius, tapOnly: tapOnly,
      hoveredOut: hovered, pick: pick
    ))
  }
}

/// The shape of the highlight under an item
public enum ScrubHighlight: Sendable {
  case capsule
  case rounded(CGFloat)

  @ViewBuilder func fill(_ style: some ShapeStyle) -> some View {
    switch self {
    case .capsule: Capsule().fill(style)
    case .rounded(let radius): RoundedRectangle(cornerRadius: radius, style: .continuous).fill(style)
    }
  }
}

/// What the highlight does under a sliding finger
public enum ScrubFollow: Sendable {
  /// Rides along under the finger itself, item-sized (a row of equal slots)
  case finger
  /// Jumps from item to item as the finger crosses them (a list of rows)
  case item
}

/// The one finger of a scrub, shared by the groups on a screen: where it is in the window
/// while it is down, where it lifted, and a count of its lifts
@MainActor @Observable
public final class ScrubSession {
  private static let feedbackDelay = Duration.milliseconds(180)

  public private(set) var point: CGPoint?
  public private(set) var lastPoint: CGPoint?
  public private(set) var showsFeedback = false
  @ObservationIgnored public private(set) var liftPoint: CGPoint?
  @ObservationIgnored public private(set) var lastLiftWasTap = true
  public private(set) var lifts = 0
  @ObservationIgnored private var moved = false
  @ObservationIgnored private var claimedLift = 0
  @ObservationIgnored private var feedbackTask: Task<Void, Never>?

  public init() {}

  func move(from start: CGPoint, to point: CGPoint) {
    let began = self.point == nil
    guard self.point != point else { return }
    lastPoint = point
    self.point = point
    if hypot(point.x - start.x, point.y - start.y) >= 8 {
      moved = true
      if !showsFeedback {
        feedbackTask?.cancel()
        feedbackTask = nil
        showsFeedback = true
      }
    } else if began {
      feedbackTask?.cancel()
      feedbackTask = Task { @MainActor [weak self] in
        do { try await Task.sleep(for: Self.feedbackDelay) } catch { return }
        guard let self, self.point != nil else { return }
        self.showsFeedback = true
      }
    }
  }

  /// A lift belongs to one group, even when choosing it reveals another group underneath.
  func claimLift() -> Bool {
    guard lifts > claimedLift else { return false }
    claimedLift = lifts
    return true
  }

  func lift() {
    feedbackTask?.cancel()
    feedbackTask = nil
    liftPoint = point
    lastLiftWasTap = !moved
    point = nil
    if showsFeedback { showsFeedback = false }
    moved = false
    lifts += 1
  }
}

extension EnvironmentValues {
  /// The finger shared by the scrub groups under this view; a group without one keeps its own
  @Entry public var scrubSession: ScrubSession?
}

/// Where each item of a group sits, by id, in the window's space, and the group itself
@MainActor @Observable
final class ScrubFrames {
  var frames: [AnyHashable: CGRect] = [:]
  var bounds: CGRect = .zero

  func setFrame(_ frame: CGRect, for id: AnyHashable) {
    guard frames[id] != frame else { return }
    frames[id] = frame
  }

  func removeFrame(for id: AnyHashable) { frames[id] = nil }

  func setBounds(_ bounds: CGRect) {
    guard self.bounds != bounds else { return }
    self.bounds = bounds
  }
}

extension EnvironmentValues {
  @Entry var scrubFrames: ScrubFrames?
}

private struct ScrubSurface<Surface: Shape>: ViewModifier {
  let shape: Surface
  @Environment(\.scrubSession) private var session

  func body(content: Content) -> some View {
    content
      .overlay {
        if let session { ScrubLight(session: session).clipShape(shape) }
      }
      .highPriorityGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
          .onChanged { session?.move(from: $0.startLocation, to: $0.location) }
          .onEnded { _ in session?.lift() }
      )
  }
}

/// One circular falloff across the whole surface, independent of item sizes and insets.
/// Keeping it outside the groups also preserves its position as the pill becomes a menu.
private struct ScrubLight: View {
  let session: ScrubSession
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.floatingTabBarStyle) private var style

  private static let radius: CGFloat = 130

  var body: some View {
    GeometryReader { proxy in
      let bounds = proxy.frame(in: .global)
      let point = session.point ?? session.lastPoint ?? CGPoint(x: bounds.midX, y: bounds.midY)
      let inside = session.showsFeedback && (session.point.map { bounds.contains($0) } ?? false)
      Circle()
        .fill(RadialGradient(
          stops: [
            .init(color: style.glow.opacity(0.09), location: 0),
            .init(color: style.glow.opacity(0.055), location: 0.3),
            .init(color: style.glow.opacity(0.018), location: 0.65),
            .init(color: style.glow.opacity(0), location: 1),
          ],
          center: .center, startRadius: 0, endRadius: Self.radius
        ))
        .frame(width: Self.radius * 2, height: Self.radius * 2)
        .position(x: point.x - bounds.minX, y: point.y - bounds.minY)
        .animation(nil, value: point)
        .blendMode(.plusLighter)
        .opacity(inside && !reduceTransparency ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: inside)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private struct ScrubItem: ViewModifier {
  let id: AnyHashable
  @Environment(\.scrubFrames) private var store

  func body(content: Content) -> some View {
    content
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { store?.setFrame($0, for: id) }
      .onDisappear { store?.removeFrame(for: id) }
  }
}

private struct ScrubGroup<ID: Hashable>: ViewModifier {
  let selected: ID?
  let highlight: ScrubHighlight
  let follows: ScrubFollow
  let isEnabled: Bool
  let ignoresHoverNear: CGPoint?
  let hoverRadius: CGFloat
  let tapOnly: Set<ID>
  let hoveredOut: Binding<ID?>?
  let pick: (ID) -> Void
  @Environment(\.scrubSession) private var shared
  @Environment(\.floatingTabBarStyle) private var style
  @State private var own = ScrubSession()
  @State private var store = ScrubFrames()

  private var session: ScrubSession { shared ?? own }

  private var allowsHover: Bool {
    guard let origin = ignoresHoverNear, let point = session.point else { return true }
    return hypot(point.x - origin.x, point.y - origin.y) >= hoverRadius
  }

  /// The item under the shared finger, if it is over this group
  private var hovered: ID? {
    guard isEnabled, allowsHover,
          let id = session.point.flatMap(item(at:)), !tapOnly.contains(id) else { return nil }
    return id
  }

  /// Only the bar rides with a drag; menu rows and committed selections change immediately.
  private static var ride: Animation { .spring(duration: 0.22, bounce: 0) }

  func body(content: Content) -> some View {
    content
      .background { marks }
      .background {
        if shared == nil { ScrubLight(session: own) }
      }
      .environment(\.scrubFrames, store)
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { store.setBounds($0) }
      // With no surface around it, the group takes its own touches
      .highPriorityGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
          .onChanged { session.move(from: $0.startLocation, to: $0.location) }
          .onEnded { _ in session.lift() },
        isEnabled: isEnabled && shared == nil
      )
      // The lift picks here when it landed here, whichever group's finger it was
      .onChange(of: session.lifts) {
        guard isEnabled else { return }
        if let point = session.liftPoint,
           let id = item(at: point),
           (!tapOnly.contains(id) || session.lastLiftWasTap),
           session.claimLift() {
          pick(id)
        }
      }
      .onChange(of: hovered) { _, new in hoveredOut?.wrappedValue = new }
      // A tick on each item the slide crosses, none for the one it starts on
      .sensoryFeedback(.selection, trigger: hovered) { old, new in old != nil && new != nil }
  }

  private func item(at point: CGPoint) -> ID? {
    store.frames.first { $0.value.contains(point) }?.key.base as? ID
  }

  /// A window point in this group's own space
  private func local(_ point: CGPoint) -> CGPoint {
    CGPoint(x: point.x - store.bounds.minX, y: point.y - store.bounds.minY)
  }

  private func frame(of id: ID) -> CGRect? {
    store.frames[AnyHashable(id)].map { CGRect(origin: local($0.origin), size: $0.size) }
  }

  /// The highlight under the chosen item, or under the finger while it slides
  @ViewBuilder private var marks: some View {
    let point = isEnabled && allowsHover && session.showsFeedback ? session.point.map(local) : nil
    let isScrubbing = point != nil
    let inside = point.map { CGRect(origin: .zero, size: store.bounds.size).contains($0) } ?? false
    ZStack(alignment: .topLeading) {
      if let frame = highlightFrame(finger: inside ? point : nil, isScrubbing: isScrubbing) {
        highlight.fill(style.highlight)
          .frame(width: frame.width, height: frame.height)
          .position(x: frame.midX, y: frame.midY)
          // A held item gains a little separation without moving its measured frame.
          // Keeping the geometry fixed avoids feedback loops while the finger scrubs.
          .brightness(isScrubbing ? 0.035 : 0)
          .shadow(color: style.glow.opacity(isScrubbing ? 0.16 : 0), radius: 5, y: 1)
          .animation(.easeOut(duration: 0.1), value: isScrubbing)
          .animation(hovered != nil && follows == .finger ? Self.ride : nil, value: frame)
      }
    }
    .allowsHitTesting(false)
  }

  /// Where the highlight sits: under the finger while it is over an item, nowhere while an
  /// active finger is outside the items, and back on the committed item after the lift.
  private func highlightFrame(finger: CGPoint?, isScrubbing: Bool) -> CGRect? {
    if let finger, let hovered, let frame = frame(of: hovered) {
      switch follows {
      case .item:
        return frame
      case .finger:
        let all = store.frames.values.map { CGRect(origin: local($0.origin), size: $0.size) }
        let xs = all.map(\.midX), ys = all.map(\.midY)
        // Items stacked in a column ride the finger up and down instead of across
        if (ys.max() ?? 0) - (ys.min() ?? 0) > (xs.max() ?? 0) - (xs.min() ?? 0) {
          let y = min(max(finger.y, ys.min() ?? frame.midY), ys.max() ?? frame.midY)
          return CGRect(x: frame.minX, y: y - frame.height / 2, width: frame.width, height: frame.height)
        }
        let x = min(max(finger.x, xs.min() ?? frame.midX), xs.max() ?? frame.midX)
        return CGRect(x: x - frame.width / 2, y: frame.minY, width: frame.width, height: frame.height)
      }
    }
    if isScrubbing { return nil }
    return selected.flatMap(frame(of:))
  }
}
