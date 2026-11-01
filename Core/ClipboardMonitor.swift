import AppKit

@MainActor
final class ClipboardMonitor {
    var onChange: ((Int, TimeInterval) -> Void)?
    private var timer: Timer?
    private var lastCount = 0
    private var deadline: TimeInterval?
    var isMonitoring: Bool { timer != nil }

    func start(baseline: Int, at time: TimeInterval, continuous: Bool = false) {
        stop()
        lastCount = baseline
        deadline = continuous ? nil : time + ClipboardEventCorrelator.confirmationWindow
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.04
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func poll() {
        let now = ProcessInfo.processInfo.systemUptime
        if let deadline, now > deadline { stop(); return }
        let count = NSPasteboard.general.changeCount
        guard count != lastCount else { return }
        lastCount = count
        if deadline != nil { stop() }
        onChange?(count, now)
    }
}
