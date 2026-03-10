import SwiftUI

struct RecentNotesList: View {
    let notes: [NoteFile]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("recent")
                .font(FiddleheadTheme.mono(11, weight: .medium))
                .foregroundStyle(FiddleheadTheme.textSecondary)
                .padding(.horizontal, FiddleheadTheme.paddingLarge)
                .padding(.top, FiddleheadTheme.paddingMedium)

            if notes.isEmpty {
                Text("no notes yet — hit record to begin.")
                    .font(FiddleheadTheme.mono(11))
                    .foregroundStyle(FiddleheadTheme.textSecondary.opacity(0.7))
                    .padding(.horizontal, FiddleheadTheme.paddingLarge)
                    .padding(.vertical, FiddleheadTheme.paddingSmall)
            } else {
                ForEach(notes) { note in
                    NoteRowView(note: note)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, FiddleheadTheme.paddingSmall)
    }
}
