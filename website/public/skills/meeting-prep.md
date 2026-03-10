---
name: Meeting Prep
description: Reviews past meetings with a contact to prepare you for the next one
trigger: manual
version: 1.0
author: fiddlehead
---

# Meeting Prep

## Purpose
Before a meeting with someone, review all past meeting notes that mention them. Surface open action items, unresolved discussions, and relevant context.

## Instructions
1. Accept a contact name as input (e.g., "Sarah", "Marcus Chen")
2. Search all meeting notes in ~/Documents/Fiddlehead/ for mentions of that person
3. Compile a prep brief that includes:
   - **Last meeting**: When you last met and what was discussed
   - **Open action items**: Any items assigned to them or involving them that are unchecked
   - **Recent topics**: Key themes from the last 3-5 meetings involving them
   - **Unresolved items**: Anything that was deferred or left open
4. Present as a concise briefing document

## Example Output
```
## Meeting Prep: Sarah Chen

**Last met:** Feb 10, 2026 (Standup Sync)

**Open action items:**
- [ ] Update onboarding docs with new tooling setup (due: this week)
- [ ] Client SDK tests against v3 endpoints (from Feb 10)

**Recent topics:**
- Onboarding documentation refresh
- Client SDK compatibility with v3 API
- QA process for the dashboard redesign

**Unresolved:**
- Dashboard redesign feedback — waiting on Marcus's mockups before Sarah can review
```
