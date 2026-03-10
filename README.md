# Fiddlehead

macOS menu bar app that automatically records, transcribes, and structures meeting notes using AI.

## How It Works

1. **Record** — Click the menu bar icon or use a global hotkey to capture mic and system audio
2. **Transcribe** — Audio is sent to Deepgram Nova-2 or OpenAI gpt-4o-transcribe for speech-to-text with speaker diarization
3. **Structure** — GPT-4o-mini organizes the raw transcript into clean, structured Markdown notes with YAML frontmatter
4. **Save** — Notes are written to a local folder as `.md` files

## Features

- Menu bar app (no dock icon)
- Mic + system audio capture via AVAudioEngine and ScreenCaptureKit
- Choice of transcription provider (Deepgram or OpenAI)
- AI-powered note structuring with topic splitting
- Calendar integration for auto-detecting meetings
- Auto-record mode for scheduled meetings
- Global hotkey for quick start/stop
- Markdown output with frontmatter metadata

## Requirements

- macOS 14.0+
- API keys for OpenAI and/or Deepgram
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
- **Transcription**: Deepgram Nova-2 (batch) or OpenAI gpt-4o-transcribe-diarize
- **Structuring**: OpenAI gpt-4o-mini via Chat Completions API
- **Build**: XcodeGen from `project.yml`
