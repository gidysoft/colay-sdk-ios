import Foundation

/// Persistent on-device event queue (one JSON event per line). Called only from the SDK's serial queue.
final class EventQueue {
    private let fileURL: URL
    private let maxSize: Int
    private var items: [[String: Any]] = []

    init(fileURL: URL, maxSize: Int) {
        self.fileURL = fileURL
        self.maxSize = maxSize
        load()
    }

    var count: Int { items.count }

    func add(_ event: [String: Any]) {
        items.append(event)
        if items.count > maxSize { items.removeFirst(items.count - maxSize) } // the oldest are dropped
        save()
    }

    func peek(_ n: Int, maxBytes: Int) -> [[String: Any]] {
        var out: [[String: Any]] = []
        var bytes = 0
        for e in items {
            if out.count >= n { break }
            let len = (try? JSONSerialization.data(withJSONObject: e).count) ?? 0
            if !out.isEmpty && bytes + len > maxBytes { break }
            out.append(e)
            bytes += len
        }
        return out
    }

    func remove(_ sent: [[String: Any]]) {
        guard !sent.isEmpty else { return }
        let ids = Set(sent.compactMap { $0["id"] as? String })
        items.removeAll { ids.contains(($0["id"] as? String) ?? "") }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL), let text = String(data: data, encoding: .utf8) else { return }
        for line in text.split(separator: "\n") where !line.isEmpty {
            if let d = line.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                items.append(obj)
            }
        }
        if items.count > maxSize { items.removeFirst(items.count - maxSize) }
    }

    private func save() {
        var text = ""
        for e in items {
            if let d = try? JSONSerialization.data(withJSONObject: e), let s = String(data: d, encoding: .utf8) {
                text += s + "\n"
            }
        }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: fileURL, options: .atomic)
        } catch {
            // disk error: events stay in memory
        }
    }
}
