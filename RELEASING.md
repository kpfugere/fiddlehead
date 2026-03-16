# Releasing Fiddlehead

## One-Time Setup

These steps only need to be done once.

### 1. Apple Developer Program

1. Enroll at https://developer.apple.com/programs/ ($99/year)
2. Wait for approval (usually instant for individuals)

### 2. Developer ID Certificate

1. Open **Xcode > Settings > Accounts** and sign in with your Apple ID
2. Select your team, click **Manage Certificates**
3. Click **+** and choose **Developer ID Application**
4. Verify it was created:
   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```
5. Note your **Team ID** (10-char alphanumeric in parentheses)

### 3. Export Certificate for CI

1. Open **Keychain Access**
2. Find "Developer ID Application: Kyle Fugere" under login keychain
3. Expand it to reveal the private key
4. Select **both** the certificate and private key → right-click → **Export Items**
5. Save as `Certificates.p12` with a strong password
6. Base64-encode it:
   ```bash
   base64 -i Certificates.p12 | pbcopy
   ```

### 4. App-Specific Password

1. Go to https://appleid.apple.com → **Sign-In and Security** → **App-Specific Passwords**
2. Generate one, label it "Fiddlehead Notarization"
3. Save the password (format: `xxxx-xxxx-xxxx-xxxx`)

### 5. Sparkle EdDSA Key

After the Sparkle SPM dependency is resolved, generate a key pair:

```bash
# Option A: Use the tool from the SPM build artifacts
find ~/Library/Developer/Xcode/DerivedData -name "generate_keys" -path "*/Sparkle/*" 2>/dev/null | head -1

# Option B: Download Sparkle release and use bundled tool
curl -sL -o /tmp/sparkle.tar.xz \
  "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz"
mkdir -p /tmp/sparkle && tar -xf /tmp/sparkle.tar.xz -C /tmp/sparkle
/tmp/sparkle/bin/generate_keys
```

This prints an EdDSA **public key** and stores the **private key** in your Keychain.

- Copy the **public key** and put it in `Fiddlehead/Info.plist` as the `SUPublicEDKey` value
- Export the **private key** for CI (the tool will tell you how)

### 6. GitHub Repository Secrets

Go to your repo → **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|--------|-------|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded .p12 from step 3 |
| `APPLE_CERTIFICATE_PASSWORD` | The .p12 export password |
| `APPLE_DEVELOPER_TEAM_ID` | Your 10-character Team ID |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_APP_SPECIFIC_PASSWORD` | From step 4 |
| `SPARKLE_PRIVATE_KEY` | Sparkle EdDSA private key from step 5 |

---

## Cutting a Release

Once the one-time setup is done, releasing is straightforward:

### 1. Decide the Version

- **PATCH** (0.1.0 → 0.1.1): Bug fixes only
- **MINOR** (0.1.0 → 0.2.0): New features (pre-1.0, this is the default for features)
- **MAJOR** (0.x → 1.0.0): Breaking changes or "ready for public"

### 2. Update Version and Changelog

In `project.yml`, update:
- `MARKETING_VERSION` to the new version (e.g., `"0.2.0"`)
- `CURRENT_PROJECT_VERSION` — increment by 1 (e.g., `"2"`)

In `CHANGELOG.md`:
- Move entries from `## [Unreleased]` to a new section: `## [0.2.0] - YYYY-MM-DD`
- Add a fresh empty `## [Unreleased]` section at the top

### 3. Commit and Tag

```bash
git add project.yml CHANGELOG.md
git commit -m "release: v0.2.0"
git tag -a v0.2.0 -m "v0.2.0"
```

### 4. Push

```bash
git push origin main
git push origin v0.2.0
```

### 5. What Happens Automatically

The `release.yml` GitHub Actions workflow will:

1. Build the app in Release configuration (hardened runtime, Developer ID signed)
2. Create a DMG with the app + Applications shortcut
3. Submit the DMG to Apple for notarization (takes 2-15 minutes)
4. Staple the notarization ticket to the DMG
5. Sign the DMG with your Sparkle EdDSA key
6. Create a GitHub Release with the DMG attached and changelog in the description
7. Update `website/public/appcast.xml` with the new version entry
8. Commit the appcast update to main (triggers website redeploy)

### 6. Verify

- Check the [Actions tab](../../actions) to confirm the workflow succeeded
- Download the DMG from the GitHub Release and test it:
  ```bash
  # Verify notarization
  spctl -a -vvv /Volumes/Fiddlehead/Fiddlehead.app
  # Should say: source=Notarized Developer ID
  ```
- Existing users with the app installed will get an update prompt via Sparkle

---

## Troubleshooting

### Notarization fails
```bash
# Get the detailed log (submission ID is in the Actions output)
xcrun notarytool log <submission-id> \
  --apple-id your@email.com \
  --password xxxx-xxxx-xxxx-xxxx \
  --team-id TEAMID
```
Common issues: unsigned embedded frameworks, missing hardened runtime.

### DMG shows "damaged" or Gatekeeper blocks it
The DMG wasn't properly notarized/stapled. Check the Actions log for the notarization step.

### Sparkle doesn't find updates
- Verify `appcast.xml` was updated: https://fiddleheadai.com/appcast.xml
- Check the version in the appcast is newer than the installed version
- Check Console.app for Sparkle-related log messages

### Certificate expired
Developer ID certificates last 5 years. To renew:
1. Create a new certificate in Xcode
2. Export a new .p12
3. Update the `APPLE_CERTIFICATE_BASE64` and `APPLE_CERTIFICATE_PASSWORD` GitHub secrets
