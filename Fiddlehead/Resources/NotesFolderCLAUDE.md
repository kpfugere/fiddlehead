# Meeting Notes — Fiddlehead

This folder contains meeting notes and transcripts captured by Fiddlehead, a macOS meeting recorder. Use these instructions to effectively search, analyze, and reference these notes.

## Architecture

Notes are organized as **daily documents** — one Markdown file per day, with all meetings for that day appended as `##`-level sections. A running **index** (`index.md`) provides a lightweight table of contents across all days.

### Files

- `YYYY-MM-DD.md` — Daily document (e.g., `2026-03-11.md`). Contains all meetings/recordings for that day.
- `index.md` — Master table of contents. Each day has a `## YYYY-MM-DD` heading with bullet-point summaries of every meeting.
- `CLAUDE.md` — This file. Instructions for AI tools.

## Daily Document Format

Each daily document has a YAML frontmatter header and a date title, followed by one `##` section per meeting:

```markdown
---
date: 2026-03-11
---

# Tuesday, March 11, 2026

## Product Squad Standup
*10:00 AM · 15m 32s · 3 speakers · attendees: a@co.com, b@co.com · tags: product, roadmap*

### Summary
One-paragraph overview of the meeting.

### Action Items
- [ ] Task description (@assignee)

### Key Points
- Important details as bullet points

### Transcript
**Kyle:** Verbatim speech...

## Engineering Sync
*2:00 PM · 22m 10s · 2 speakers · tags: engineering, sprint*

### Summary
...
```

### Metadata Line

Each `##` section has an italic metadata line immediately below the heading:

`*10:00 AM · 15m 32s · 3 speakers · attendees: a@co.com, b@co.com · tags: strategy, hiring*`

Possible fields (separated by ` · `):
- **Time**: When the recording started (e.g., `10:00 AM`)
- **Duration**: Recording length (e.g., `15m 32s`)
- **Speakers**: Number detected (e.g., `3 speakers`)
- **Attendees**: Calendar attendees (e.g., `attendees: a@co.com, b@co.com`)
- **Tags**: Topics extracted (e.g., `tags: product, roadmap`)
- **Status**: `partial` if structuring was truncated, `unstructured` if no structuring
- **Source**: `auto` if captured in auto-mode

### Multi-Topic Sessions (Auto Mode)

Auto-mode recordings that cover multiple topics appear as a single `##` section with `###`-level sub-topics:

```markdown
## Morning Working Session
*9:00 AM · 45m 12s · 1 speaker · tags: planning, code-review · auto*

### Session Summary
Overview of the entire session.

### Topic: Budget Planning
Summary and action items for this topic.

### Topic: Code Review
Summary and action items for this topic.

### Full Transcript
**Kyle:** Verbatim speech...
```

### Unstructured Fallbacks

When structuring fails, the section contains a note and raw transcript:

```markdown
## Recording — 3:00 PM
*3:00 PM · 8m 15s · 2 speakers · unstructured*

> Note: This transcript could not be structured automatically.

### Transcript
**Speaker 1:** Verbatim speech...
```

## Index Format

`index.md` is a running table of contents with newest dates first:

```markdown
# Meeting Notes Index

## 2026-03-11
- **Product Squad Standup** (10:00 AM, 15m) — Discussed Q2 roadmap priorities.
- **Engineering Sync** (2:00 PM, 22m) — Sprint review and blockers.

## 2026-03-10
- **Leadership Meeting** (9:00 AM, 45m) — Budget approval for new hires.
```

## How to Search These Notes

### Quick overview
Read `index.md` first — it has every meeting title, time, duration, and one-line summary. This is the fastest way to find what you're looking for.

### By date
- Open the daily document directly: `2026-03-11.md`
- Use `Glob` with date patterns: `2026-03-*.md` for all of March

### By topic or keyword
Use `Grep` to search note content:
- Tags: `tags:.*keyword` (in metadata lines)
- Meeting names: `## Meeting Name` (section headings)
- Attendees: `attendees:.*email@`
- Action items: `- \[ \]` (open) or `- \[x\]` (completed)
- Speaker dialogue: `**Name:**` (in transcripts)

### By content
Full-text `Grep` across all `.md` files works well since everything is plain text.

## Tips

- **Start with the index**: `index.md` gives you a bird's-eye view. Find the meeting, then jump to the daily doc for full details.
- **Action item tracking**: Search for `- [ ]` across all daily docs to find outstanding tasks.
- **Meeting continuity**: Search across multiple daily docs to build a timeline of how a topic evolved over days/weeks.
- **People context**: `attendees:` in metadata and `**Name:**` in transcripts help trace who said what.
- **One file per day**: All of a day's meetings are in one file, making it easy to see the full context of a busy day.
