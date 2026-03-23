# Changelog

All notable changes to Fiddlehead will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.2.5] - 2026-03-23
### Fixed
- Checkout page opening in LemonSqueezy test mode instead of live mode

## [0.2.4] - 2026-03-20
### Fixed
- Auto mode recordings not counting toward free tier usage — recordings used counter in Settings now updates correctly for auto mode, and the free tier limit is properly enforced

## [0.2.3] - 2026-03-20
### Fixed
- TelemetryDeck analytics not initializing on app launch — moved initialization from menu bar view's onAppear (which only fires when clicking the icon) to app init so it runs immediately at startup

## [0.2.2] - 2026-03-20
### Added
- Anonymous usage analytics via TelemetryDeck — tracks app launches, recording completions, and error rates across macOS versions (no personal data collected)
- CI workflow that builds and tests on both macOS 14 (Sonoma) and macOS 15 (Sequoia) to catch version-specific regressions

## [0.2.1] - 2026-03-17
### Fixed
- App failing to launch on macOS 26 — removed Carbon framework dependency and replaced with modern NSEvent-based global hotkey registration
- Deprecated IOKit symbol (`kIOMasterPortDefault`) replaced with `kIOMainPortDefault`
- Sparkle updater now defers initialization to prevent silent launch crashes

## [0.2.0] - 2026-03-16
### Added
- Auto-update support via Sparkle — the app checks for updates automatically and offers in-app install
- "Check for updates" button in the menu bar footer
- Automated release pipeline: push a version tag and GitHub Actions builds, signs, notarizes, and publishes a DMG to GitHub Releases
- Dynamic version display in Settings (reads from bundle instead of hardcoded)
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
