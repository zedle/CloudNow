@testable import CloudNow
import Testing

@Suite("Analog stick deadzone hysteresis")
struct AnalogStickDeadzoneFilterTests {
    private let deadzone: Float = 0.15

    @Test("Inactive stick stays zero below the enter threshold")
    func inactiveBelowEnterIsZero() {
        var filter = AnalogStickDeadzoneFilter()
        let sample = filter.apply(x: 0.14, y: 0, deadzone: deadzone)

        #expect(sample == (0, 0))
        #expect(filter.isActive == false)
    }

    @Test("Crossing the enter threshold activates and remaps the stick")
    func enterThresholdActivates() {
        var filter = AnalogStickDeadzoneFilter()
        let sample = filter.apply(x: 0.16, y: 0, deadzone: deadzone)

        #expect(sample.0 > 0)
        #expect(sample.1 == 0)
        #expect(filter.isActive == true)
    }

    @Test("Active stick stays live between exit and enter thresholds")
    func hysteresisKeepsActiveBelowEnter() {
        var filter = AnalogStickDeadzoneFilter()
        _ = filter.apply(x: 0.20, y: 0, deadzone: deadzone)

        // exit = deadzone * 0.65 = 0.0975; 0.12 is between exit and enter.
        let sample = filter.apply(x: 0.12, y: 0, deadzone: deadzone)

        #expect(sample.0 > 0, "release band must stay polarity-correct, not invert")
        #expect(sample.1 == 0)
        #expect(filter.isActive == true)
    }

    @Test("Release-band remapping keeps the same sign as the physical axis")
    func hysteresisBandPreservesSign() {
        var filter = AnalogStickDeadzoneFilter()
        _ = filter.apply(x: -0.40, y: 0, deadzone: deadzone)

        let sample = filter.apply(x: -0.12, y: 0, deadzone: deadzone)

        #expect(sample.0 < 0)
        #expect(sample.1 == 0)
        #expect(filter.isActive == true)
    }

    @Test("Dropping through the exit threshold returns to zero")
    func exitThresholdClears() {
        var filter = AnalogStickDeadzoneFilter()
        _ = filter.apply(x: 0.20, y: 0, deadzone: deadzone)
        _ = filter.apply(x: 0.12, y: 0, deadzone: deadzone)

        let sample = filter.apply(x: 0.09, y: 0, deadzone: deadzone)

        #expect(sample == (0, 0))
        #expect(filter.isActive == false)
    }

    @Test("Reset drops hysteresis so a mid-band sample is zero again")
    func resetClearsHysteresis() {
        var filter = AnalogStickDeadzoneFilter()
        _ = filter.apply(x: 0.20, y: 0, deadzone: deadzone)
        filter.reset()

        let sample = filter.apply(x: 0.12, y: 0, deadzone: deadzone)

        #expect(sample == (0, 0))
        #expect(filter.isActive == false)
    }

    @Test("Exact enter magnitude does not activate until magnitude exceeds deadzone")
    func exactEnterStaysInactive() {
        var filter = AnalogStickDeadzoneFilter()
        let sample = filter.apply(x: deadzone, y: 0, deadzone: deadzone)

        #expect(sample == (0, 0))
        #expect(filter.isActive == false)
    }
}
