import Foundation

/// Represents a saved note file
struct NoteFile: Identifiable, Comparable {
    let id: URL
    let url: URL
    let title: String
    let date: Date
    let isStructured: Bool

    var filename: String { url.lastPathComponent }

    static func < (lhs: NoteFile, rhs: NoteFile) -> Bool {
        lhs.date > rhs.date // Newest first
    }
}
