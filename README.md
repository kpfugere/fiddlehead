# Project Template System

A reusable project template system that uses an interview-based onboarding process to gather universal context and generate comprehensive project documentation.

## Overview

This template provides:
- **Interview-based onboarding**: Automated interview process to gather project context
- **Universal context documentation**: Structured documentation of project requirements, goals, and constraints
- **Compiled documentation**: Final consolidated documentation in a standardized location
- **GitHub-ready**: Easy setup and installation for new projects

## Project Structure

```
.
├── README.md                    # This file
├── AGENTS.md                    # Agent instructions and workflows
├── SCOPE.md                     # Project scoping document
├── setup.sh                     # Automated setup script
├── interview/                   # Interview scripts and templates
│   ├── onboarding.md           # Interview questions template
│   └── interview_script.sh     # Automated interview runner
├── docs/                        # Generated documentation
│   ├── universal_context.md     # Compiled universal context
│   ├── project_scope.md         # Final project scope
│   └── setup_guide.md           # Setup instructions
└── templates/                   # Reusable templates
    ├── project_structure.md     # Standard project structure template
    └── context_template.md      # Universal context template
```

## Quick Start

### For New Projects

1. **Run the setup script**:
   ```bash
   ./setup.sh
   ```

2. **Complete the interview**:
   The setup script will guide you through an interview process to gather:
   - Project goals and objectives
   - Technical requirements
   - Constraints and limitations
   - Team structure
   - Timeline and milestones

3. **Review generated docs**:
   - `docs/universal_context.md` - Complete project context
   - `docs/project_scope.md` - Final scoping document
   - `SCOPE.md` - Project scope summary

### Installation from GitHub

See [GitHub Setup Instructions](docs/setup_guide.md) for detailed installation steps.

## Documentation Locations

- **Final Compiled Doc**: `docs/universal_context.md`
- **Project Scope**: `SCOPE.md` and `docs/project_scope.md`
- **Agent Instructions**: `AGENTS.md`
- **Setup Guide**: `docs/setup_guide.md`

## Usage

After setup, agents working on this project will:
1. Read `AGENTS.md` for workflow instructions
2. Reference `docs/universal_context.md` for project context
3. Use `SCOPE.md` for project boundaries and requirements

## Contributing

This is a template project. To use it:
1. Clone or fork this repository
2. Run `./setup.sh` to initialize your project
3. Complete the interview process
4. Start building!

