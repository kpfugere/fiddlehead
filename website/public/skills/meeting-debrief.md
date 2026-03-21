---
name: Meeting Debrief
description: Structured post-mortem for a meeting — dynamics, commitments, risks, and suggested follow-ups
trigger: manual
version: 1.0
author: fiddlehead
---

# Meeting Debrief

## Purpose
Generate a structured debrief after an important meeting — sales call, investor pitch, client presentation, or negotiation. Analyzes what happened beyond the surface: conversation dynamics, implicit signals, unanswered questions, and non-obvious follow-up opportunities.

## Instructions
1. Read the specified meeting note (default: most recent meeting in the user's notes directory)
2. Analyze the conversation and produce a debrief covering:

   **Meeting Dynamics**
   - Approximate speaker balance (who drove the conversation)
   - Overall tone and energy (collaborative, adversarial, one-sided, exploratory)
   - Whether the meeting achieved its apparent purpose

   **Questions & Answers**
   - List questions the other party asked
   - Note which were answered clearly, which were deflected, and which went unanswered
   - Flag any questions you asked that didn't get a clear answer back

   **Commitments Made**
   - Explicit commitments: things someone directly said they would do
   - Implicit commitments: expectations created by the conversation even if not stated as action items (e.g., "we'll definitely keep you in the loop" creates an expectation of follow-up)

   **Signals & Risks**
   - Positive signals: enthusiasm, urgency, specific next steps proposed by the other party
   - Warning signals: hedging language, deflection, lack of commitment, vague timelines
   - Topics they avoided or steered away from

   **Suggested Follow-ups**
   - Standard follow-ups from explicit commitments
   - Non-obvious follow-ups based on signals detected (e.g., address an unanswered question proactively, prepare for an objection that was hinted at)

3. Be specific — reference actual quotes or moments from the transcript when possible
4. Keep analysis grounded in what was said, not speculation

## Example Output
```
## Debrief: Investor Call — Mar 18

**Meeting Dynamics:**
- Kyle drove ~65% of the conversation (pitch-heavy)
- Investor was engaged but measured — asked pointed questions, didn't volunteer enthusiasm
- Purpose was a first-look pitch; achieved — investor agreed to a follow-up

**Questions Asked by Investor:**
- "What's your current ARR?" — answered clearly ($1.2M)
- "How do you handle churn in enterprise accounts?" — deflected to general retention strategy, no specific number given
- "What's the path to profitability?" — answered with timeline (18 months) but investor didn't react

**Commitments:**
- *Explicit:* Kyle to send updated deck and financial model by Friday
- *Explicit:* Investor to share with partner and schedule follow-up next week
- *Implicit:* Kyle referenced "our enterprise roadmap" — investor may expect detail on this in the next call

**Signals:**
- Positive: Investor asked about deal terms unprompted — suggests genuine interest
- Positive: Agreed to a follow-up with their partner (escalation)
- Warning: "We're being pretty conservative right now" — said twice, may signal smaller check or longer diligence
- Warning: No questions about the team — unusual if they're seriously considering

**Suggested Follow-ups:**
- [ ] Send deck + model by Thursday (one day early)
- [ ] Prepare a clear churn answer with specific enterprise retention numbers
- [ ] Include a team slide in the follow-up deck — they didn't ask, which could mean they're not sold on team yet
- [ ] Draft a brief "path to profitability" one-pager to preempt deeper diligence
```
