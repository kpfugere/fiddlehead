# Fiddlehead

A free, open-source macOS menu bar app that automatically records, transcribes, and structures meeting notes using AI. Notes are saved as plain Markdown files you own — designed to be processed further by [Claude Code](https://claude.com/claude-code) skills.

Source: [github.com/kpfugere/Fiddlehead](https://github.com/kpfugere/Fiddlehead) · Website: [fiddleheadai.com](https://fiddleheadai.com)

## How It Works

1. **Record** — Click the menu bar icon or use a global hotkey to capture mic and system audio
2. **Transcribe** — Audio is sent to OpenAI gpt-4o-transcribe or AssemblyAI for speech-to-text with speaker diarization
3. **Structure** — GPT-4o-mini organizes the raw transcript into clean, structured Markdown notes with YAML frontmatter
4. **Save** — Notes are written to a local folder as `.md` files

## Features

- Menu bar app (no dock icon)
- Mic + system audio capture via AVAudioEngine and ScreenCaptureKit
- Choice of transcription provider (OpenAI or AssemblyAI)
- AI-powered note structuring with topic splitting
- Calendar integration for auto-detecting meetings
- Auto-record mode for scheduled meetings
- Global hotkey for quick start/stop
- Markdown output with frontmatter metadata

## Skills

Fiddlehead's notes are plain Markdown — designed to be combined with [Claude Code](https://claude.com/claude-code) skills that turn raw notes into useful artifacts. Eleven ready-to-use skills are published alongside the app:

| Skill | What it does |
|---|---|
| [meeting follow-up drafter](website/public/skills/meeting-follow-up.md) ([web](https://fiddleheadai.com/skills/meeting-follow-up)) | drafts follow-up emails from your action items and key decisions |
| [linear issue creator](website/public/skills/linear-issue-creator.md) ([web](https://fiddleheadai.com/skills/linear-issue-creator)) | turns action items into structured Linear issues with descriptions and acceptance criteria |
| [decision log](website/public/skills/decision-log.md) ([web](https://fiddleheadai.com/skills/decision-log)) | extracts decisions across meetings into a running log with context and date |
| [meeting prep](website/public/skills/meeting-prep.md) ([web](https://fiddleheadai.com/skills/meeting-prep)) | reviews past meetings with a contact to prepare you for the next one |
| [weekly summary](website/public/skills/weekly-summary.md) ([web](https://fiddleheadai.com/skills/weekly-summary)) | aggregates a week of meetings into a single digest with themes and open items |
| [stakeholder update](website/public/skills/stakeholder-update.md) ([web](https://fiddleheadai.com/skills/stakeholder-update)) | generates a polished status update for leadership or investors from recent meetings |
| [accountability tracker](website/public/skills/accountability-tracker.md) ([web](https://fiddleheadai.com/skills/accountability-tracker)) | tracks who committed to what across meetings and flags overdue items |
| [topic tracker](website/public/skills/topic-tracker.md) ([web](https://fiddleheadai.com/skills/topic-tracker)) | traces how a specific topic evolved across meetings over time |
| [meeting debrief](website/public/skills/meeting-debrief.md) ([web](https://fiddleheadai.com/skills/meeting-debrief)) | structured post-mortem with conversation dynamics, signals, and suggested follow-ups |
| [meeting roi analyzer](website/public/skills/meeting-roi.md) ([web](https://fiddleheadai.com/skills/meeting-roi)) | scores your meetings by outcomes produced and identifies time sinks |
| [personal 360](website/public/skills/personal-360.md) ([web](https://fiddleheadai.com/skills/personal-360)) | analyzes your communication patterns across meetings to surface strengths, blind spots, and growth areas |

To use a skill: drop the `.md` file into your Claude Code skills directory, then point Claude at your Fiddlehead notes folder.

## Requirements

- macOS 14.0+
- Your own API keys for OpenAI and/or AssemblyAI (entered in Settings)
- Microphone and screen recording permissions

## Building

Fiddlehead uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`.

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Open and build
open Fiddlehead.xcodeproj
```

## Tech Stack

- **UI**: SwiftUI, macOS menu bar (LSUIElement)
- **Audio**: AVAudioEngine (mic) + ScreenCaptureKit (system) → 16kHz Int16 PCM
- **Transcription**: OpenAI gpt-4o-transcribe-diarize or AssemblyAI
- **Structuring**: OpenAI gpt-4o-mini via Chat Completions API
- **Updates**: Sparkle 2
- **Build**: XcodeGen from `project.yml`

## Contributing

PRs welcome. See [CHANGELOG.md](CHANGELOG.md) for release history and [CLAUDE.md](CLAUDE.md) for the project's versioning + release conventions.

## License

[MIT](LICENSE) — © 2026 Kyle Fugere
