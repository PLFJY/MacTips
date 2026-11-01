import Foundation

/// Pure event correlation logic. Times are monotonic seconds supplied by the caller.
struct ClipboardEventCorrelator {
    enum Intent: Equatable { case copy, cut }
    enum Output: Equatable { case confirmed(TipKind) }
    struct Pending { var intent: Intent; var time: TimeInterval; var baseline: Int }

    static let confirmationWindow: TimeInterval = 1.2
    private(set) var pending: [Pending] = []
    static let mergeWindow: TimeInterval = 0.25
    private var lastHintTime: TimeInterval?
    private(set) var lastChangeCount: Int

    init(initialChangeCount: Int) { lastChangeCount = initialChangeCount }

    mutating func record(_ intent: Intent, changeCount: Int, at time: TimeInterval) {
        // A newer shortcut supersedes an unconfirmed older one.
        pending = [Pending(intent: intent, time: time, baseline: changeCount)]
        lastChangeCount = changeCount
    }

    mutating func supersedeWithPaste(at time: TimeInterval? = nil) {
        pending.removeAll()
        if let time { lastHintTime = time }
    }

    mutating func synchronize(changeCount: Int) { lastChangeCount = changeCount }

    mutating func clipboardChanged(to count: Int, at time: TimeInterval, allowUnsolicited: Bool = false, hasContent: Bool = true) -> [Output] {
        guard count != lastChangeCount else { return [] }
        lastChangeCount = count
        pending.removeAll { time - $0.time > Self.confirmationWindow }
        if let index = pending.firstIndex(where: { count != $0.baseline }) {
            let operation = pending.remove(at: index)
            lastHintTime = time
            return [.confirmed(operation.intent == .copy ? .copy : .cut)]
        }
        guard allowUnsolicited, hasContent,
              lastHintTime.map({ time - $0 >= Self.mergeWindow }) ?? true else { return [] }
        lastHintTime = time
        return [.confirmed(.copy)]
    }

    mutating func expire(at time: TimeInterval) {
        pending.removeAll { time - $0.time >= Self.confirmationWindow }
    }
}
