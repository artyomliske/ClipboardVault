import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem]
    @Published var isMonitoringEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMonitoringEnabled, forKey: Keys.isMonitoringEnabled)
            isMonitoringEnabled ? monitor.start() : monitor.stop()
        }
    }
    @Published var historyLimit: Int {
        didSet {
            historyLimit = min(max(historyLimit, 25), 1_000)
            UserDefaults.standard.set(historyLimit, forKey: Keys.historyLimit)
            trimHistoryIfNeeded()
            persist()
        }
    }

    private let persistence: HistoryPersistence
    private lazy var monitor = PasteboardMonitor { [weak self] capture in
        self?.record(capture)
    }

    private enum Keys {
        static let isMonitoringEnabled = "isMonitoringEnabled"
        static let historyLimit = "historyLimit"
    }

    init(persistence: HistoryPersistence = HistoryPersistence()) {
        self.persistence = persistence
        self.items = persistence.load()

        if UserDefaults.standard.object(forKey: Keys.isMonitoringEnabled) == nil {
            self.isMonitoringEnabled = true
        } else {
            self.isMonitoringEnabled = UserDefaults.standard.bool(forKey: Keys.isMonitoringEnabled)
        }

        let savedLimit = UserDefaults.standard.integer(forKey: Keys.historyLimit)
        self.historyLimit = savedLimit == 0 ? 200 : min(max(savedLimit, 25), 1_000)
        trimHistoryIfNeeded()
    }

    func startMonitoringIfNeeded() {
        guard isMonitoringEnabled else { return }
        monitor.start()
    }

    func stopMonitoring() {
        monitor.stop()
    }

    func displayedItems(matching query: String, caseSensitive: Bool) -> [ClipboardItem] {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = items.filter { item in
            guard !cleanedQuery.isEmpty else { return true }
            if caseSensitive {
                return item.preview.contains(cleanedQuery)
            }
            return item.preview.localizedCaseInsensitiveContains(cleanedQuery)
        }

        return result.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.createdAt > rhs.createdAt
        }
    }

    func imageData(for item: ClipboardItem) -> Data? {
        guard item.isImage, let fileName = item.imageFileName else { return nil }
        return persistence.imageData(for: fileName)
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        if item.isImage, let data = imageData(for: item) {
            NSPasteboard.general.setData(data, forType: .png)
        } else if let text = item.text {
            NSPasteboard.general.setString(text, forType: .string)
        }
        moveToTop(item.id)
    }

    func togglePinned(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        persist()
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        persist()
    }

    func clearAll() {
        items.removeAll()
        persist()
    }

    private func record(_ capture: ClipboardCapture) {
        guard isMonitoringEnabled else { return }

        switch capture {
        case .text(let text):
            if let existingIndex = items.firstIndex(where: { $0.kind == .text && $0.text == text }) {
                var existingItem = items.remove(at: existingIndex)
                existingItem.createdAt = .now
                items.insert(existingItem, at: 0)
            } else {
                items.insert(ClipboardItem(text: text), at: 0)
            }

        case .image(let data, let width, let height, let digest):
            if let existingIndex = items.firstIndex(where: {
                $0.kind == .image && $0.contentDigest == digest
            }) {
                var existingItem = items.remove(at: existingIndex)
                existingItem.createdAt = .now
                items.insert(existingItem, at: 0)
            } else {
                let fileName = "\(UUID().uuidString).png"
                persistence.saveImage(data, fileName: fileName)
                items.insert(
                    ClipboardItem(
                        imageFileName: fileName,
                        pixelWidth: width,
                        pixelHeight: height,
                        contentDigest: digest
                    ),
                    at: 0
                )
            }
        }

        trimHistoryIfNeeded()
        persist()
    }

    private func moveToTop(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.createdAt = .now
        items.insert(item, at: 0)
        persist()
    }

    private func trimHistoryIfNeeded() {
        while items.count > historyLimit,
              let oldestUnpinnedIndex = items.indices
                .filter({ !items[$0].isPinned })
                .min(by: { items[$0].createdAt < items[$1].createdAt }) {
            items.remove(at: oldestUnpinnedIndex)
        }
    }

    private func persist() {
        persistence.save(items)
    }
}
