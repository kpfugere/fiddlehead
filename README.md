# Writing Workspace Template

A standardized writing workspace template for creating high-quality documents using a structured, agent-friendly workflow.

## What This Repo Is

This is a template repository that provides:
- A standardized structure for writing projects
- Universal context management (`universal/`)
- Per-document artifact organization (`docs/<DOC>/`)
- Compilation system (`compiler/`)
- Reusable skills and playbooks (`universal/skills/`)

## Canonical Output Rule

**For every document folder:**

**Canonical compiled document**: `docs/<DOC>/05_draft.md`

All other files are inputs, generators, or diagnostics.

## Quick Start

### Create a New Document

1. **Copy the template**:
   ```bash
   cp -R docs/_TEMPLATE_DOC docs/my_document_name
   ```

2. **Fill in the goal**: Edit `docs/my_document_name/00_doc_goal.md`

3. **Create outline**: Edit `docs/my_document_name/01_outline.md`

4. **Add facts** (if needed): Edit `docs/my_document_name/02_key_facts.md`

5. **Work through the pipeline**: Follow `universal/agents.md` for the standard pipeline

6. **Compile**: The final draft lives at `docs/my_document_name/05_draft.md`

### First-Time Setup

If this is a new project and `universal/` files are empty or missing:

1. Run the initialization interview (agents will prompt you, or see `universal/skills/project_init.md`)
2. Populate the `universal/` directory files:
   - `00_project_goal.md`
   - `01_audience.md`
   - `02_voice_tone_style.md`
   - `03_writing_guidelines.md`
   - `04_characters.md` (if applicable)

## Repository Structure

```
writing-workspace-template/
├── README.md
├── LICENSE
├── .gitignore
│
├── universal/
│   ├── agents.md
│   ├── 00_project_goal.md
│   ├── 01_audience.md
│   ├── 02_voice_tone_style.md
│   ├── 03_writing_guidelines.md
│   ├── 04_characters.md
│   ├── 05_glossary.md
│   ├── 06_sources_policy.md
│   └── skills/
│       ├── README.md
│       ├── project_init.md
│       ├── outline.md
│       ├── facts.md
│       ├── dialogue.md
│       ├── drafting.md
│       ├── voice_tone.md
│       ├── editing.md
│       └── critique.md
│
├── docs/
│   └── _TEMPLATE_DOC/
│       ├── agent_brief.md
│       ├── 00_doc_goal.md
│       ├── 01_outline.md
│       ├── 02_key_facts.md
│       ├── 03_dialogue.md
│       ├── 04_snippets.md
│       ├── 05_draft.md
│       └── 06_review_notes.md
│
├── compiler/
│   ├── agent_build.md
│   ├── 01_output_spec.md
│   └── build_prompt.md
│
└── meta/
    ├── project_state.md
    └── changelog.md
```

## Agent Behavior

### Initialization Interview

**Trigger**: `universal/` files missing/placeholder OR `meta/project_state.md` shows `initialized: false`

**Process**: Agent asks questions in 3-5 question batches (from `universal/skills/project_init.md`)

**Output**: Writes universal context docs from answers, records assumptions in `meta/changelog.md`, sets `meta/project_state.md` → `initialized: true`

### Per-Document Pipeline

Standard agent pipeline (from `universal/agents.md` and `compiler/agent_build.md`):

1. Ensure `00_doc_goal.md` exists
2. Create/repair `01_outline.md`
3. Create/repair `02_key_facts.md` if needed
4. Create/repair `03_dialogue.md` (default: yes)
5. Harvest/update `04_snippets.md` (optional)
6. Compile into `05_draft.md`
7. Write `06_review_notes.md` with prioritized edits

## Conventions

### Facts Policy

- **Never invent facts, stats, quotes, or attributions**
- If facts are missing: mark TODO + proceed with qualitative phrasing
- All facts must have sources or be marked TODO
- See `universal/06_sources_policy.md` for citation style

### TODOs

- Mark missing facts as TODO in `02_key_facts.md`
- Record assumptions in `meta/changelog.md`
- Document blockers in `docs/<DOC>/agent_brief.md`

### Precedence Rules

Context precedence (highest → lowest):

1. Explicit human instruction in current session
2. `docs/<DOC>/...` files (document-specific)
3. `universal/...` files (project-wide)
4. Defaults in `universal/agents.md`

### Hard Constraints

- Never fabricate facts, stats, quotes, or attributions
- If something is uncertain, mark it as TODO or phrase it qualitatively
- Keep artifacts small and composable
- Don't dump a whole draft into every file
- Prefer editing existing files over creating new ones

## Key File Locations

| File | Purpose |
|------|---------|
| `universal/agents.md` | Agent workflow contract and instructions |
| `docs/<DOC>/05_draft.md` | ⭐ **Final compiled doc** for each document |
| `compiler/01_output_spec.md` | Output format specification |
| `meta/project_state.md` | Project initialization status |
| `docs/_TEMPLATE_DOC/` | Template for creating new documents |

## Usage

### Creating a New Document

```bash
cp -R docs/_TEMPLATE_DOC docs/my_document_name
```

Then edit the files in `docs/my_document_name/` following the pipeline.

### Agent Workflow

Agents should:
1. Read `universal/agents.md` for workflow instructions
2. Check `meta/project_state.md` - if not initialized, run initialization interview
3. For each document, follow the standard pipeline
4. Compile final draft to `docs/<DOC>/05_draft.md`

## GitHub Template Setup

This repository is designed to be used as a GitHub Template Repository.

### Setting Up as Template

1. Create repository on GitHub
2. Push this code
3. In repository settings, enable "Template repository"

### Using the Template

**Via GitHub UI**: Click "Use this template" → Create new repository

**Via GitHub CLI**:
```bash
gh repo create my-writing-project --template ORG/writing-workspace-template --private
cd my-writing-project
```

**Via Git Clone**:
```bash
git clone https://github.com/ORG/writing-workspace-template my-project
cd my-project
rm -rf .git
git init
git add .
git commit -m "Initialize writing workspace"
```

## License

See [LICENSE](LICENSE) file for details.
