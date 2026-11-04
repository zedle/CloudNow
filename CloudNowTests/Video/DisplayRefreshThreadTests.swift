@testable import CloudNow
import Foundation
import os
import Testing

@Suite("Display refresh thread")
struct DisplayRefreshThreadTests {
    private struct Ticks {
        var count = 0
        var sawMainThread = false
    }

    @Test("Refresh ticks arrive off the main thread and stop after stop()")
    func ticksOffMainAndStops() async throws {
        let ticks = OSAllocatedUnfairLock(initialState: Ticks())
        let refresh = DisplayRefreshThread { _ in
            let isMain = Thread.isMainThread
            ticks.withLock {
                $0.count += 1
                $0.sawMainThread = $0.sawMainThread || isMain
            }
        }

        let deadline = ContinuousClock.now + .seconds(5)
        while ticks.withLock(\.count) < 3, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        refresh.stop()
        try await Task.sleep(for: .milliseconds(150))
        let countAfterStop = ticks.withLock(\.count)
        try await Task.sleep(for: .milliseconds(300))
        let final = ticks.withLock { $0 }

        #expect(final.count >= 3)
        #expect(!final.sawMainThread)
        #expect(final.count == countAfterStop)
    }
}
