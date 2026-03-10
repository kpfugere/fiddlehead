# Fiddlehead

## Versioning & Release Rules

When making changes to this project, follow these versioning practices:

### CHANGELOG Maintenance
- A `CHANGELOG.md` exists at the repo root following Keep a Changelog format.
- When completing a feature, bug fix, or notable change, add an entry under `## [Unreleased]` in the appropriate category (`Added`, `Changed`, `Fixed`, `Removed`).
- Write changelog entries from a user's perspective — what changed for them, not internal refactors.
- Do NOT add entries for purely internal refactors, code cleanup, or comment changes unless they affect behavior.

### Version Bumping
- The single source of truth for the version is `project.yml` — specifically `MARKETING_VERSION` (semver string) and `CURRENT_PROJECT_VERSION` (integer build number).
- When the user asks to cut a release or bump the version:
  1. Determine the version bump type (MAJOR/MINOR/PATCH) based on changes since the last release. Pre-1.0: MINOR = features, PATCH = fixes.
  2. Update `MARKETING_VERSION` in `project.yml` to the new semver string.
  3. Increment `CURRENT_PROJECT_VERSION` by 1.
  4. Move `## [Unreleased]` entries in CHANGELOG.md under a new `## [X.Y.Z] - YYYY-MM-DD` heading and add a fresh empty `## [Unreleased]` section.
  5. Commit with message: `release: vX.Y.Z`
  6. Create an annotated git tag: `git tag -a vX.Y.Z -m "vX.Y.Z"`
- Do NOT push tags or create GitHub releases without explicit user confirmation.

### Git Tags
- Tag format: `vX.Y.Z` (e.g., `v0.2.0`)
- Always use annotated tags (`git tag -a`)
- Tag the release commit (the one that bumps project.yml + CHANGELOG)

### What NOT to Do
- Never modify `MARKETING_VERSION` or `CURRENT_PROJECT_VERSION` outside of an explicit release/version bump request.
- Never create a git tag without also updating project.yml and CHANGELOG.md.
- Never skip the CHANGELOG — every release must document what changed.
