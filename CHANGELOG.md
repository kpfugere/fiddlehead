# Changelog

All notable changes to Fiddlehead will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]
### Added
- Daily document architecture: all meetings for a day are consolidated into a single `YYYY-MM-DD.md` file instead of separate files per recording, optimizing for AI-powered search
- Running index (`index.md`): master table of contents with every meeting's title, time, duration, and one-line summary for fast cross-day scanning
- CLAUDE.md skill file auto-placed in notes folder so Claude Code and Cowork can search and understand your notes
- Automatic multi-meeting splitting: when a recording spans multiple calendar events, each meeting gets its own note with correct metadata
- Works in both manual recording and auto mode pipelines

### Changed
- Simplified to AssemblyAI-only transcription — removed dual-provider system and OpenAI transcription option, reducing complexity and eliminating provider-related bugs
- AssemblyAI defaults to `universal-2` model (was `universal-3-pro`) to reduce transcription costs, with option to switch back to `universal-3-pro` for higher accuracy in supported languages (en, es, pt, fr, de, it) — falls back to `universal-2` automatically for other languages

### Fixed
- Auto mode recordings now correctly use stereo interleaved audio with AssemblyAI, enabling channel-based speaker identification (mic = "Me", system audio = "Them") instead of fallback utterance diarization which frequently misattributed speakers
- Auto mode recordings now reliably auto-stop on silence — previously the stereo/mono decision depended on which transcription provider was selected, causing mono audio that broke silence detection

## [0.1.0] - 2026-03-09
### Added
- Initial release
- Menu bar recording app with mic and system audio capture
- OpenAI gpt-4o-transcribe-diarize transcription
- AssemblyAI transcription (selectable in Settings)
- AI-powered note structuring via gpt-4o-mini
- Markdown output with YAML frontmatter
