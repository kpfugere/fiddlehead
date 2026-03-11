# Changelog

All notable changes to Fiddlehead will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]
### Added
- CLAUDE.md skill file auto-placed in notes folder so Claude Code and Cowork can search and understand your notes
- Automatic multi-meeting splitting: when a recording spans multiple calendar events, each meeting gets its own note with correct metadata
- Works in both manual recording and auto mode pipelines

### Fixed
- Auto mode recordings now correctly use stereo interleaved audio with AssemblyAI, enabling channel-based speaker identification (mic = "Me", system audio = "Them") instead of fallback utterance diarization which frequently misattributed speakers

## [0.1.0] - 2026-03-09
### Added
- Initial release
- Menu bar recording app with mic and system audio capture
- OpenAI gpt-4o-transcribe-diarize transcription
- AssemblyAI transcription (selectable in Settings)
- AI-powered note structuring via gpt-4o-mini
- Markdown output with YAML frontmatter
