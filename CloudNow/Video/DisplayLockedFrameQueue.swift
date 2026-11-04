import Foundation

/// The image queue samples at vsync, the same instant `CADisplayLink` fires. Enqueuing on the
/// tick leaves about 1 ms of margin, so scheduling jitter lands two frames in one sample window
/// and the older one is evicted. Releasing three quarters into the refresh keeps a quarter refresh
/// (about 8 ms at 30 Hz) of margin before the next sample, far above the measured ~2 ms release
/// jitter, while letting frames that arrive later in the refresh still make that sample.
nonisolated enum DisplayLockedReleasePhase {
    static let fraction = 0.75

    /// Delay from `now` until `fraction` of the way through the refresh that began at
    /// `refreshTimestamp`. A tick that runs past that point releases immediately.
    static func releaseDelay(
        refreshTimestamp: TimeInterval,
        refreshInterval: TimeInterval,
        now: TimeInterval
    ) -> TimeInterval {
        guard refreshInterval > 0 else { return 0 }
        let target = refreshTimestamp + refreshInterval * fraction
        return min(max(0, target - now), refreshInterval * fraction)
    }
}

/// Releases at most one decoded frame per display refresh. Immediate-display enqueues let
/// two network-bunched frames land in the same refresh, so the image queue evicts the first
/// and the next late frame repeats on glass. Holding one extra frame turns that burst-and-gap
/// pair into even cadence. A backlog that persists for `backlogTrimRefreshes` consecutive
/// refreshes is trimmed so stable delivery does not keep the extra frame of latency.
nonisolated struct DisplayLockedFrameQueue<Element> {
    nonisolated struct Release {
        let presented: Element?
        let trimmed: Element?
    }

    static var defaultCapacity: Int {
        2
    }

    let capacity: Int
    let backlogTrimRefreshes: Int
    private var frames: [Element] = []
    private var backlogRefreshes = 0

    init(capacity: Int = Self.defaultCapacity, backlogTrimRefreshes: Int) {
        self.capacity = max(1, capacity)
        self.backlogTrimRefreshes = max(1, backlogTrimRefreshes)
    }

    var count: Int {
        frames.count
    }

    /// Returns the oldest frame when the queue overflows.
    mutating func push(_ element: Element) -> Element? {
        frames.append(element)
        guard frames.count > capacity else { return nil }
        return frames.removeFirst()
    }

    mutating func releaseForRefresh() -> Release {
        guard !frames.isEmpty else {
            backlogRefreshes = 0
            return Release(presented: nil, trimmed: nil)
        }
        var trimmed: Element?
        if frames.count > 1 {
            backlogRefreshes += 1
            if backlogRefreshes >= backlogTrimRefreshes {
                trimmed = frames.removeFirst()
                backlogRefreshes = 0
            }
        } else {
            backlogRefreshes = 0
        }
        return Release(presented: frames.removeFirst(), trimmed: trimmed)
    }

    mutating func removeAll() -> [Element] {
        defer {
            frames.removeAll()
            backlogRefreshes = 0
        }
        return frames
    }
}
