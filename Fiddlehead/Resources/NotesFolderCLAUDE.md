# Meeting Notes — Fiddlehead

This folder contains meeting notes and transcripts captured by Fiddlehead, a macOS meeting recorder. Use these instructions to effectively search, analyze, and reference these notes.

## File Format

Every note is a Markdown file with YAML frontmatter:

```yaml
---
date: 2026-03-10T16:00:36Z        # ISO 8601 timestamp
duration: 27m 26s                   # Recording length
speakers: 2                         # Number of speakers detected
speaker_names: Jim, Kyle            # Identified speaker names (when available)
tags: [product, strategy, hiring]   # Topics covered
topics: Topic One; Topic Two        # Semicolon-separated topic titles
meeting: Product Squad              # Calendar event name (if matched)
attendees: a@co.com, b@co.com      # Calendar attendees (if matched)
calendar_event_id: ...              # Calendar event reference
source: auto                        # Present when captured in auto-mode
structuring_status: partial         # "complete" or "partial" (if structuring had issues)
---
```

Not all fields are present on every note. Older or fallback notes may only have `date` and `status: unstructured`.

## File Naming

- Structured notes: `YYYY-MM-DD_slugified-title.md` (e.g., `2026-03-10_product-squad.md`)
- Unstructured transcripts: `YYYY-MM-DD_HHmm_transcript.md`
- Audio files (when kept): `YYYY-MM-DD_HHmm_recording.wav`

## Note Structure

Structured notes follow this pattern:

```markdown
# Meeting Title

## Session Summary
One-paragraph overview of the entire recording session.

## Topic: Topic Name
### Summary
Paragraph summary of this topic.

### Action Items
- [ ] Task description (@assignee)

### Key Points
- Bullet points of important details

## Full Transcript
**Speaker Name:** Verbatim speech...
```

Some notes have multiple `## Topic:` sections when the recording covered several subjects.

## How to Search These Notes

### By date
Use `Glob` with date patterns: `2026-03-*` for all March 2026 notes, `2026-03-10*` for a specific day.

### By topic or keyword
Use `Grep` to search note content. Useful patterns:
- Search tags: `tags: \[.*keyword` (in frontmatter)
- Search meeting names: `meeting: Meeting Name`
- Search attendees: `attendees:.*email@`
- Search action items: `- \[ \]` (open) or `- \[x\]` (completed)
- Search by speaker: `speaker_names:.*Name` or `**Name:**` (in transcripts)
- Search topics: `## Topic:.*keyword`

### By content
Full-text search with `Grep` across all `.md` files works well since notes are plain text.

### Combining searches
For complex queries (e.g., "action items from meetings with Jim in March"), use multiple searches:
1. Find files matching the date range
2. Filter to those mentioning the person
3. Extract the relevant sections

## Tips

- **Action item tracking**: Search for `- [ ]` across all notes to find outstanding tasks. Combine with date filters to find recent ones.
- **Meeting continuity**: When a user asks "what did we discuss about X?", search across multiple notes to build a timeline of how a topic evolved.
- **People context**: `speaker_names` in frontmatter and `**Name:**` in transcripts help trace who said what.
- **Auto-mode notes** (`source: auto`) may cover multiple unrelated topics from a continuous recording session — check the `## Topic:` sections individually.
- **Unstructured transcripts** (files ending in `_transcript.md` or with `status: unstructured`) contain raw text without sections — still searchable but less organized.
