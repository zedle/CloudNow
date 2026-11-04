@testable import CloudNow
import Testing

@Suite("Overlay long-press gesture")
struct OverlayLongPressGestureTests {
    @Test("A held trigger reaches the game before the long press fires")
    func forwardsWhileHeldBelowThreshold() {
        var gesture = OverlayLongPressGesture(thresholdTicks: 4)

        for _ in 0 ..< 3 {
            #expect(gesture.advance() == false)
            #expect(gesture.forwardsTriggerToGame)
        }
    }

    @Test("The long press fires exactly once and then masks the trigger")
    func firesOnceThenMasks() {
        var gesture = OverlayLongPressGesture(thresholdTicks: 4)

        var fired: [Bool] = []
        for _ in 0 ..< 10 {
            fired.append(gesture.advance())
        }

        #expect(fired.filter { $0 }.count == 1)
        #expect(fired[3])
        #expect(gesture.forwardsTriggerToGame == false)
    }

    @Test("Default threshold keeps the 1.8 second hold at 120 Hz")
    func defaultThreshold() {
        var gesture = OverlayLongPressGesture()

        for _ in 0 ..< 215 {
            #expect(gesture.advance() == false)
        }
        let fired = gesture.advance()
        #expect(fired)
    }

    @Test("A hold carried across resume is suppressed until release")
    func suppressedUntilRelease() {
        var gesture = OverlayLongPressGesture.suppressedUntilRelease()

        #expect(gesture.forwardsTriggerToGame == false)
        #expect(gesture.advance() == false)
    }
}
