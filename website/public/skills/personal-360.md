---
name: Personal 360
description: Analyzes your communication patterns across meetings to surface strengths, blind spots, and growth areas
trigger: manual
version: 1.0
author: fiddlehead
---

# Personal 360

## Purpose
Generate a 360-style feedback report using your own meeting transcripts as evidence. Traditional 360s rely on peer surveys — this one uses the raw behavioral record of how you actually show up in meetings. It surfaces patterns across many meetings, not just one, and grounds every observation in specific examples.

## Instructions

### Step 1: Gather Data
1. Read all meeting notes from the user's notes directory for the specified range (default: last 30 days)
2. You need at least 5 meetings with transcripts to produce meaningful patterns. If fewer are available, say so and offer to run with what's there while noting the limited sample
3. Identify the user — they are typically the most frequent speaker, labeled "Me", "Kyle", or similar. Ask if unclear

### Step 2: Optional Self-Rating
Before presenting results, ask the user to rate themselves 1-5 on these dimensions (skip if they prefer to go straight to results):
- Communication clarity
- Listening & making space for others
- Follow-through on commitments
- Decision-making
- Coaching & developing others
- Strategic thinking

This enables blind-spot detection — the gap between self-perception and transcript evidence is the most valuable insight.

### Step 3: Analyze Across These Dimensions

For each dimension, look for specific transcript signals:

**Communication Clarity**
- Are statements structured and concise, or meandering?
- Do others ask clarifying questions after the user speaks? (signals lack of clarity)
- Look for hedging patterns: "I think maybe sort of", "kind of", "I guess"
- Look for clear framing: "there are three things", "the main point is", "to summarize"

**Listening & Space-Making**
- Estimate talk-time ratio across meetings (research suggests 43:57 talk-to-listen is optimal)
- Longest monologues (>2.5 minutes is a flag)
- Does the user reference what the previous speaker said, or pivot to their own point?
- Does the user invite input? ("what do you think?", "any concerns?", "how do you see it?")
- Note differences by meeting type — talking more in a presentation is expected, talking more in a brainstorm is a flag

**Follow-Through & Accountability**
- Do action items from meeting N appear resolved by meeting N+1?
- Does the user proactively report back on commitments? ("I said I'd do X — here's where it stands")
- Are commitments specific? (who, what, when) or vague? ("I'll look into it")
- Count: commitments made vs. commitments with evidence of completion

**Decision-Making**
- Does the user drive toward decisions or let discussions loop?
- Are decisions stated clearly? ("so we're going with X")
- Do decisions stick, or get re-litigated in later meetings?
- Does the user summarize options before deciding, or jump to a conclusion?

**Collaboration & Credit**
- "We" vs "I" ratio
- Does the user reference others' contributions? ("as Sarah mentioned", "building on what Marcus said")
- Does the user explicitly credit others' work?
- Does the user engage with disagreement constructively, or shut it down / avoid it?

**Coaching & Developing Others**
- Question-to-statement ratio, especially in 1:1s
- Open questions ("how would you approach this?") vs. closed questions ("did you finish it?")
- Does the user jump to solutions, or help others work through problems?
- Does the user delegate with context, or just assign tasks?

**Strategic Thinking**
- Does the user connect tactical items to goals, strategy, or customer impact?
- Frequency of "why" and "so that" framing
- Does the user zoom out during operational discussions, or stay in the weeds?
- Does the user raise topics proactively, or only react to what others bring up?

### Step 4: Produce the Report

Structure the report as follows:

1. **Overview**: 2-3 sentence summary of the user's overall meeting presence and communication style

2. **Strengths** (2-3): Dimensions where transcripts show consistent strong performance. Each strength must include at least one specific example with a quote and meeting reference

3. **Growth Areas** (2-3): Dimensions where transcripts show room for improvement. Each must include specific evidence — not generic advice. Say "In your last 8 standups, your average statement length was X and you asked 2 questions total" not "try to listen more"

4. **Blind Spots** (if self-ratings were provided): Where self-rating diverges from transcript evidence. This is the most valuable section. Frame it neutrally — blind spots can be positive (underestimating a strength) or negative (overestimating one)

5. **Patterns by Meeting Type**: Note how communication style shifts across different meeting types (1:1s, group syncs, presentations, brainstorms). Different contexts have different norms — flag where the user adapts well and where they don't

6. **Specific Suggestions**: 2-3 concrete, actionable experiments to try. Not "communicate better" — more like "In your next standup, try limiting your updates to 60 seconds and asking one question to someone else"

### Important Guidelines
- Analyze across many meetings, not just one. Patterns matter more than incidents
- Always cite specific meetings and quotes as evidence
- Be honest but constructive. This is a development tool, not a performance review
- Acknowledge that transcripts don't capture tone, body language, or sidebar conversations
- Set different baselines for different meeting types — leading a meeting vs. attending one, 1:1 vs. group
- If the data is thin on a dimension, say so rather than speculating

## Example Output
```
## Personal 360 — Kyle, Mar 1–30, 2026
*Based on 18 meetings (12h 40m total)*

### Overview
You're a decisive, action-oriented communicator who drives meetings toward outcomes. Your strongest pattern is clear decision-making — meetings you lead almost always end with explicit next steps. Your biggest growth opportunity is making more space for others in group settings, where you tend to carry 60%+ of the conversation.

### Strengths

**Decision-Making**
You consistently close loops. In 14 of 18 meetings, you stated decisions explicitly ("so we're going with X", "let's lock that in"). Decisions you make tend to stick — only 1 instance of re-litigation across the month (the pricing model, revisited on Mar 15 after new data).
> "Okay, we've heard both sides. Let's go with the usage-based model for beta and revisit after 90 days of data. Marcus, can you spec that by Friday?" — Mar 12 Product Sync

**Follow-Through**
Strong pattern of closing the loop on commitments. Of 11 action items you took on, 9 had evidence of completion or progress updates in subsequent meetings. You proactively report status ("I said I'd send the deck — it went out yesterday").

### Growth Areas

**Listening & Space-Making**
In group meetings (standups, syncs), your estimated talk ratio is ~62%. Your longest monologue was 3m 40s in the Mar 8 standup. In contrast, your 1:1s are well-balanced (~48% talk time). You asked a total of 6 questions across 10 group meetings vs. 22 questions across 8 one-on-ones.
> Consider: your 1:1 style (curious, question-driven) is effective. The gap suggests group settings trigger a different mode — possibly a felt responsibility to fill space or drive pace.

**Coaching & Developing Others**
In 1:1s with direct reports, you tend to jump to solutions quickly. In 5 of 8 one-on-ones, when someone raised a problem, your first response was a directive ("just do X", "I'd go with Y") rather than a question. One exception was the Mar 20 1:1 with Sarah where you asked "how would you approach this?" — she came up with a stronger solution than the one you likely would have suggested.

### Blind Spots
*Based on your self-ratings*

| Dimension | Self-Rating | Evidence | Gap |
|-----------|-----------|----------|-----|
| Listening | 4/5 | ~62% talk time in groups, 6 questions in 10 meetings | Overestimate |
| Strategic Thinking | 2/5 | Connected to strategy in 7 of 18 meetings, often the one to zoom out | Underestimate |
| Follow-Through | 4/5 | 9 of 11 items completed with evidence | Accurate |

Your biggest blind spot is **strategic thinking** — you rated yourself low, but transcripts show you're frequently the person who connects tactical work to the bigger picture. You may not recognize this because it feels natural to you.

### Patterns by Meeting Type
- **1:1s**: Your strongest format. Balanced talk time, more questions, better coaching instincts
- **Group Syncs/Standups**: You tend to over-index on driving pace, which crowds out quieter voices
- **External Meetings (sales, partners)**: Clear and compelling. Good at reading the room and adjusting

### Suggestions
1. **The 60-second rule**: In your next 3 standups, limit your own updates to 60 seconds and ask one question to someone who hasn't spoken yet
2. **The coaching pause**: In your next 1:1, when someone raises a problem, ask "what options are you considering?" before offering your take. Time yourself — try to hold for 10 seconds
3. **Name the strength**: You underrate your strategic thinking. Start explicitly framing it: "zooming out for a second — this connects to our Q2 goal because..." This makes the value visible to you and to your team
```
