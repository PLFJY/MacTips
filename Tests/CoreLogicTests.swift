import XCTest
@testable import MacTips
import ApplicationServices
import AppKit

final class CoreLogicTests: XCTestCase {
    @MainActor
    func testMenuBarVisibilityPersists() {
        let suite = "MacTipsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        XCTAssertTrue(settings.showMenuBarIcon)
        settings.showMenuBarIcon = false
        XCTAssertFalse(SettingsStore(defaults: defaults).showMenuBarIcon)
        settings.showMenuBarIcon = true
        XCTAssertTrue(SettingsStore(defaults: defaults).showMenuBarIcon)
    }

    @MainActor
    func testClipboardMonitorStopsAfterConfirmationWindow() async throws {
        let monitor = ClipboardMonitor()
        XCTAssertFalse(monitor.isMonitoring)
        monitor.start(baseline: NSPasteboard.general.changeCount, at: ProcessInfo.processInfo.systemUptime)
        XCTAssertTrue(monitor.isMonitoring)
        try await Task.sleep(for: .seconds(1.6))
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testCommandShortcutsAndModifiers() {
        let command: CGEventFlags = .maskCommand
        XCTAssertEqual(KeyboardShortcutClassifier.classify(keyCode: 8, flags: command, isRepeat: false), .copy)
        XCTAssertEqual(KeyboardShortcutClassifier.classify(keyCode: 9, flags: command, isRepeat: false), .paste)
        XCTAssertEqual(KeyboardShortcutClassifier.classify(keyCode: 7, flags: command, isRepeat: false), .cut)
        XCTAssertNil(KeyboardShortcutClassifier.classify(keyCode: 8, flags: [], isRepeat: false))
        XCTAssertNil(KeyboardShortcutClassifier.classify(keyCode: 8, flags: .maskControl, isRepeat: false))
        XCTAssertNil(KeyboardShortcutClassifier.classify(keyCode: 8, flags: [.maskCommand, .maskShift], isRepeat: false))
        XCTAssertNil(KeyboardShortcutClassifier.classify(keyCode: 8, flags: [.maskCommand, .maskAlternate], isRepeat: false))
        XCTAssertNil(KeyboardShortcutClassifier.classify(keyCode: 8, flags: command, isRepeat: true))
    }

    func testCopyWaitsForClipboardAndExpires() {
        var correlator = ClipboardEventCorrelator(initialChangeCount: 4)
        correlator.record(.copy, changeCount: 4, at: 10)
        XCTAssertEqual(correlator.clipboardChanged(to: 5, at: 10.1), [.confirmed(.copy)])
        correlator.record(.copy, changeCount: 5, at: 20)
        XCTAssertEqual(correlator.clipboardChanged(to: 5, at: 20.8), [])
    }

    func testCutConfirmationAndPasteClassifier() {
        var correlator = ClipboardEventCorrelator(initialChangeCount: 0)
        correlator.record(.cut, changeCount: 0, at: 1)
        XCTAssertEqual(correlator.clipboardChanged(to: 1, at: 1.1), [.confirmed(.cut)])
        XCTAssertEqual(KeyboardShortcutClassifier.classify(keyCode: 9, flags: .maskCommand, isRepeat: false), .paste)
    }

    func testCutCanBeConfirmedAfterASlowerPoll() {
        var correlator = ClipboardEventCorrelator(initialChangeCount: 0)
        correlator.record(.cut, changeCount: 0, at: 1)
        XCTAssertEqual(correlator.clipboardChanged(to: 1, at: 1.9), [.confirmed(.cut)])
        XCTAssertEqual(correlator.clipboardChanged(to: 2, at: 2.4), [])
    }

    func testNewCutSupersedesUnconfirmedCopy() {
        var correlator = ClipboardEventCorrelator(initialChangeCount: 0)
        correlator.record(.copy, changeCount: 0, at: 1)
        correlator.record(.cut, changeCount: 0, at: 1.1)
        XCTAssertEqual(correlator.clipboardChanged(to: 1, at: 1.2), [.confirmed(.cut)])
    }

    func testPasteSupersedesDelayedClipboardChange() {
        var correlator = ClipboardEventCorrelator(initialChangeCount: 0)
        correlator.record(.cut, changeCount: 0, at: 1)
        correlator.supersedeWithPaste()
        XCTAssertEqual(correlator.clipboardChanged(to: 1, at: 1.2), [])
        correlator.record(.copy, changeCount: 1, at: 1.3)
        XCTAssertEqual(correlator.clipboardChanged(to: 2, at: 1.4), [.confirmed(.copy)])
        correlator.supersedeWithPaste()
        XCTAssertEqual(correlator.clipboardChanged(to: 3, at: 1.8), [])
        XCTAssertEqual(correlator.clipboardChanged(to: 4, at: 2.7), [])
    }

    func testUnsolicitedClipboardChangesDoNotProduceHints() {
        var correlator = ClipboardEventCorrelator(initialChangeCount: 1)
        XCTAssertEqual(correlator.clipboardChanged(to: 2, at: 2), [])
        correlator.record(.copy, changeCount: 2, at: 3)
        XCTAssertEqual(correlator.clipboardChanged(to: 3, at: 4.3), [])
    }

    func testUnsolicitedCopiesAndManagerRewrites() {
        var correlator = ClipboardEventCorrelator(initialChangeCount: 1)
        XCTAssertEqual(correlator.clipboardChanged(to: 2, at: 1, allowUnsolicited: true), [.confirmed(.copy)])
        XCTAssertEqual(correlator.clipboardChanged(to: 3, at: 1.1, allowUnsolicited: true), [])
        XCTAssertEqual(correlator.clipboardChanged(to: 4, at: 1.4, allowUnsolicited: true, hasContent: false), [])
        correlator.record(.cut, changeCount: 4, at: 1.5)
        XCTAssertEqual(correlator.clipboardChanged(to: 5, at: 1.6, allowUnsolicited: true), [.confirmed(.cut)])
        correlator.record(.copy, changeCount: 5, at: 1.7)
        XCTAssertEqual(correlator.clipboardChanged(to: 6, at: 1.8, allowUnsolicited: true), [.confirmed(.copy)])
        correlator.supersedeWithPaste(at: 2)
        XCTAssertEqual(correlator.clipboardChanged(to: 7, at: 2.1, allowUnsolicited: true), [])
        XCTAssertEqual(correlator.clipboardChanged(to: 8, at: 2.4, allowUnsolicited: true), [.confirmed(.copy)])
    }

    func testRepeatedSameOperationCountsAndHideResets() {
        var counter = TipSequenceCounter()
        XCTAssertEqual(counter.show(.copy), 1)
        XCTAssertEqual(counter.show(.copy), 2)
        XCTAssertEqual(counter.show(.paste), 1)
        XCTAssertEqual(counter.show(.paste), 2)
        counter.hide()
        XCTAssertEqual(counter.show(.paste), 1)
    }

    func testSixPresetPositionsUseVisibleFrameCoordinates() {
        let screen = CGRect(x: -1600, y: -200, width: 1500, height: 900)
        let size = CGSize(width: 200, height: 54)
        XCTAssertEqual(PlacementEngine.origin(visibleFrame: screen, windowSize: size, horizontal: "left", vertical: "top"), CGPoint(x: -1576, y: 622))
        XCTAssertEqual(PlacementEngine.origin(visibleFrame: screen, windowSize: size, horizontal: "center", vertical: "top"), CGPoint(x: -950, y: 622))
        XCTAssertEqual(PlacementEngine.origin(visibleFrame: screen, windowSize: size, horizontal: "right", vertical: "top"), CGPoint(x: -324, y: 622))
        XCTAssertEqual(PlacementEngine.origin(visibleFrame: screen, windowSize: size, horizontal: "left", vertical: "bottom"), CGPoint(x: -1576, y: -176))
        XCTAssertEqual(PlacementEngine.origin(visibleFrame: screen, windowSize: size, horizontal: "center", vertical: "bottom"), CGPoint(x: -950, y: -176))
        XCTAssertEqual(PlacementEngine.origin(visibleFrame: screen, windowSize: size, horizontal: "right", vertical: "bottom"), CGPoint(x: -324, y: -176))
    }

    func testCustomPlacementClampsAndCornerSlidePrefersHorizontal() {
        let screen = CGRect(x: -100, y: 50, width: 1000, height: 700)
        let size = CGSize(width: 200, height: 54)
        let origin = PlacementEngine.origin(visibleFrame: screen, windowSize: size, horizontal: "center", vertical: "bottom",
                                           customPosition: CGPoint(x: -4, y: 4))
        XCTAssertEqual(origin, CGPoint(x: screen.minX, y: screen.maxY - size.height))
        XCTAssertEqual(PlacementEngine.slideDirection(origin: origin, visibleFrame: screen, windowSize: size), .left)
        XCTAssertEqual(PlacementEngine.slideDirection(origin: CGPoint(x: 350, y: 350), visibleFrame: screen, windowSize: size), .down)
    }
}
