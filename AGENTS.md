# Agents: Navigation + Workflow Contract

You are an LLM writing agent operating inside a standardized writing workspace repo.
Your job is to navigate the file structure, create missing artifacts, and compile high-quality drafts.

## Initial Setup

**When first setting up the project**, the agent should conduct an interview to gather universal context and populate the `universal/` directory files. Run the interview script:

```bash
./setup.sh
# or directly:
./interview/interview_script.sh
```

The interview gathers information to create:
- `universal/00_project_goal.md`
- `universal/01_audience.md`
- `universal/02_voice_tone_style.md`
- `universal/03_writing_guidelines.md`
- `universal/04_characters.md` (if applicable)

If the `universal/` directory is missing or incomplete, prompt the human to run the setup interview first.

## Repo map
- universal/: stable context for the entire project
  - 00_project_goal.md
  - 01_audience.md
  - 02_voice_tone_style.md
  - 03_writing_guidelines.md
  - 04_characters.md (default characters)
  - skills/: reusable playbooks
- docs/<DOC>/: per-document artifacts
  - 05_draft.md: **final compiled doc** for each document (output destination)
- compiler/: compilation instructions and output spec

## Document folder contract
Each docs/<DOC>/ folder SHOULD contain:
- 00_doc_goal.md (required)
- 01_outline.md (required)
- 02_key_facts.md (required if any facts/stats/quotes are used)
- 03_dialogue.md (recommended for most documents)
- 04_snippets.md (optional but useful)
- 05_draft.md (output destination)
- 06_review_notes.md (post-draft critique + next edits)

Optional overrides in docs/<DOC>/:
- characters.md (overrides universal/04_characters.md)
- agent_brief.md (current status + priorities + blockers)

## Defaulting rules
- If docs/<DOC>/characters.md does not exist, use universal/04_characters.md.
- If the doc goal conflicts with universal context, doc goal wins for that doc.
- If facts are missing, do NOT invent them. Add TODOs.

## Standard pipeline (create → refine → compile)
You should follow this order unless a doc is extremely simple:

1) Goal clarity
- Ensure docs/<DOC>/00_doc_goal.md is specific and testable.

2) Outline
- Create/repair docs/<DOC>/01_outline.md so it cleanly supports the goal.

3) Facts & anchors (if needed)
- Create/repair docs/<DOC>/02_key_facts.md.
- Every number/quote must have a source or a TODO.

4) Dialogue rehearsal (recommended)
- Create docs/<DOC>/03_dialogue.md to surface objections, crisp lines, and examples.

5) Snippet harvest (optional)
- Create/repair docs/<DOC>/04_snippets.md by harvesting best lines, hooks, transitions.

6) Compile draft
- Produce docs/<DOC>/05_draft.md aligned to compiler/01_output_spec.md.
- **This is the final compiled document** for that specific document.
- Location: `docs/<DOC>/05_draft.md` (where <DOC> is the document name/folder)

7) Review + next edits
- Produce docs/<DOC>/06_review_notes.md with prioritized changes.

## When to ask the human vs proceed
Proceed with best-effort defaults and mark TODOs unless missing info blocks progress.

Ask only if:
- the audience is unknown AND it materially changes the draft
- the call-to-action is unknown AND the document requires it
- key facts are required but unavailable (and the document depends on them)

Otherwise:
- choose a reasonable default and note assumptions in 06_review_notes.md.

## Hard rules
- Never fabricate facts, stats, quotes, or attributions.
- If something is uncertain, mark it as TODO or phrase it qualitatively.
- Keep artifacts small and composable; don't dump a whole draft into every file.
- Prefer editing existing files over creating new ones unless needed.

## Skill invocation
Use skills in universal/skills/*.md as playbooks.
If unsure what to do next, run:
- universal/skills/critique.md (to diagnose gaps)
then pick the next skill accordingly.
