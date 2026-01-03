# Project Initialization

Conduct an interview to gather universal context and populate the `universal/` directory files.

## Trigger

Run this when:
- `universal/` directory files are missing or contain only placeholders
- `meta/project_state.md` shows `initialized: false`
- Explicitly requested by the user

## Process

Ask questions in 3-5 question batches to avoid overwhelming the user.

### Batch 1: Project Basics
1. **Project Goal**: What is this writing project trying to achieve?
2. **Primary Purpose**: What is the main purpose or problem this project addresses?
3. **Project Type**: What type of writing project is this? (blog, book, documentation, etc.)

### Batch 2: Audience
4. **Primary Audience**: Who is the primary audience for this writing?
5. **Audience Characteristics**: What are the key characteristics of this audience?
6. **Audience Needs**: What does this audience need from the writing?

### Batch 3: Voice, Tone, Style
7. **Voice**: What personality and character should the writing convey?
8. **Tone**: What attitude should the writing have?
9. **Style Guidelines**: What style guidelines should be followed?
10. **Examples**: Can you provide examples of the desired voice/tone/style?

### Batch 4: Writing Guidelines (Optional)
11. **Formatting Rules**: Any specific formatting requirements?
12. **Structure Preferences**: Any structure preferences or constraints?
13. **Do's and Don'ts**: Any specific things to do or avoid?

### Batch 5: Characters (If Applicable)
14. **Characters**: Does this project involve characters? If so, describe them.
15. **Character Voices**: How should different characters speak or be written?

## Output

After gathering answers, create/update:
- `universal/00_project_goal.md`
- `universal/01_audience.md`
- `universal/02_voice_tone_style.md`
- `universal/03_writing_guidelines.md`
- `universal/04_characters.md` (if applicable)
- `universal/05_glossary.md` (if terms were discussed)
- `universal/06_sources_policy.md` (if sourcing was discussed)

Record any assumptions or TODOs in `meta/changelog.md`.

Set `meta/project_state.md` → `initialized: true`.

## Notes

- Don't re-run this interview unless explicitly requested or project_state shows not initialized
- If user doesn't know an answer, mark as TODO and proceed
- Keep questions conversational and avoid jargon

