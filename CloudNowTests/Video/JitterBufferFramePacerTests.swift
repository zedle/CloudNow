@testable import CloudNow
import Testing

@Suite("Native jitter-buffer frame pacing")
struct JitterBufferFramePacerTests {
    private static let frameTicks = 1500
    private static let frameInterval = 1.0 / 60

    @Test("Warm-up holds frames 20 ms after arrival")
    func warmupAdvance() {
        var pacer = JitterBufferFramePacer()

        for index in 0 ..< 50 {
            let arrival = 1.0 + Double(index) * Self.frameInterval
            let presentation = pacer.presentationTime(
                rtpTimestamp: UInt32(index * Self.frameTicks),
                arrivalTime: arrival
            )
            #expect(abs(presentation - (arrival + 0.020)) < 0.000_001)
        }
    }

    @Test("Steady delivery settles on the 8 ms minimum advance after the ramp")
    func steadyDeliveryUsesMinimumAdvance() {
        var pacer = JitterBufferFramePacer()
        var lastDelay = 0.0

        for index in 0 ..< 300 {
            let arrival = Double(index) * Self.frameInterval
            let presentation = pacer.presentationTime(
                rtpTimestamp: UInt32(index * Self.frameTicks),
                arrivalTime: arrival
            )
            lastDelay = presentation - arrival
        }

        #expect(abs(pacer.advance - JitterBufferFramePacer.minimumAdvance) < 0.000_001)
        #expect(abs(lastDelay - JitterBufferFramePacer.minimumAdvance) < 0.000_1)
    }

    @Test("Late network spikes are absorbed back onto the server cadence")
    func jitterIsAbsorbed() {
        var pacer = JitterBufferFramePacer()
        var network = SpikyNetwork(seed: 7, frameInterval: Self.frameInterval)
        var arrivalDeviation = 0.0
        var presentationDeviation = 0.0
        var previous: (arrival: Double, presentation: Double)?

        for index in 0 ..< 1500 {
            let arrival = network.nextArrival(index: index)
            let presentation = pacer.presentationTime(
                rtpTimestamp: UInt32(index * Self.frameTicks),
                arrivalTime: arrival
            )
            if index >= 600, let previous {
                arrivalDeviation += abs(arrival - previous.arrival - Self.frameInterval)
                presentationDeviation += abs(presentation - previous.presentation - Self.frameInterval)
            }
            previous = (arrival, presentation)
        }

        #expect(pacer.advance > JitterBufferFramePacer.minimumAdvance)
        #expect(pacer.advance <= JitterBufferFramePacer.maximumAdvance)
        #expect(presentationDeviation < arrivalDeviation / 2)
    }

    @Test("Presentation never moves backwards or exceeds the maximum advance after arrival")
    func presentationBounds() {
        var pacer = JitterBufferFramePacer()
        var network = SpikyNetwork(seed: 42, frameInterval: Self.frameInterval)
        var previous = -Double.infinity

        for index in 0 ..< 600 {
            let arrival = network.nextArrival(index: index) + (index.isMultiple(of: 37) ? 0.060 : 0)
            network.holdUntil(arrival)
            let presentation = pacer.presentationTime(
                rtpTimestamp: UInt32(index * Self.frameTicks),
                arrivalTime: arrival
            )
            #expect(presentation >= previous)
            #expect(presentation <= arrival + JitterBufferFramePacer.maximumAdvance + 0.000_001)
            previous = presentation
        }
    }

    @Test("Duplicate or backwards timestamps restart the warm-up", arguments: [0, 299 * 1500] as [UInt32])
    func discontinuityResets(timestamp: UInt32) {
        var pacer = JitterBufferFramePacer()
        for index in 0 ..< 300 {
            _ = pacer.presentationTime(
                rtpTimestamp: UInt32(index * Self.frameTicks),
                arrivalTime: Double(index) * Self.frameInterval
            )
        }

        let arrival = 300 * Self.frameInterval
        let presentation = pacer.presentationTime(rtpTimestamp: timestamp, arrivalTime: arrival)

        #expect(pacer.frameCount == 1)
        #expect(abs(presentation - (arrival + JitterBufferFramePacer.warmupAdvance)) < 0.000_001)
    }

    @Test("RTP timestamp rollover keeps the learned timing")
    func rtpRollover() {
        var pacer = JitterBufferFramePacer()
        let start = UInt32.max - UInt32(150 * Self.frameTicks)
        for index in 0 ..< 300 {
            _ = pacer.presentationTime(
                rtpTimestamp: start &+ UInt32(index * Self.frameTicks),
                arrivalTime: Double(index) * Self.frameInterval
            )
        }

        #expect(pacer.frameCount == 300)
        #expect(abs(pacer.advance - JitterBufferFramePacer.minimumAdvance) < 0.000_001)
    }

    @Test("Scheduled queue drops the oldest frame past its native capacity")
    func scheduledQueueOverflow() {
        var queue = ScheduledFrameQueue<Int>(capacity: 2)

        #expect(queue.push(1, presentationTime: 1) == nil)
        #expect(queue.push(2, presentationTime: 2) == nil)
        #expect(queue.push(3, presentationTime: 3) == 1)
        #expect(queue.count == 2)
        #expect(queue.nextPresentationTime == 2)
        #expect(ScheduledFrameQueue<Int>.defaultCapacity == 7)
    }

    @Test("Scheduled queue presents the newest due frame and supersedes older due frames")
    func scheduledQueueTakeDue() {
        var queue = ScheduledFrameQueue<Int>()
        _ = queue.push(1, presentationTime: 1)
        _ = queue.push(2, presentationTime: 2)
        _ = queue.push(3, presentationTime: 5)

        let early = queue.takeDue(now: 0.5)
        let due = queue.takeDue(now: 2.5)

        #expect(early.presented == nil)
        #expect(early.superseded.isEmpty)
        #expect(due.presented == 2)
        #expect(due.superseded == [1])
        #expect(queue.nextPresentationTime == 5)
        #expect(queue.removeAll() == [3])
    }
}

/// In-order arrivals with sub-millisecond noise and occasional 4-14 ms queuing spikes.
private struct SpikyNetwork {
    private var random: LinearCongruentialGenerator
    private let frameInterval: Double
    private var lastArrival = -Double.infinity

    init(seed: UInt64, frameInterval: Double) {
        random = LinearCongruentialGenerator(seed: seed)
        self.frameInterval = frameInterval
    }

    mutating func nextArrival(index: Int) -> Double {
        let noise = random.nextUnit() * 0.001
        let spike = random.nextUnit() < 0.1 ? 0.004 + random.nextUnit() * 0.010 : 0
        lastArrival = max(lastArrival, Double(index) * frameInterval + noise + spike)
        return lastArrival
    }

    mutating func holdUntil(_ arrival: Double) {
        lastArrival = max(lastArrival, arrival)
    }
}

private struct LinearCongruentialGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextUnit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }
}
