import Foundation

final class BookmarkManager: Sendable {
    static let shared = BookmarkManager()
    private let bookmarkKey = "saveLocationBookmark"

    private init() {}

    func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        } catch {
            // Non-sandboxed: bookmarks may fail, that's OK — we have the raw path
        }
    }

    func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale {
            // Bookmark is stale — re-save if we can access it
            saveBookmark(for: url)
        }

        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
