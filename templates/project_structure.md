# Standard Project Structure Template

This template defines a standard project structure for projects using this template system.

## Recommended Structure

```
project-root/
├── README.md                    # Project overview and quick start
├── AGENTS.md                    # Agent instructions and workflows
├── SCOPE.md                     # Project scope document
├── LICENSE                      # License file
├── .gitignore                   # Git ignore rules
├── setup.sh                     # Project setup script
│
├── docs/                        # Documentation
│   ├── universal_context.md    # ⭐ Main compiled context document
│   ├── project_scope.md        # Detailed project scope
│   ├── setup_guide.md          # Setup instructions
│   ├── architecture.md         # Architecture documentation
│   └── api/                    # API documentation (if applicable)
│
├── interview/                   # Interview and onboarding
│   ├── onboarding.md           # Interview questions template
│   └── interview_script.sh     # Automated interview runner
│
├── templates/                   # Reusable templates
│   ├── project_structure.md    # This file
│   └── context_template.md     # Universal context template
│
├── src/                         # Source code (project-specific)
│   └── ...
│
├── tests/                       # Tests (project-specific)
│   └── ...
│
└── config/                      # Configuration files (project-specific)
    └── ...
```

## Key Directories

### `docs/`
**Purpose**: All project documentation lives here.

**Key Files**:
- `universal_context.md` - **The final compiled document** containing all project context
- `project_scope.md` - Detailed project scope and requirements
- `setup_guide.md` - Installation and setup instructions

### `interview/`
**Purpose**: Interview scripts and templates for gathering project context.

**Files**:
- `onboarding.md` - Question template for the interview
- `interview_script.sh` - Automated script to run the interview

### `templates/`
**Purpose**: Reusable templates for generating documentation.

**Files**:
- `context_template.md` - Template for universal context document
- `project_structure.md` - This structure template

## Documentation Hierarchy

1. **`docs/universal_context.md`** ⭐
   - Primary reference for all agents
   - Contains complete project context
   - Generated during onboarding interview
   - Should be kept up-to-date

2. **`SCOPE.md`**
   - High-level project scope
   - Quick reference for boundaries
   - Updated from universal context

3. **`AGENTS.md`**
   - Workflow instructions
   - Task tracking guidelines
   - Session completion procedures

4. **`README.md`**
   - Project overview
   - Quick start guide
   - Links to other documentation

## Customization

This structure is a template. Customize it based on your project needs:

- **Web Applications**: Add `public/`, `assets/`, `components/`
- **CLI Tools**: Add `bin/`, `commands/`
- **Libraries**: Add `lib/`, `examples/`
- **APIs**: Add `routes/`, `middleware/`, `models/`

The core `docs/`, `interview/`, and `templates/` directories should remain for the template system to function.

