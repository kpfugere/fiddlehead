---
name: Decision Log
description: Extracts decisions across meetings into a running log
trigger: manual
version: 1.0
author: fiddlehead
---

# Decision Log

## Purpose
Maintain a running log of decisions made across meetings. Useful for auditing, onboarding new team members, and avoiding re-litigating settled questions.

## Instructions
1. Read all meeting notes from ~/Documents/Fiddlehead/ in the specified time range (default: last 30 days)
2. Extract any statements that represent a decision (look for phrases like "we decided", "let's go with", "agreed to", "the plan is")
3. For each decision, capture:
   - **Date**: When the decision was made
   - **Meeting**: Which meeting it came from
   - **Decision**: What was decided
   - **Context**: Brief reasoning or discussion that led to it
   - **Owner**: Who is responsible for executing
4. Append new decisions to ~/Documents/Fiddlehead/decision-log.md
5. Avoid duplicating decisions already in the log

## Output Format
```
## Decision Log

| Date | Decision | Context | Owner |
|------|----------|---------|-------|
| 2026-02-10 | Deploy v3 API on Friday | Auth endpoints migrated, billing webhooks nearly done | Marcus |
| 2026-02-10 | Update onboarding docs before March hires | Current docs outdated with tooling changes | Sarah |
```
