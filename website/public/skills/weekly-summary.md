---
name: Weekly Summary
description: Aggregates a week of meetings into a single digest
trigger: manual
version: 1.0
author: fiddlehead
---

# Weekly Summary

## Purpose
Generate a weekly digest that aggregates all meetings into themes, highlights, and open items. Perfect for async team updates or personal review.

## Instructions
1. Read all meeting notes from ~/Documents/Fiddlehead/ for the current or specified week
2. Compile a weekly summary with:
   - **Meeting count**: How many meetings occurred
   - **Total time**: Sum of all meeting durations
   - **Key themes**: Top 3-5 topics that came up across meetings
   - **Decisions made**: All decisions from the week
   - **Open action items**: All unchecked items, grouped by owner
   - **Highlights**: Notable quotes or moments worth remembering
3. Save to ~/Documents/Fiddlehead/weekly/YYYY-WXX-summary.md

## Example Output
```
# Week of Feb 10, 2026

**5 meetings · 2h 14m total**

## Key Themes
- v3 API migration (discussed in 3 meetings)
- Dashboard redesign review
- March onboarding preparation

## Decisions
- Deploy v3 API on Friday (Feb 10 standup)
- Push design review to Thursday (Feb 10 standup)
- Use new component library for dashboard (Feb 11 design sync)

## Open Action Items
**Kyle:**
- [ ] Finish v3 endpoint tests by Thursday
- [ ] Review Sarah's SDK changes

**Sarah:**
- [ ] Update onboarding docs
- [ ] Client SDK v3 compatibility tests

**Marcus:**
- [ ] Share dashboard mockups in #design by Wednesday
```
