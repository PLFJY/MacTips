import ApplicationServices

enum KeyboardShortcutClassifier {
    enum Action: Equatable { case copy, paste, cut }
    static func classify(keyCode: Int64, flags: CGEventFlags, isRepeat: Bool) -> Action? {
        guard !isRepeat, flags.contains(.maskCommand), !flags.contains(.maskShift),
              !flags.contains(.maskAlternate), !flags.contains(.maskControl) else { return nil }
        return switch keyCode {
        case 8: .copy
        case 9: .paste
        case 7: .cut
        default: nil
        }
    }
}
