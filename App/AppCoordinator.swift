import AppKit
import SwiftUI
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    let settings = SettingsStore.shared
    let keyboard = KeyboardMonitor()
    let clipboard = ClipboardMonitor()
    let tips: TipCoordinator
    @Published private(set) var permissionGranted = PermissionsManager.inputMonitoringGranted
    @Published private(set) var monitoringActive = false
    private var copySettingObserver: AnyCancellable?
    private var activationObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private(set) var settingsWindow: NSWindow?
    private var settingsRequested = false

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
            if !self.monitorsOtherCopies { self.clipboard.start(baseline: changeCount, at: time) }
        }
        keyboard.onPaste = { [weak self] in
            guard let self else { return }
            self.observeCurrentClipboard()
            if !self.monitorsOtherCopies { self.clipboard.stop() }
            self.correlator.supersedeWithPaste(at: ProcessInfo.processInfo.systemUptime)
            self.tips.show(.paste)
        }
        keyboard.onCapsLock = { [weak self] state in self?.tips.show(.capsLock, state: state) }
        clipboard.onChange = { [weak self] count, time in
            guard let self else { return }
            self.handleClipboardChange(count: count, at: time)
        }
        correlator = ClipboardEventCorrelator(initialChangeCount: NSPasteboard.general.changeCount)
        configureClipboardMonitoring()
        copySettingObserver = Publishers.CombineLatest(settings.$showAnyCopy, settings.$showCopy).dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.configureClipboardMonitoring() }
        }
        refreshPermission()
    }

    private var monitorsOtherCopies: Bool { settings.showAnyCopy && settings.showCopy }

    private func configureClipboardMonitoring() {
        clipboard.stop()
        let count = NSPasteboard.general.changeCount
        correlator.synchronize(changeCount: count)
        if monitorsOtherCopies {
            clipboard.start(baseline: count, at: ProcessInfo.processInfo.systemUptime, continuous: true)
        } else if let pending = correlator.pending.last {
            clipboard.start(baseline: pending.baseline, at: pending.time)
        }
    }

    private var correlator: ClipboardEventCorrelator!

    func showSettings() {
        settingsRequested = true
        guard let window = settingsWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func registerSettingsWindow(_ window: NSWindow) {
        guard settingsWindow == nil else { return }
        settingsWindow = window
        window.isReleasedWhenClosed = false
        if settingsRequested { showSettings() }
    }

    private func observeCurrentClipboard() {
        guard !correlator.pending.isEmpty else { return }
        handleClipboardChange(count: NSPasteboard.general.changeCount, at: ProcessInfo.processInfo.systemUptime)
    }

    private func handleClipboardChange(count: Int, at time: TimeInterval) {
        let hasContent = !(NSPasteboard.general.types ?? []).isEmpty
        let outputs = correlator.clipboardChanged(to: count, at: time,
                                                  allowUnsolicited: monitorsOtherCopies,
                                                  hasContent: hasContent)
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
        else { keyboard.stop(); if !monitorsOtherCopies { clipboard.stop() }; correlator.supersedeWithPaste(); active = false }
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
