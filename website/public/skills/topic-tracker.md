---
name: Topic Tracker
description: Traces how a specific topic evolved across meetings over time
trigger: manual
version: 1.0
author: fiddlehead
---

# Topic Tracker

## Purpose
Given a topic, search all meeting notes and build a chronological timeline showing how that topic evolved — what was discussed, what changed, what was decided, and where things stand now. Useful when someone asks "where did we land on X?" and the answer is scattered across weeks of meetings.

## Instructions
1. Accept a topic query from the user (e.g., "EY partnership", "dashboard redesign", "hiring plan", "pricing model")
2. Search all meeting notes in the user's notes directory for mentions of the topic — use the topic name, related keywords, and relevant people's names
3. For each relevant meeting, extract only the topic-specific content:
   - What was discussed about this topic
   - Any decisions made
   - Action items related to it
   - Changes in direction or sentiment
4. Arrange findings chronologically, earliest to latest
5. For each entry, include the meeting name and date for traceability
6. End with a **Current Status** section that synthesizes:
   - The latest known state of the topic
   - Any open/unresolved items
   - Who owns the next step
7. If no mentions are found, say so clearly rather than guessing

## Example Output
```
## Topic Timeline: Dashboard Redesign

### Mar 5 — Product Sync
First mention. Kyle proposed redesigning the analytics dashboard to support the new data model. No objections. Sarah volunteered to lead the design phase.

### Mar 8 — Design Review
Sarah presented three mockup options. Team preferred Option B (card-based layout). Marcus raised concerns about mobile responsiveness. Decision: proceed with Option B, Marcus to prototype responsive behavior.

### Mar 12 — Engineering Standup
Marcus shared responsive prototype. Identified a performance issue with the chart rendering library on mobile. Team agreed to evaluate alternative libraries before committing.

### Mar 15 — Product Sync
Chart library evaluation complete. Team chose Recharts over Victory based on bundle size and mobile performance. Sarah updated mockups to reflect library constraints. Target: ship to staging by Mar 22.

**Current Status:** Design finalized (Option B + Recharts). Marcus building responsive implementation. Targeting staging deploy Mar 22.
**Open Items:**
- [ ] Ship to staging by Mar 22 (@Marcus)
- [ ] QA pass on mobile breakpoints (@Sarah)
- [ ] Stakeholder demo after staging deploy (unassigned)
```
