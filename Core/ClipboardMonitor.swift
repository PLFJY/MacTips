import AppKit

@MainActor
final class ClipboardMonitor {
    var onChange: ((Int, Bool, TimeInterval) -> Void)?
    private var timer: Timer?
    private var lastCount = NSPasteboard.general.changeCount

    func start() {
        guard timer == nil else { return }
        lastCount = NSPasteboard.general.changeCount
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.1
        self.timer = timer
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func poll() {
        let board = NSPasteboard.general
        let count = board.changeCount
        guard count != lastCount else { return }
        lastCount = count
        // Types are metadata only: never read text, image, file, or other clipboard payloads.
        onChange?(count, !(board.types ?? []).isEmpty, ProcessInfo.processInfo.systemUptime)
    }
}
