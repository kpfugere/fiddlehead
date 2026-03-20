# macOS Version Compatibility Test Checklist

Manual test checklist for verifying Fiddlehead across macOS versions.
Run on VMs (UTM/Parallels) or physical hardware for each target version.

**Target versions:** macOS 14.0, 14.7, 15.0, 15.4 (latest)

---

## 1. Screen Recording Permission (CRITICAL)

| Test | 14.0 | 14.7 | 15.0 | 15.4 |
|------|------|------|------|------|
| Fresh install → permission prompt appears | | | | |
| Grant permission → system audio captures successfully | | | | |
| `CGPreflightScreenCaptureAccess()` returns correct status | | | | |
| Deny permission → app falls back to mic-only gracefully | | | | |
| Revoke permission in System Settings mid-session → no crash | | | | |
| After Sequoia periodic permission reset → app re-prompts | N/A | N/A | | |

**Risk notes:**
- macOS 15.0 introduced periodic permission resets for screen recording
- macOS 15.0 changed `SCContentFilter` interaction with the permission system
- Watch Console.app for `-3801` errors (permission denied)

---

## 2. Microphone Permission (HIGH)

| Test | 14.0 | 14.7 | 15.0 | 15.4 |
|------|------|------|------|------|
| Fresh install → mic permission prompt appears | | | | |
| Grant permission → mic audio captures at 16kHz mono | | | | |
| Deny permission → app shows appropriate error state | | | | |
| Revoke permission mid-recording → graceful stop | | | | |
| Mic + system audio both active → mixer produces correct output | | | | |
| System audio fails, mic succeeds → correct mono channel count sent to transcription | | | | |

**Risk notes:**
- macOS 15.x has stricter TCC enforcement — mic access may silently fail after upgrade
- Verify channel count: mic-only should connect to Deepgram with `channels=1`

---

## 3. Calendar Access (MEDIUM)

| Test | 14.0 | 14.7 | 15.0 | 15.4 |
|------|------|------|------|------|
| `requestFullAccessToEvents()` prompts correctly | | | | |
| Full access granted → upcoming meetings detected | | | | |
| "Add Only" access → `authorizationState` returns correct status | | | | |
| Deny access → no crash, calendar features disabled | | | | |
| Meeting with video URL → auto-detection works | | | | |
| Upgrade from 14.x → 15.x → existing authorization persists | N/A | N/A | | |

**Risk notes:**
- `requestFullAccessToEvents()` was introduced in macOS 14.0 — this is the deployment floor
- macOS 15.0 refreshed the authorization UI

---

## 4. MenuBarExtra & SwiftUI (LOW-MEDIUM)

| Test | 14.0 | 14.7 | 15.0 | 15.4 |
|------|------|------|------|------|
| Menu bar icon appears on launch | | | | |
| Clicking icon opens popover/window correctly | | | | |
| Window positioning correct on primary display | | | | |
| Window positioning correct on external display | | | | |
| Window dismisses when clicking outside | | | | |
| Settings window opens and all controls work | | | | |
| App stays responsive after 30+ min running | | | | |

**Risk notes:**
- SwiftUI `MenuBarExtra` behavior tweaked in 15.0 (window positioning, lifecycle)
- Test on both single and multi-monitor setups

---

## 5. Audio Recording & Compression (LOW)

| Test | 14.0 | 14.7 | 15.0 | 15.4 |
|------|------|------|------|------|
| Short recording (1 min) → WAV written correctly | | | | |
| Long recording (30+ min) → no corruption | | | | |
| WAV → M4A compression succeeds (valid file) | | | | |
| Split recording (>25MB) → both chunks valid | | | | |
| Audio playback of compressed file in QuickTime | | | | |

**Risk notes:**
- AVAudioFile WAV header finalization relies on `autoreleasepool` deallocation timing
- Verify M4A files are not 572 bytes (sign of unfinalzed WAV header bug)

---

## 6. Transcription & Structuring (LOW)

| Test | 14.0 | 14.7 | 15.0 | 15.4 |
|------|------|------|------|------|
| OpenAI transcription returns valid text | | | | |
| AssemblyAI transcription returns valid text | | | | |
| Structuring via gpt-4o-mini produces markdown | | | | |
| Daily note file written with correct frontmatter | | | | |
| Index.md updated correctly | | | | |

**Risk notes:**
- These are API calls, so OS version risk is minimal
- Network/TLS stack differences between 14.x and 15.x could theoretically cause issues

---

## 7. Sparkle Updates (LOW)

| Test | 14.0 | 14.7 | 15.0 | 15.4 |
|------|------|------|------|------|
| Update check completes without crash | | | | |
| Appcast.xml parsed correctly | | | | |
| Update download and install works | | | | |

---

## 8. Global Hotkey (LOW)

| Test | 14.0 | 14.7 | 15.0 | 15.4 |
|------|------|------|------|------|
| Hotkey registration works on launch | | | | |
| Hotkey triggers recording start/stop | | | | |
| No conflict with system shortcuts | | | | |

---

## How to Run

### VM Setup (UTM — free, Apple Silicon native)
1. Download macOS IPSW for each target version
2. Create VM: 4GB RAM, 64GB disk minimum
3. Install macOS, create user account
4. Build Fiddlehead locally: `xcodegen generate && xcodebuild archive`
5. Copy the .app to the VM via shared folder
6. Run through each section above, marking pass/fail

### Console Log Monitoring
On each VM, open Terminal and run:
```bash
log show --predicate 'subsystem == "com.kylefugere.Fiddlehead"' --last 5m --info --debug
```
Check for errors after each test section.

### What to Log
For each failed test, note:
- macOS version (full build number: `sw_vers`)
- Console log errors
- Steps to reproduce
- Screenshot if UI-related
