@testable import CloudNow
import Foundation
import Testing

@Suite("Display-locked frame queue")
struct DisplayLockedFrameQueueTests {
    @Test("Two frames bunched into one refresh are both presented on consecutive refreshes")
    func burstThenGapKeepsEveryFrame() {
        var queue = DisplayLockedFrameQueue<Int>(backlogTrimRefreshes: 30)

        let firstOverflow = queue.push(1)
        let secondOverflow = queue.push(2)
        let burstRefresh = queue.releaseForRefresh()
        let gapRefresh = queue.releaseForRefresh()
        let idleRefresh = queue.releaseForRefresh()

        #expect(firstOverflow == nil)
        #expect(secondOverflow == nil)
        #expect(burstRefresh.presented == 1)
        #expect(burstRefresh.trimmed == nil)
        #expect(gapRefresh.presented == 2)
        #expect(idleRefresh.presented == nil)
    }

    @Test("Overflow drops the oldest frame to bound latency")
    func overflowDropsOldest() {
        var queue = DisplayLockedFrameQueue<Int>(capacity: 2, backlogTrimRefreshes: 30)

        _ = queue.push(1)
        _ = queue.push(2)
        let overflow = queue.push(3)
        let release = queue.releaseForRefresh()

        #expect(overflow == 1)
        #expect(release.presented == 2)
        #expect(queue.count == 1)
    }

    @Test("A standing backlog is trimmed after the configured number of refreshes")
    func standingBacklogIsTrimmed() {
        var queue = DisplayLockedFrameQueue<Int>(backlogTrimRefreshes: 3)
        _ = queue.push(0)

        var releases: [DisplayLockedFrameQueue<Int>.Release] = []
        for frame in 1 ... 3 {
            _ = queue.push(frame)
            releases.append(queue.releaseForRefresh())
        }

        #expect(releases.map(\.presented) == [0, 1, 3])
        #expect(releases.map(\.trimmed) == [nil, nil, 2])
        #expect(queue.count == 0)
    }

    @Test("A gap resets the backlog count so alternating jitter is never trimmed")
    func gapResetsBacklog() {
        var queue = DisplayLockedFrameQueue<Int>(backlogTrimRefreshes: 2)

        var trimmed: [Int] = []
        for burst in 0 ..< 4 {
            _ = queue.push(burst * 2)
            _ = queue.push(burst * 2 + 1)
            for _ in 0 ..< 2 {
                if let frame = queue.releaseForRefresh().trimmed {
                    trimmed.append(frame)
                }
            }
        }

        #expect(trimmed.isEmpty)
    }

    @Test("Removing all frames empties the queue and returns frames in order")
    func removeAll() {
        var queue = DisplayLockedFrameQueue<Int>(backlogTrimRefreshes: 30)
        _ = queue.push(4)
        _ = queue.push(5)

        let removed = queue.removeAll()
        let afterRemoval = queue.releaseForRefresh()

        #expect(removed == [4, 5])
        #expect(afterRemoval.presented == nil)
    }

    @Test("Release lands a quarter refresh before the next vsync sample point")
    func releaseDelayTargetsLateRefresh() {
        let releaseOffset: TimeInterval = 0.025
        func delay(at now: TimeInterval) -> TimeInterval {
            DisplayLockedReleasePhase.releaseDelay(refreshTimestamp: 100, refreshInterval: 1.0 / 30, now: now)
        }

        #expect(abs(delay(at: 100.001) - (releaseOffset - 0.001)) < 0.000_001)
        #expect(abs(delay(at: 100.010) - (releaseOffset - 0.010)) < 0.000_001)
        #expect(abs(delay(at: 100.020) - (releaseOffset - 0.020)) < 0.000_001)
        #expect(delay(at: 100.030) == 0)
        #expect(abs(delay(at: 99.990) - releaseOffset) < 0.000_001)
    }

    @Test("A non-positive refresh interval releases immediately")
    func releaseDelayWithoutInterval() {
        #expect(DisplayLockedReleasePhase.releaseDelay(refreshTimestamp: 100, refreshInterval: 0, now: 100) == 0)
    }
}
