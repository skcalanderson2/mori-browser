import SwiftUI

/// One visited page.
struct HistoryEntry: Identifiable, Codable {
    var id = UUID()
    var url: String
    var title: String
    var lastVisited: Date
    var visitCount: Int
}

/// Persistent browsing history. Records main-frame navigations, collapses
/// repeat visits to the same URL, and is capped to a sane size. Stored as JSON
/// in Application Support so it survives relaunch (like the cookie jar).
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [HistoryEntry] = []

    private let maxEntries = 2000
    private let fileURL: URL
    private var saveScheduled = false

    init() {
        fileURL = HistoryStore.supportDirectory()
            .appendingPathComponent("history.json")
        load()
    }

    /// Record a visit. Ignores blanks and internal pages so the list stays
    /// meaningful. Same-URL revisits bump the count and move to the top.
    func record(url: String, title: String) {
        guard isRecordable(url) else { return }

        let entry: HistoryEntry
        if let idx = entries.firstIndex(where: { $0.url == url }) {
            var updated = entries.remove(at: idx)
            updated.lastVisited = Date()
            updated.visitCount += 1
            if !title.isEmpty { updated.title = title }
            entries.insert(updated, at: 0)
            entry = updated
        } else {
            let created = HistoryEntry(url: url, title: title,
                                       lastVisited: Date(), visitCount: 1)
            entries.insert(created, at: 0)
            if entries.count > maxEntries {
                entries.removeLast(entries.count - maxEntries)
            }
            entry = created
        }
        scheduleSave()
        MoriBrowserView.dispatchExtensionEvent("history.onVisited",
                                                 args: [extensionHistoryItem(entry)],
                                                 forExtensionID: nil)
    }

    /// Update the title for the most recent entry of a URL (titles arrive after
    /// the navigation commits).
    func updateTitle(_ title: String, for url: String) {
        guard !title.isEmpty, let idx = entries.firstIndex(where: { $0.url == url })
        else { return }
        entries[idx].title = title
        scheduleSave()
    }

    /// Best prefix/substring matches for omnibox autocomplete, most-visited and
    /// most-recent first.
    func suggestions(for query: String, limit: Int = 6) -> [HistoryEntry] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }
        return entries
            .filter { $0.url.lowercased().contains(q) || $0.title.lowercased().contains(q) }
            .sorted { ($0.visitCount, $0.lastVisited) > ($1.visitCount, $1.lastVisited) }
            .prefix(limit)
            .map { $0 }
    }

    func clear() {
        let urls = entries.map(\.url)
        entries = []
        scheduleSave()
        dispatchHistoryRemoved(allHistory: true, urls: urls)
    }

    func remove(_ entry: HistoryEntry) {
        let removed = entries.filter { $0.id == entry.id }.map(\.url)
        entries.removeAll { $0.id == entry.id }
        scheduleSave()
        dispatchHistoryRemoved(allHistory: false, urls: removed)
    }

    func handleExtensionHistory(method: String, args: NSDictionary) -> NSDictionary {
        switch method {
        case "history.search":
            let query = args["query"] as? NSDictionary ?? [:]
            let result = searchHistory(query: query).map(extensionHistoryItem)
            return ["result": result]

        case "history.getVisits":
            let details = args["details"] as? NSDictionary ?? [:]
            guard let url = details["url"] as? String, !url.isEmpty else {
                return ["error": "history.getVisits requires a url."]
            }
            let visits = entries
                .filter { $0.url == url }
                .map(extensionVisitItem)
            return ["result": visits]

        case "history.addUrl":
            let details = args["details"] as? NSDictionary ?? [:]
            guard let url = details["url"] as? String, !url.isEmpty else {
                return ["error": "history.addUrl requires a url."]
            }
            record(url: url, title: details["title"] as? String ?? url)
            return ["result": NSNull()]

        case "history.deleteUrl":
            let details = args["details"] as? NSDictionary ?? [:]
            guard let url = details["url"] as? String, !url.isEmpty else {
                return ["error": "history.deleteUrl requires a url."]
            }
            let removed = entries.filter { $0.url == url }.map(\.url)
            entries.removeAll { $0.url == url }
            scheduleSave()
            dispatchHistoryRemoved(allHistory: false, urls: removed)
            return ["result": NSNull()]

        case "history.deleteRange":
            let range = args["range"] as? NSDictionary ?? [:]
            let startTime = (range["startTime"] as? NSNumber)?.doubleValue ?? 0
            let endTime = (range["endTime"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970 * 1000
            let removed = entries
                .filter { item in
                    let timestamp = item.lastVisited.timeIntervalSince1970 * 1000
                    return timestamp >= startTime && timestamp <= endTime
                }
                .map(\.url)
            entries.removeAll { item in
                let timestamp = item.lastVisited.timeIntervalSince1970 * 1000
                return timestamp >= startTime && timestamp <= endTime
            }
            scheduleSave()
            dispatchHistoryRemoved(allHistory: false, urls: removed)
            return ["result": NSNull()]

        case "history.deleteAll":
            clear()
            return ["result": NSNull()]

        case "topSites.get":
            let result = entries
                .sorted { lhs, rhs in
                    if lhs.visitCount == rhs.visitCount {
                        return lhs.lastVisited > rhs.lastVisited
                    }
                    return lhs.visitCount > rhs.visitCount
                }
                .prefix(25)
                .map { ["url": $0.url, "title": $0.title] as NSDictionary }
            return ["result": Array(result)]

        default:
            return ["error": "Unsupported history method: \(method)"]
        }
    }

    // MARK: Recordability

    private func isRecordable(_ url: String) -> Bool {
        guard !url.isEmpty, url != "about:blank" else { return false }
        let lower = url.lowercased()
        return !lower.hasPrefix("about:") && !lower.hasPrefix("chrome:")
            && !lower.hasPrefix("devtools:") && !lower.hasPrefix("data:")
    }

    // MARK: Persistence

    private static func supportDirectory() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("MoriBrowser", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    /// Coalesce rapid navigations into a single write on the next runloop tick.
    private func scheduleSave() {
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.saveScheduled = false
            self?.save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func searchHistory(query: NSDictionary) -> [HistoryEntry] {
        let text = (query["text"] as? String ?? "").lowercased()
        let startTime = (query["startTime"] as? NSNumber)?.doubleValue ?? 0
        let endTime = (query["endTime"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970 * 1000
        let maxResults = max(0, (query["maxResults"] as? NSNumber)?.intValue ?? 100)
        return entries
            .filter { item in
                let timestamp = item.lastVisited.timeIntervalSince1970 * 1000
                guard timestamp >= startTime && timestamp <= endTime else { return false }
                guard !text.isEmpty else { return true }
                return item.url.lowercased().contains(text)
                    || item.title.lowercased().contains(text)
            }
            .prefix(maxResults)
            .map { $0 }
    }

    private func extensionHistoryItem(_ entry: HistoryEntry) -> NSDictionary {
        [
            "id": entry.id.uuidString,
            "url": entry.url,
            "title": entry.title,
            "lastVisitTime": entry.lastVisited.timeIntervalSince1970 * 1000,
            "visitCount": entry.visitCount,
            "typedCount": 0
        ]
    }

    private func extensionVisitItem(_ entry: HistoryEntry) -> NSDictionary {
        [
            "id": entry.id.uuidString,
            "visitId": entry.id.uuidString,
            "visitTime": entry.lastVisited.timeIntervalSince1970 * 1000,
            "referringVisitId": "",
            "transition": "link"
        ]
    }

    private func dispatchHistoryRemoved(allHistory: Bool, urls: [String]) {
        guard allHistory || !urls.isEmpty else { return }
        MoriBrowserView.dispatchExtensionEvent("history.onVisitRemoved",
                                                 args: [[
                                                    "allHistory": allHistory,
                                                    "urls": Array(Set(urls))
                                                 ]],
                                                 forExtensionID: nil)
    }
}
