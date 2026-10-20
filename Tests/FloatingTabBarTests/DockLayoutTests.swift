import CoreGraphics
@testable import FloatingTabBar
import Testing

struct DockLayoutTests {
  /// Four pinned tabs and the last slot, as the app has them, on a 370 pt wide dock
  private func layout(searchTakesSlot: Bool) -> DockLayout {
    DockLayout(slots: 5, searchTakesSlot: searchTakesSlot, inset: 5, gap: 8, button: 50)
  }

  private func slotWidth(pill: CGFloat, slots: Int) -> CGFloat { (pill - 2 * 5) / CGFloat(slots) }

  @Test func pillTakesWhatTheAccessoryLeaves() {
    let spans = layout(searchTakesSlot: false).spans(width: 370, roles: [.pill, .accessory])
    #expect(spans[0].x == 0 && spans[0].width == 312)
    #expect(spans[1].x == 320 && spans[1].width == 50)
  }

  @Test func searchKeepsTheSlotWidthWithEqualGaps() {
    let plain = layout(searchTakesSlot: false).spans(width: 370, roles: [.pill, .accessory])
    let searched = layout(searchTakesSlot: true).spans(width: 370, roles: [.pill, .search, .accessory])

    // One tab fewer in the pill, each slot as wide as before
    #expect(abs(slotWidth(pill: searched[0].width, slots: 4) - slotWidth(pill: plain[0].width, slots: 5)) < 0.001)
    let before = searched[1].x - searched[0].width
    let after = searched[2].x - (searched[1].x + searched[1].width)
    #expect(abs(before - after) < 0.001)
    #expect(abs(searched[2].x + searched[2].width - 370) < 0.001)
  }

  @Test func searchWaitingBehindTheOpenMenuTakesNoWidth() {
    let spans = layout(searchTakesSlot: false).spans(width: 370, roles: [.pill, .search, .accessory])
    #expect(spans[0].width == 312)
    #expect(spans[1].x + spans[1].width == spans[0].width)
    #expect(spans[2].x == 320)
  }

  @Test func withoutAnAccessoryThePillRunsToTheEdge() {
    let spans = layout(searchTakesSlot: false).spans(width: 370, roles: [.pill])
    #expect(spans[0].width == 370)
  }
}
