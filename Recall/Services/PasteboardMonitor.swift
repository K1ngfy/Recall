import AppKit

/// NSPasteboard monitor.
/// - Polls changeCount (the only mechanism macOS exposes)
/// - Debounce: collapse many rapid changes into a single tick
final class PasteboardMonitor {

    private let pasteboard = NSPasteboard.general
    private let interval: TimeInterval
    private let debounce: TimeInterval

    private var lastChangeCount: Int = -1
    private var timer: Timer?
    private var lastEmissionAt: Date = .distantPast

    var onNewItem: ((ClipItemBuilder.Result) -> Void)?

    init(interval: TimeInterval = 0.5, debounce: TimeInterval = 0.15) {
        self.interval = interval
        self.debounce = debounce
    }

    func start() {
        lastChangeCount = pasteboard.changeCount
        schedule()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func tick() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        let now = Date()
        if now.timeIntervalSince(lastEmissionAt) < debounce { return }
        lastEmissionAt = now

        // 6.5 snippet trigger-word detection (isolated on @MainActor)
        let pbString = pasteboard.string(forType: .string)
        if let str = pbString {
            Task { @MainActor in
                if let snippet = SnippetService.matchTrigger(in: str, allItems: SnippetService.allSnippets()) {
                    let trigger = snippet.triggerWord ?? ""
                    AppLog.paste.info("Snippet triggered: \(trigger, privacy: .public)")
                    SnippetService.recordUsage(snippet)
                    // Real auto-expand: delete the trigger word and write
                    // the snippet at the cursor position
                    PasteService.shared.expandSnippet(
                        triggerLength: trigger.count,
                        snippetText: snippet.textContent ?? ""
                    )
                    return  // snippet path does not write to the database
                }
            }
        }

        guard let result = ClipItemBuilder.build(from: pasteboard) else { return }
        onNewItem?(result)
    }
}
