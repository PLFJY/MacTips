import Foundation

/// Pure event correlation logic. Times are monotonic seconds supplied by the caller.
struct ClipboardEventCorrelator {
    enum Intent: Equatable { case copy, cut }
    enum Output: Equatable { case confirmed(TipKind), inferredCopy }
    struct Pending { var intent: Intent; var time: TimeInterval; var baseline: Int }

    static let confirmationWindow: TimeInterval = 1.2
    static let rewriteMergeWindow: TimeInterval = 0.75
    private(set) var pending: [Pending] = []
    private(set) var lastChangeCount: Int
    private var lastConfirmedChangeAt: TimeInterval = -.infinity
    private var suppressInferredUntil: TimeInterval = -.infinity

    init(initialChangeCount: Int) { lastChangeCount = initialChangeCount }

    mutating func record(_ intent: Intent, changeCount: Int, at time: TimeInterval) {
        // A newer shortcut supersedes an unconfirmed older one.
        pending = [Pending(intent: intent, time: time, baseline: changeCount)]
        suppressInferredUntil = -.infinity
    }

    mutating func supersedeWithPaste(at time: TimeInterval) {
        let pendingDeadline = pending.map { $0.time + Self.confirmationWindow }.max() ?? -.infinity
        suppressInferredUntil = max(suppressInferredUntil, pendingDeadline,
                                    lastConfirmedChangeAt + Self.confirmationWindow)
        pending.removeAll()
    }

    mutating func clipboardChanged(to count: Int, hasTypes: Bool, at time: TimeInterval,
                                   showAnyCopy: Bool) -> [Output] {
        guard count != lastChangeCount else { return [] }
        lastChangeCount = count
        pending.removeAll { time - $0.time > Self.confirmationWindow }
        if let index = pending.firstIndex(where: { count != $0.baseline }) {
            let operation = pending.remove(at: index)
            lastConfirmedChangeAt = time
            return [.confirmed(operation.intent == .copy ? .copy : .cut)]
        }
        // Clipboard type metadata is only a conservative hint. An empty type list may
        // indicate privacy restrictions, so never claim a copy when content is unknown.
        guard hasTypes, showAnyCopy, time >= suppressInferredUntil,
              time - lastConfirmedChangeAt >= Self.rewriteMergeWindow else { return [] }
        lastConfirmedChangeAt = time
        return [.inferredCopy]
    }

    mutating func expire(at time: TimeInterval) {
        pending.removeAll { time - $0.time >= Self.confirmationWindow }
    }
}
