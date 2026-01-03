# Build Prompt Template

Template for prompting compilation of documents.

## Standard Build Prompt

Compile the document in `docs/<DOC>/` following this process:

1. Review `00_doc_goal.md` to understand the purpose
2. Follow the structure in `01_outline.md`
3. Incorporate facts from `02_key_facts.md` (with citations)
4. Include dialogue elements from `03_dialogue.md`
5. Use snippets from `04_snippets.md` where appropriate
6. Maintain voice/tone from `universal/02_voice_tone_style.md`
7. Follow format specified in `compiler/01_output_spec.md`
8. Write the compiled draft to `docs/<DOC>/05_draft.md`

## Context Precedence

Use this order when resolving conflicts:

1. Explicit human instruction in current session
2. `docs/<DOC>/...` files (document-specific)
3. `universal/...` files (project-wide)
4. Defaults in `universal/agents.md`

## Hard Constraints

- Never invent facts, stats, quotes, or attributions
- If facts are missing, mark as TODO
- Keep artifacts small and composable
- Prefer editing existing files over creating new ones

