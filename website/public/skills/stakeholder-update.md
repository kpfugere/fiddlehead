---
name: Stakeholder Update Generator
description: Generates a polished status update for leadership, investors, or board from recent meetings
trigger: manual
version: 1.0
author: fiddlehead
---

# Stakeholder Update Generator

## Purpose
Generate a concise, executive-level status update from a week of meetings. Filters out operational noise and focuses on outcomes, risks, decisions, and milestones — the things stakeholders actually care about.

## Instructions
1. Read all meeting notes from the user's notes directory for the current or specified week
2. Categorize information across meetings into:
   - **Progress & Wins**: Concrete outcomes, milestones hit, deals closed, features shipped
   - **Risks & Blockers**: Items that could derail timelines or goals, unresolved dependencies
   - **Decisions Made**: Strategic or significant decisions with brief context
   - **Upcoming**: Key milestones, deadlines, or events in the next 1-2 weeks
3. Filter aggressively — omit operational details, internal process discussions, and routine status. Include only what changes someone's understanding of the business or project
4. Write in third-person team voice, not transcript voice. Be specific with names, numbers, and dates
5. Keep the update under 300 words
6. If a time range is not specified, default to the last 7 days
7. Optionally include a "Needs Input" section for items requiring stakeholder decisions

## Tone
Direct and confident. No hedging, no filler. Write like a chief of staff briefing a board member who has 2 minutes.

## Example Output
```
## Status Update — Week of Mar 17, 2026

### Progress
- EY integration meeting completed; data access confirmed through Q3
- Self-serve pricing model finalized — launching to beta users next week
- Engineering headcount restructured around three focus areas (data, platform, growth)

### Risks & Blockers
- $600K receivable from Acme Corp still outstanding — legal escalation under review
- Enterprise pipeline thin beyond current active deals; outbound motion needs acceleration

### Decisions Made
- Pivoting to consulting-led, industry-agnostic positioning (Mar 18 leadership meeting)
- Deprioritizing crypto-only self-serve path in favor of broader market approach

### Upcoming
- Board prep materials due Friday Mar 21
- R3 partnership call Wednesday Mar 19
- Beta pricing launch targeting Mar 24

### Needs Input
- Legal escalation on Acme receivable — proceed or hold?
```
