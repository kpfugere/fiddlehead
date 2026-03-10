---
name: Linear Issue Creator
description: Turns meeting action items into structured Linear issues
trigger: manual
version: 1.0
author: fiddlehead
---

# Linear Issue Creator

## Purpose
Convert action items from meeting notes into well-structured Linear issue descriptions ready to create via the API or paste into Linear.

## Instructions
1. Read the most recent meeting note from ~/Documents/Fiddlehead/
2. For each action item, create an issue with:
   - **Title**: Clear, actionable summary (imperative mood)
   - **Description**: Context from the meeting discussion
   - **Acceptance Criteria**: What "done" looks like based on the conversation
   - **Assignee**: The person mentioned in the action item
   - **Priority**: Inferred from urgency cues in the transcript (Urgent, High, Medium, Low)
   - **Label**: Suggested label based on the topic
3. Output all issues in a single markdown file

## Example Output
```
## Issue: Finish v3 Endpoint Tests

**Assignee:** Kyle
**Priority:** High
**Label:** backend

### Description
The v3 API migration is 90% complete with auth endpoints migrated. Billing webhooks are the remaining work with a Friday deploy target. Endpoint tests need to pass before deploy.

### Acceptance Criteria
- [ ] All v3 endpoint tests passing
- [ ] Billing webhook tests included
- [ ] CI green on the migration branch
```
