import SwiftUI

struct NoteRowView: View {
    let note: NoteFile

    var body: some View {
        Button(action: openNote) {
            HStack(spacing: 10) {
                Text(note.isStructured ? "▣" : "▢")
                    .font(FiddleheadTheme.mono(12))
                    .foregroundStyle(note.isStructured ? FiddleheadTheme.saved : FiddleheadTheme.textSecondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title.lowercased())
                        .font(FiddleheadTheme.mono(12, weight: .medium))
                        .foregroundStyle(FiddleheadTheme.textPrimary)
                        .lineLimit(1)

                    Text(formattedDate)
                        .font(FiddleheadTheme.mono(10))
                        .foregroundStyle(FiddleheadTheme.textSecondary)
                }

                Spacer()

                Text("→")
                    .font(FiddleheadTheme.mono(10))
                    .foregroundStyle(FiddleheadTheme.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, FiddleheadTheme.paddingLarge)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: note.date, relativeTo: Date())
    }

    private func openNote() {
        NSWorkspace.shared.open(note.url)
    }
}
