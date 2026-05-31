import SwiftUI

/// A saved bookmark.
struct Bookmark: Identifiable, Codable {
    var id = UUID()
    var url: String
    var title: String
    var createdAt: Date
}

/// Persistent bookmarks, stored as JSON in Application Support. Newest first.
final class BookmarkStore: ObservableObject {
    static let shared = BookmarkStore()

    @Published private(set) var bookmarks: [Bookmark] = []

    private let fileURL: URL
    private var saveScheduled = false

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("MoriBrowser", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("bookmarks.json")
        load()
    }

    func isBookmarked(_ url: String) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    /// Add or remove the page from bookmarks. Returns the new bookmarked state.
    @discardableResult
    func toggle(url: String, title: String) -> Bool {
        guard !url.isEmpty, url != "about:blank" else { return false }
        if let idx = bookmarks.firstIndex(where: { $0.url == url }) {
            bookmarks.remove(at: idx)
            scheduleSave()
            return false
        }
        bookmarks.insert(Bookmark(url: url, title: title.isEmpty ? url : title,
                                  createdAt: Date()), at: 0)
        scheduleSave()
        return true
    }

    func remove(_ bookmark: Bookmark) {
        remove(id: bookmark.id.uuidString)
    }

    func handleExtensionBookmarks(method: String, args: NSDictionary) -> NSDictionary {
        switch method {
        case "bookmarks.getTree":
            return ["result": [rootNode()]]

        case "bookmarks.getChildren":
            let id = args["id"] as? String ?? ""
            guard id == "0" || id == "1" else { return ["result": []] }
            return ["result": id == "0" ? [bookmarksBarNode()] : bookmarkNodes()]

        case "bookmarks.get":
            let ids = bookmarkIDs(from: args["id"])
            let nodes = ids.compactMap(bookmarkNode(for:))
            return ["result": nodes]

        case "bookmarks.search":
            let results = searchBookmarks(query: args["query"]).map { bookmarkNode($0) }
            return ["result": results]

        case "bookmarks.create":
            let props = args["bookmark"] as? NSDictionary ?? [:]
            guard let url = props["url"] as? String, !url.isEmpty else {
                return ["error": "Mori currently supports bookmark URL nodes only."]
            }
            let title = (props["title"] as? String) ?? url
            let index = (props["index"] as? NSNumber)?.intValue
            let bookmark = Bookmark(url: url, title: title, createdAt: Date())
            let insertIndex = max(0, min(index ?? 0, bookmarks.count))
            bookmarks.insert(bookmark, at: insertIndex)
            scheduleSave()
            let node = bookmarkNode(bookmark, index: insertIndex)
            MoriBrowserView.dispatchExtensionEvent("bookmarks.onCreated",
                                                     args: [bookmark.id.uuidString, node],
                                                     forExtensionID: nil)
            return ["result": node]

        case "bookmarks.update":
            let id = args["id"] as? String ?? ""
            let changes = args["changes"] as? NSDictionary ?? [:]
            guard let idx = bookmarks.firstIndex(where: { $0.id.uuidString == id }) else {
                return ["error": "No bookmark with that id."]
            }
            if let title = changes["title"] as? String { bookmarks[idx].title = title }
            if let url = changes["url"] as? String { bookmarks[idx].url = url }
            scheduleSave()
            let node = bookmarkNode(bookmarks[idx], index: idx)
            var changeInfo: [String: Any] = ["title": bookmarks[idx].title]
            changeInfo["url"] = bookmarks[idx].url
            MoriBrowserView.dispatchExtensionEvent("bookmarks.onChanged",
                                                     args: [id, changeInfo],
                                                     forExtensionID: nil)
            return ["result": node]

        case "bookmarks.move":
            let id = args["id"] as? String ?? ""
            let destination = args["destination"] as? NSDictionary ?? [:]
            if id == "0" || id == "1" {
                return ["error": "Mori cannot move bookmark root nodes."]
            }
            if let parentId = destination["parentId"] as? String, parentId != "1" {
                return ["error": "Mori currently supports moving bookmarks within the bookmarks bar only."]
            }
            guard let oldIndex = bookmarks.firstIndex(where: { $0.id.uuidString == id }) else {
                return ["error": "No bookmark with that id."]
            }
            let bookmark = bookmarks.remove(at: oldIndex)
            let rawIndex = (destination["index"] as? NSNumber)?.intValue ?? oldIndex
            let newIndex = max(0, min(rawIndex, bookmarks.count))
            bookmarks.insert(bookmark, at: newIndex)
            scheduleSave()
            let node = bookmarkNode(bookmark, index: newIndex)
            MoriBrowserView.dispatchExtensionEvent("bookmarks.onMoved",
                                                     args: [id, [
                                                        "parentId": "1",
                                                        "index": newIndex,
                                                        "oldParentId": "1",
                                                        "oldIndex": oldIndex
                                                     ]],
                                                     forExtensionID: nil)
            return ["result": node]

        case "bookmarks.remove", "bookmarks.removeTree":
            let id = args["id"] as? String ?? ""
            guard remove(id: id) else { return ["error": "No bookmark with that id."] }
            return ["result": NSNull()]

        default:
            return ["error": "Unsupported bookmarks method: \(method)"]
        }
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
        else { return }
        bookmarks = decoded
    }

    private func scheduleSave() {
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.saveScheduled = false
            self?.save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    @discardableResult
    private func remove(id: String) -> Bool {
        guard let idx = bookmarks.firstIndex(where: { $0.id.uuidString == id }) else {
            return false
        }
        let node = bookmarkNode(bookmarks[idx], index: idx)
        bookmarks.remove(at: idx)
        scheduleSave()
        MoriBrowserView.dispatchExtensionEvent("bookmarks.onRemoved",
                                                 args: [id, [
                                                    "parentId": "1",
                                                    "index": idx,
                                                    "node": node
                                                 ]],
                                                 forExtensionID: nil)
        return true
    }

    private func bookmarkIDs(from raw: Any?) -> [String] {
        if let id = raw as? String { return [id] }
        if let ids = raw as? [String] { return ids }
        if let ids = raw as? NSArray { return ids.compactMap { $0 as? String } }
        return []
    }

    private func rootNode() -> NSDictionary {
        [
            "id": "0",
            "title": "",
            "children": [bookmarksBarNode()]
        ]
    }

    private func bookmarksBarNode() -> NSDictionary {
        [
            "id": "1",
            "parentId": "0",
            "title": "Bookmarks",
            "children": bookmarkNodes()
        ]
    }

    private func bookmarkNodes() -> [NSDictionary] {
        bookmarks.enumerated().map { bookmarkNode($0.element, index: $0.offset) }
    }

    private func bookmarkNode(for id: String) -> NSDictionary? {
        if id == "0" { return rootNode() }
        if id == "1" { return bookmarksBarNode() }
        guard let idx = bookmarks.firstIndex(where: { $0.id.uuidString == id }) else {
            return nil
        }
        return bookmarkNode(bookmarks[idx], index: idx)
    }

    private func bookmarkNode(_ bookmark: Bookmark, index: Int? = nil) -> NSDictionary {
        var node: [String: Any] = [
            "id": bookmark.id.uuidString,
            "parentId": "1",
            "title": bookmark.title,
            "url": bookmark.url,
            "dateAdded": bookmark.createdAt.timeIntervalSince1970 * 1000
        ]
        if let index { node["index"] = index }
        return node as NSDictionary
    }

    private func searchBookmarks(query raw: Any?) -> [Bookmark] {
        if raw == nil || raw is NSNull { return bookmarks }
        if let text = raw as? String {
            return bookmarks.filter { matches($0, text: text) }
        }
        guard let query = raw as? NSDictionary else { return [] }
        return bookmarks.filter { bookmark in
            if let url = query["url"] as? String, bookmark.url != url { return false }
            if let title = query["title"] as? String, bookmark.title != title { return false }
            if let text = query["query"] as? String, !matches(bookmark, text: text) { return false }
            return true
        }
    }

    private func matches(_ bookmark: Bookmark, text: String) -> Bool {
        guard !text.isEmpty else { return true }
        return bookmark.title.localizedCaseInsensitiveContains(text) ||
               bookmark.url.localizedCaseInsensitiveContains(text)
    }
}
