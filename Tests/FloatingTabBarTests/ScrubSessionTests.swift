import CoreGraphics
@testable import FloatingTabBar
import Testing

@MainActor
struct ScrubSessionTests {
  @Test func hiddenInboxCannotKeepTheMoreHitArea() {
    let frames = ScrubFrames()
    let oldInbox = CGRect(x: 150, y: 700, width: 50, height: 40)
    frames.setFrame(oldInbox, for: "inbox")
    frames.setFrame(oldInbox, for: "more")
    frames.removeFrame(for: "inbox")

    #expect(frames.frames["inbox"] == nil)
    #expect(frames.frames["more"] == oldInbox)
    #expect(frames.frames.count == 1)
  }

  @Test func openingMenuCannotSelectAgainOnTheSameLift() {
    let session = ScrubSession()
    let point = CGPoint(x: 180, y: 700)
    session.move(from: point, to: point)
    session.lift()

    #expect(session.claimLift()) // The bar opens More.
    #expect(!session.claimLift()) // The newly enabled menu must ignore that lift.

    session.move(from: point, to: CGPoint(x: 180, y: 600))
    session.lift()
    #expect(session.claimLift()) // The next gesture can choose a menu item.
  }

  @Test func holdingIntoMenuLeavesTheLiftAvailable() {
    let session = ScrubSession()
    let point = CGPoint(x: 180, y: 700)
    session.move(from: point, to: point)
    #expect(!session.claimLift()) // Opening on hold has not consumed a lift.
    session.move(from: point, to: CGPoint(x: 180, y: 600))
    session.lift()
    #expect(session.claimLift())
    #expect(!session.lastLiftWasTap)
  }
}
