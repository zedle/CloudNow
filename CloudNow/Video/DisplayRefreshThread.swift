import Foundation
import os
import QuartzCore

/// Runs a `CADisplayLink` on a dedicated run loop so main-thread work (SwiftUI, HUD updates,
/// input handling) cannot delay or coalesce the per-refresh frame release. The handler runs on
/// that thread and must be thread-safe.
final nonisolated class DisplayRefreshThread: @unchecked Sendable {
    private nonisolated struct State: @unchecked Sendable {
        var isStopped = false
        var runLoop: CFRunLoop?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let handler: @Sendable (CADisplayLink) -> Void

    init(handler: @escaping @Sendable (CADisplayLink) -> Void) {
        self.handler = handler
        let thread = Thread { [self] in run() }
        thread.name = "com.owenselles.CloudNow2.display-refresh"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// Thread-safe. The thread invalidates its link and exits within one refresh.
    func stop() {
        let runLoop = state.withLock { state -> CFRunLoop? in
            state.isStopped = true
            return state.runLoop
        }
        if let runLoop {
            CFRunLoopStop(runLoop)
        }
    }

    private func run() {
        let target = Target(handler: handler)
        let link = CADisplayLink(target: target, selector: #selector(Target.displayLinkDidFire(_:)))
        let shouldRun = state.withLock { state -> Bool in
            guard !state.isStopped else { return false }
            state.runLoop = CFRunLoopGetCurrent()
            return true
        }
        guard shouldRun else {
            link.invalidate()
            return
        }
        link.add(to: .current, forMode: .default)
        while !state.withLock(\.isStopped) {
            _ = RunLoop.current.run(mode: .default, before: .distantFuture)
        }
        link.invalidate()
    }

    /// `CADisplayLink` retains its target; the target holds only the handler.
    private final nonisolated class Target: NSObject {
        let handler: @Sendable (CADisplayLink) -> Void

        init(handler: @escaping @Sendable (CADisplayLink) -> Void) {
            self.handler = handler
        }

        @objc func displayLinkDidFire(_ link: CADisplayLink) {
            handler(link)
        }
    }
}
