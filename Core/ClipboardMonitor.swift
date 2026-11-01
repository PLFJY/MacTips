import AppKit

@MainActor
final class ClipboardMonitor {
    var onChange: ((Int, TimeInterval) -> Void)?
    private var timer: Timer?
    var isMonitoring: Bool { timer != nil }

    func start(baseline: Int, at time: TimeInterval) {
        stop()
        let deadline = time + ClipboardEventCorrelator.confirmationWindow
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll(baseline: baseline, deadline: deadline) }
        }
        timer.tolerance = 0.02
        self.timer = timer
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func poll(baseline: Int, deadline: TimeInterval) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now <= deadline else { stop(); return }
        let count = NSPasteboard.general.changeCount
        guard count != baseline else { return }
        stop()
        onChange?(count, now)
    }
}
