---
name: Meeting ROI Analyzer
description: Analyzes your meeting patterns and identifies which meetings produce outcomes and which don't
trigger: manual
version: 1.0
author: fiddlehead
---

# Meeting ROI Analyzer

## Purpose
Audit your meeting schedule using your actual notes. Score each meeting or recurring series by the outcomes it produces — decisions, action items, and progress. Surface which meetings are worth your time and which are candidates for cutting, shortening, or restructuring.

## Instructions
1. Read all meeting notes from the user's notes directory for the specified range (default: last 30 days)
2. For each meeting, count:
   - **Decisions made**: Items in a Decisions section, or statements like "we agreed", "let's go with", "decision:"
   - **Action items generated**: Checkbox items (`- [ ]`)
   - **Key points**: Substantive bullet points in Key Points sections
3. Group meetings by recurring series — match by title similarity and attendees (e.g., "Product Sync", "Product Sync — Mar 10", "Weekly Product Sync" are the same series)
4. For each meeting or series, calculate:
   - Total occurrences in the period
   - Total time spent (sum of durations)
   - Total decisions, action items, and key points
   - **Outcome density**: (decisions + action items) per hour
5. Rank meetings by outcome density, highest to lowest
6. Classify each as:
   - **High ROI**: Consistently produces decisions and action items
   - **Medium ROI**: Produces some outcomes, but could be more efficient
   - **Low ROI**: Minimal measurable outcomes relative to time invested
7. For low-ROI meetings, suggest one of: cancel, shorten, make async, or restructure with an agenda
8. Include a summary with total meeting time and the percentage that produced meaningful outcomes

## Example Output
```
## Meeting ROI — Feb 15 – Mar 15, 2026

| Meeting | Count | Total Time | Decisions | Action Items | Density | Rating |
|---------|-------|-----------|-----------|-------------|---------|--------|
| Leadership Team | 4 | 6h 12m | 12 | 18 | 4.8/hr | High |
| Product Sync | 4 | 2h 00m | 6 | 8 | 7.0/hr | High |
| Design Review | 2 | 1h 30m | 3 | 4 | 4.7/hr | High |
| Team Standup | 12 | 3h 00m | 2 | 4 | 2.0/hr | Low |
| 1:1 with Dave | 4 | 2h 00m | 0 | 1 | 0.5/hr | Low |
| All Hands | 2 | 2h 00m | 1 | 0 | 0.5/hr | Low |

### Recommendations
- **Team Standup** (3h/month, 2.0/hr): Low outcome density. Consider switching to async standups in Slack with a weekly sync for blockers only.
- **1:1 with Dave** (2h/month, 0.5/hr): No decisions in 4 sessions. Consider adding a shared agenda doc or reducing to biweekly.
- **All Hands** (2h/month, 0.5/hr): Informational, not decisional. Could this be a recorded Loom instead?

### Summary
**26 meetings · 16h 42m total**
58% of meeting time (Leadership + Product + Design) produced high-density outcomes.
42% of meeting time (7h) produced minimal measurable outcomes.
```
