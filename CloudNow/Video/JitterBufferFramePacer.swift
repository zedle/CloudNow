import Foundation

/// Video presentation strategy for the decoded-frame renderer.
nonisolated enum FramePacingMode: Sendable, Equatable {
    /// Present every frame on arrival.
    case immediate
    /// Bounded one-frame smoothing (`AdaptiveFramePacer`).
    case adaptive
    /// Native GeForce NOW playout model (`JitterBufferFramePacer`).
    case jitterBuffer
}

/// Port of the native GeForce NOW client's `FrameTiming::nextPresentationTimestamp`.
///
/// Each frame is scheduled at its capture time plus the smoothed capture-to-arrival offset
/// plus an adaptive advance. The advance tracks the 99.7th percentile of arrival jitter
/// (inter-arrival minus inter-capture spacing), clamped to 8-32 ms, after a 20 ms warm-up.
/// Presentation never strays more than one advance from arrival and never moves backwards.
nonisolated struct JitterBufferFramePacer: Sendable {
    static let warmupFrames = 100
    static let rampFrames = 100
    static let warmupAdvance: TimeInterval = 0.020
    static let minimumAdvance: TimeInterval = 0.008
    static let maximumAdvance: TimeInterval = 0.032
    static let jitterOutlierLimit: TimeInterval = 0.075
    static let jitterQuantile = 0.997
    static let quantileConvergence = 0.002
    /// Exponential moving-average weights for 3600-sample jitter and 60-sample offset windows.
    static let jitterSmoothing = 2.0 / 3601
    static let offsetSmoothing = 2.0 / 61

    private static let rtpClockRate = 90000.0

    private(set) var frameCount = 0
    private var previousTimestamp: UInt32?
    private var captureTime: TimeInterval = 0
    private var previousArrival: TimeInterval = 0
    private var offsetMean: TimeInterval = 0
    private var offsetVariance: TimeInterval = 0
    private var jitterMean: TimeInterval = 0
    private var jitterVariance: TimeInterval = 0
    private(set) var jitterEstimate: TimeInterval = 0
    private var lastPresentation: TimeInterval = 0

    /// Current playout advance added to the smoothed arrival time.
    var advance: TimeInterval {
        guard frameCount >= Self.warmupFrames else { return Self.warmupAdvance }
        let bounded = min(max(jitterEstimate, Self.minimumAdvance), Self.maximumAdvance)
        let rampProgress = Double(frameCount - Self.warmupFrames) / Double(Self.rampFrames)
        guard rampProgress < 1 else { return bounded }
        return Self.warmupAdvance + (bounded - Self.warmupAdvance) * rampProgress
    }

    /// Returns the presentation time for a frame on the same clock as `arrivalTime`.
    mutating func presentationTime(rtpTimestamp: UInt32, arrivalTime: TimeInterval) -> TimeInterval {
        let captureDelta = previousTimestamp.map { Int32(bitPattern: rtpTimestamp &- $0) } ?? 0
        previousTimestamp = rtpTimestamp

        if captureDelta <= 0 {
            // First frame, duplicate, or backwards timestamp: restart the estimators.
            frameCount = 0
            captureTime = 0
            offsetMean = arrivalTime
            offsetVariance = 0
            jitterEstimate = 0
        } else {
            let interval = Double(captureDelta) / Self.rtpClockRate
            let expectedArrival = previousArrival + interval
            captureTime += interval
            updateOffset(arrivalTime - captureTime)
            if frameCount >= Self.warmupFrames {
                updateJitter(arrivalTime - expectedArrival)
            }
        }
        previousArrival = arrivalTime

        let advance = advance
        let target = captureTime + offsetMean + advance
        let bounded = min(max(target, arrivalTime - advance), arrivalTime + advance)
        let presentation = max(bounded, lastPresentation)
        lastPresentation = presentation
        frameCount += 1
        return presentation
    }

    mutating func reset() {
        self = Self()
    }

    private mutating func updateOffset(_ offset: TimeInterval) {
        let weight = Self.offsetSmoothing
        let difference = offset - offsetMean
        offsetVariance = (1 - weight) * (offsetVariance + weight * difference * difference)
        offsetMean = (1 - weight) * offsetMean + weight * offset
    }

    private mutating func updateJitter(_ sample: TimeInterval) {
        let jitter = min(max(sample, -Self.jitterOutlierLimit), Self.jitterOutlierLimit)
        let weight = Self.jitterSmoothing
        let difference = jitter - jitterMean
        jitterVariance = (1 - weight) * (jitterVariance + weight * difference * difference)
        jitterMean = (1 - weight) * jitterMean + weight * jitter

        let magnitude = abs(jitter)
        guard jitterEstimate != 0 else {
            jitterEstimate = magnitude
            return
        }
        let step = jitterVariance.squareRoot() * Self.quantileConvergence
        if magnitude < jitterEstimate {
            jitterEstimate -= step / Self.jitterQuantile
        } else if magnitude > jitterEstimate {
            jitterEstimate += step / (1 - Self.jitterQuantile)
        }
    }
}

/// FIFO of frames waiting for their scheduled presentation time.
nonisolated struct ScheduledFrameQueue<Element> {
    /// Native `video.framePacing.maxQueuedFrames` default.
    static var defaultCapacity: Int {
        7
    }

    let capacity: Int
    private var frames: [(element: Element, time: TimeInterval)] = []

    init(capacity: Int = Self.defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    var count: Int {
        frames.count
    }

    var nextPresentationTime: TimeInterval? {
        frames.first?.time
    }

    /// Returns the oldest frame when the queue overflows.
    mutating func push(_ element: Element, presentationTime: TimeInterval) -> Element? {
        frames.append((element, presentationTime))
        guard frames.count > capacity else { return nil }
        return frames.removeFirst().element
    }

    /// Returns the newest frame that is due by `now`, plus older due frames it supersedes.
    mutating func takeDue(now: TimeInterval) -> (presented: Element?, superseded: [Element]) {
        let dueCount = frames.prefix { $0.time <= now }.count
        guard dueCount > 0 else { return (nil, []) }
        let due = frames.prefix(dueCount).map(\.element)
        frames.removeFirst(dueCount)
        return (due.last, Array(due.dropLast()))
    }

    mutating func removeAll() -> [Element] {
        defer { frames.removeAll() }
        return frames.map(\.element)
    }
}
