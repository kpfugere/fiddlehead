---
name: Meeting Follow-up Drafter
description: Generates follow-up emails from action items and key decisions
trigger: manual
version: 1.0
author: fiddlehead
---

# Meeting Follow-up Drafter

## Purpose
Draft a professional follow-up email after a meeting, pulling action items and key decisions from the structured notes.

## Instructions
1. Read the most recent meeting note from ~/Documents/Fiddlehead/
2. Extract all action items and key decisions
3. Draft a concise follow-up email that:
   - Opens with a brief summary of what was discussed
   - Lists action items with owners and deadlines
   - Highlights any decisions that were made
   - Closes with next steps or the next meeting date
4. Save the draft to ~/Documents/Fiddlehead/drafts/

## Tone
Professional but concise. Match the communication style of the team. No corporate fluff.

## Example Output
```
Subject: Follow-up: Standup Sync — Feb 10

Hey team,

Quick recap from today's standup:

**Decisions:**
- Targeting Friday for the v3 API deploy

**Action items:**
- @kyle: finish v3 endpoint tests by Thursday
- @sarah: update onboarding docs with new tooling setup
- @marcus: share dashboard mockups in #design by Wednesday

Let me know if I missed anything. Next standup is Thursday at 10am.
```
