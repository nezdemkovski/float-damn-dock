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

  @Test func overlappingFramesPickTheNearestCenter() {
    let frames = ScrubFrames()
    // An item fading out still overlaps the one taking its place
    frames.setFrame(CGRect(x: 0, y: 0, width: 100, height: 40), for: "outgoing")
    frames.setFrame(CGRect(x: 60, y: 0, width: 100, height: 40), for: "incoming")

    #expect(frames.item(at: CGPoint(x: 70, y: 20)) == AnyHashable("outgoing"))
    #expect(frames.item(at: CGPoint(x: 90, y: 20)) == AnyHashable("incoming"))
    #expect(frames.item(at: CGPoint(x: 200, y: 20)) == nil)
  }

  @Test func liftWhereTheHoldRestedPicksNothing() {
    let session = ScrubSession()
    let point = CGPoint(x: 180, y: 700)
    session.move(from: point, to: point)
    session.hold()
    #expect(session.isResting)
    // A tremor within the slop is still resting
    session.move(from: point, to: CGPoint(x: 185, y: 700))
    #expect(session.isResting)
    session.lift()

    #expect(!session.isResting)
    #expect(!session.claimLift()) // The menu the hold opened stays up.

    session.move(from: point, to: point)
    session.lift()
    #expect(session.claimLift()) // The next tap picks again.
  }

  @Test func slidingAwayFromTheHoldPicksOnLift() {
    let session = ScrubSession()
    let point = CGPoint(x: 180, y: 700)
    session.move(from: point, to: point)
    session.hold()
    session.move(from: point, to: CGPoint(x: 180, y: 640))
    #expect(!session.isResting)
    session.lift()
    #expect(session.claimLift())
  }
}
