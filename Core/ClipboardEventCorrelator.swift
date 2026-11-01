import Foundation

/// Pure event correlation logic. Times are monotonic seconds supplied by the caller.
struct ClipboardEventCorrelator {
    enum Intent: Equatable { case copy, cut }
    enum Output: Equatable { case confirmed(TipKind) }
    struct Pending { var intent: Intent; var time: TimeInterval; var baseline: Int }

    static let confirmationWindow: TimeInterval = 1.2
    private(set) var pending: [Pending] = []
    private(set) var lastChangeCount: Int

    init(initialChangeCount: Int) { lastChangeCount = initialChangeCount }

    mutating func record(_ intent: Intent, changeCount: Int, at time: TimeInterval) {
        // A newer shortcut supersedes an unconfirmed older one.
        pending = [Pending(intent: intent, time: time, baseline: changeCount)]
        lastChangeCount = changeCount
    }

    mutating func supersedeWithPaste() {
        pending.removeAll()
    }

    mutating func clipboardChanged(to count: Int, at time: TimeInterval) -> [Output] {
        guard count != lastChangeCount else { return [] }
        lastChangeCount = count
        pending.removeAll { time - $0.time > Self.confirmationWindow }
        if let index = pending.firstIndex(where: { count != $0.baseline }) {
            let operation = pending.remove(at: index)
            return [.confirmed(operation.intent == .copy ? .copy : .cut)]
        }
        return []
    }

    mutating func expire(at time: TimeInterval) {
        pending.removeAll { time - $0.time >= Self.confirmationWindow }
    }
}
