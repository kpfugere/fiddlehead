---
name: Accountability Tracker
description: Tracks who committed to what across meetings and flags overdue items
trigger: manual
version: 1.0
author: fiddlehead
---

# Accountability Tracker

## Purpose
Scan meetings over a time range, extract every action item by owner, and cross-reference later meetings for completion signals. Produce a per-person accountability report that flags what's done, what's in progress, and what fell through the cracks.

## Instructions
1. Read all meeting notes from the user's notes directory for the specified time range (default: last 14 days)
2. Extract all action items — look for:
   - Checkbox items: `- [ ]` and `- [x]`
   - Assignments in transcripts: "I'll do X", "can you handle Y", "action item: Z"
   - Items with owners: `(@name)`, `@name`, or names mentioned alongside commitments
   - Due dates: "by Friday", "by end of week", "by March 20"
3. For each action item, search subsequent meeting notes for completion signals:
   - Checked boxes: `- [x]`
   - Transcript mentions: "that's done", "finished the...", "shipped", "completed"
   - If the item appears in a later meeting's action items still unchecked, it's still open
4. Classify each item as:
   - **Completed**: Evidence of completion found
   - **In Progress**: Mentioned in a later meeting but not yet done
   - **Overdue**: Has a due date that has passed with no completion signal
   - **No Update**: Not mentioned again after assignment — potential drop
5. Group by person and sort by urgency (overdue first, then no-update, then in-progress)
6. Include a summary line with completion stats

## Example Output
```
## Accountability Report — Mar 6–20, 2026

### Sarah (4 items)
- [x] Update onboarding docs with new tooling setup — completed Mar 12
- [ ] Client SDK tests against v3 endpoints (assigned Mar 10) — IN PROGRESS, mentioned Mar 15
- [ ] Schedule design review with Marcus (assigned Mar 10, due Mar 14) — OVERDUE
- [ ] Write post-mortem for last week's outage (assigned Mar 12) — NO UPDATE

### Marcus (2 items)
- [x] Share dashboard mockups in #design (assigned Mar 10, due Mar 13) — completed Mar 13
- [ ] Finalize component library migration (assigned Mar 15) — NO UPDATE

### Kyle (3 items)
- [x] Follow up with EY procurement — completed Mar 8
- [x] Finish v3 endpoint tests — completed Mar 11
- [ ] Draft Q2 OKRs (assigned Mar 12, due Mar 19) — OVERDUE

**Summary:** 4 of 9 items completed (44%). 2 overdue. 2 with no update since assignment.
```
