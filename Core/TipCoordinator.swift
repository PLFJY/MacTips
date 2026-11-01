import AppKit

@MainActor
final class TipCoordinator {
    private let settings: SettingsStore
    private let panel = GlassOSDPanel()
    private var counter = TipSequenceCounter()
    private var hideTask: Task<Void, Never>?
    private var generation = 0

    init(settings: SettingsStore) { self.settings = settings }

    func show(_ kind: TipKind, state: Bool? = nil, force: Bool = false) {
        guard force || settings.enabled(kind) else { return }
        let count = counter.show(kind)
        let next = TipPresentation(kind: kind, count: count, state: state)
        generation += 1
        let token = generation
        panel.present(next, settings: settings)
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.settings.displaySeconds ?? 2))
            guard !Task.isCancelled, let self, self.generation == token else { return }
            self.panel.dismiss(settings: self.settings)
            self.counter.hide()
        }
    }
}
