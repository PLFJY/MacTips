import XCTest
@testable import MacTips
import ApplicationServices

final class CoreLogicTests: XCTestCase {
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
        XCTAssertEqual(correlator.clipboardChanged(to: 5, hasTypes: true, at: 10.1, showAnyCopy: true), [.confirmed(.copy)])
        correlator.record(.copy, changeCount: 5, at: 20)
        XCTAssertEqual(correlator.clipboardChanged(to: 5, hasTypes: true, at: 20.8, showAnyCopy: true), [])
    }

    func testCutConfirmationAndPasteClassifier() {
        var correlator = ClipboardEventCorrelator(initialChangeCount: 0)
        correlator.record(.cut, changeCount: 0, at: 1)
        XCTAssertEqual(correlator.clipboardChanged(to: 1, hasTypes: true, at: 1.1, showAnyCopy: true), [.confirmed(.cut)])
        XCTAssertEqual(KeyboardShortcutClassifier.classify(keyCode: 9, flags: .maskCommand, isRepeat: false), .paste)
    }

    func testInferredCopiesRespectSettingsAndMergeClipboardRewrites() {
        var correlator = ClipboardEventCorrelator(initialChangeCount: 1)
        XCTAssertEqual(correlator.clipboardChanged(to: 2, hasTypes: true, at: 2, showAnyCopy: false), [])
        XCTAssertEqual(correlator.clipboardChanged(to: 3, hasTypes: true, at: 3, showAnyCopy: true), [.inferredCopy])
        XCTAssertEqual(correlator.clipboardChanged(to: 4, hasTypes: true, at: 3.1, showAnyCopy: true), [])
        XCTAssertEqual(correlator.clipboardChanged(to: 5, hasTypes: false, at: 4, showAnyCopy: true), [])
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
