# Agent Build Instructions

Instructions for agents on how to compile documents.

## Standard Pipeline

Follow the pipeline defined in `universal/agents.md`:

1. Ensure `00_doc_goal.md` exists and is specific
2. Create/repair `01_outline.md`
3. Create/repair `02_key_facts.md` if needed
4. Create/repair `03_dialogue.md` (default: yes)
5. Harvest/update `04_snippets.md` (optional)
6. Compile into `05_draft.md`
7. Write `06_review_notes.md` with prioritized edits

## Compilation Process

When compiling `05_draft.md`:

1. Follow `01_outline.md` for structure
2. Reference `compiler/01_output_spec.md` for format requirements
3. Incorporate facts from `02_key_facts.md`
4. Include dialogue elements from `03_dialogue.md`
5. Use snippets from `04_snippets.md` where appropriate
6. Maintain voice/tone from `universal/02_voice_tone_style.md`

## Output Location

**Canonical output**: `docs/<DOC>/05_draft.md`

This is the final compiled document for each document.

