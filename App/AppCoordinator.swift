import AppKit
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    let settings = SettingsStore.shared
    let keyboard = KeyboardMonitor()
    let clipboard = ClipboardMonitor()
    let tips: TipCoordinator
    @Published private(set) var permissionGranted = PermissionsManager.inputMonitoringGranted
    @Published private(set) var monitoringActive = false
    private var activationObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private(set) var settingsWindow: NSWindow?

    init() {
        tips = TipCoordinator(settings: settings)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshPermission() }
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.stop() } }
        keyboard.onClipboardShortcut = { [weak self] intent, changeCount in
            guard let self else { return }
            self.observeCurrentClipboard()
            let time = ProcessInfo.processInfo.systemUptime
            self.correlator.record(intent, changeCount: changeCount, at: time)
            self.clipboard.start(baseline: changeCount, at: time)
        }
        keyboard.onPaste = { [weak self] in
            guard let self else { return }
            self.observeCurrentClipboard()
            self.clipboard.stop()
            self.correlator.supersedeWithPaste()
            self.tips.show(.paste)
        }
        keyboard.onCapsLock = { [weak self] state in self?.tips.show(.capsLock, state: state) }
        clipboard.onChange = { [weak self] count, time in
            guard let self else { return }
            self.handleClipboardChange(count: count, at: time)
        }
        correlator = ClipboardEventCorrelator(initialChangeCount: NSPasteboard.general.changeCount)
        refreshPermission()
    }

    private var correlator: ClipboardEventCorrelator!

    func showSettings() {
        let window: NSWindow
        if let existing = settingsWindow {
            window = existing
        } else {
            let root = SettingsWindowContent(coordinator: self, settings: settings)
            window = NSWindow(contentViewController: NSHostingController(rootView: root))
            window.title = String(localized: "settings.title", locale: settings.activeLocale)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 600, height: 560))
            window.minSize = NSSize(width: 520, height: 490)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        window.title = String(localized: "settings.title", locale: settings.activeLocale)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func observeCurrentClipboard() {
        guard !correlator.pending.isEmpty else { return }
        handleClipboardChange(count: NSPasteboard.general.changeCount, at: ProcessInfo.processInfo.systemUptime)
    }

    private func handleClipboardChange(count: Int, at time: TimeInterval) {
        let outputs = correlator.clipboardChanged(to: count, at: time)
        for output in outputs {
            switch output {
            case .confirmed(let kind): tips.show(kind)
            }
        }
    }

    func refreshPermission() {
        let granted = PermissionsManager.inputMonitoringGranted
        if permissionGranted != granted { permissionGranted = granted }
        let active: Bool
        if granted { active = keyboard.isRunning || keyboard.start() }
        else { keyboard.stop(); clipboard.stop(); correlator.supersedeWithPaste(); active = false }
        if monitoringActive != active { monitoringActive = active }
    }

    func requestPermission() {
        _ = PermissionsManager.requestInputMonitoring()
        refreshPermission()
    }

    func stop() {
        keyboard.stop()
        monitoringActive = false
        clipboard.stop()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        activationObserver = nil
        terminationObserver = nil
    }
}
