# Project Review: Writing Project Template System

## Executive Summary

This is a **reusable project template system** designed to help projects generate comprehensive documentation through an interview-based onboarding process. The template itself should be clean, generic, and free of project-specific tool dependencies.

## Current Issues Identified

### 1. Beads/bd Conflict

**Problem**: The project contains beads/bd (an issue tracking tool) references that conflict with the template's purpose:

- `AGENTS.md` contains beads-specific workflow instructions
- `PROJECT_SCOPING.md` mentions beads as a feature
- `.beads/` directory exists in the repository
- Workspace rules enforce beads workflow

**Why This is a Problem**:
- This is a **template project**, not a project that needs beads for its own development
- Beads is a specific tool choice, not a universal requirement
- Template projects should be clean and generic
- Users of this template may not want or need beads
- The beads instructions in `AGENTS.md` are specific to projects that USE beads, not to this template

## How This Project Should Work

### Project Purpose

This is a **template system** that provides:

1. **Interview-based onboarding**: Automated interview process to gather project context
2. **Universal context documentation**: Structured documentation generation
3. **Reusable template structure**: Clean, generic structure that can be forked/cloned
4. **GitHub-ready**: Easy setup for new projects

### Core Workflow

#### For Template Maintainers (This Project)

1. **Development**: Maintain and improve the template itself
   - Update interview scripts
   - Improve documentation templates
   - Enhance setup scripts
   - Test the template workflow

2. **No Project-Specific Tools Required**: The template should not mandate specific tools like beads, GitHub issues, Jira, etc. It should remain generic.

#### For Users of This Template

1. **Clone/Use Template**: Get the template from GitHub
2. **Run Setup**: Execute `./setup.sh`
3. **Complete Interview**: Answer questions to generate context
4. **Customize**: Add their own tools, workflows, and project-specific files
5. **Use Their Own Tools**: They can use beads, GitHub issues, Jira, or any other tool they prefer

### Key Files and Their Roles

#### `AGENTS.md`
**Should contain**: Generic agent instructions for working on THIS template project, OR be a template/placeholder that users customize for their own projects.

**Should NOT contain**: Specific tool dependencies like beads/bd that aren't relevant to the template itself.

**Recommended content**:
- Instructions for agents working on the template project itself
- OR a placeholder/template that users customize
- Reference to `docs/universal_context.md` for project context
- Generic workflow guidelines

#### `PROJECT_SCOPING.md`
**Should contain**: Complete scoping document for THIS template project.

**Should NOT contain**: References to optional tools like beads that aren't core to the template.

#### `README.md`
**Status**: ✅ Correct - generic template overview

#### `docs/universal_context.md`
**Status**: ✅ Correct - generated context document (currently has test data)

#### `.beads/` directory
**Issue**: This directory exists but isn't needed for the template itself.

**Recommendation**: Add to `.gitignore` if keeping for local development, OR remove if not needed.

### Recommended Cleanup Actions

1. **Clean `AGENTS.md`**: Remove beads references, make it generic/template-appropriate
2. **Clean `PROJECT_SCOPING.md`**: Remove beads reference from feature list
3. **Update `.gitignore`**: Add `.beads/` to keep template repository clean
4. **Document intent**: Ensure all files reflect that this is a template, not a beads-dependent project

## Project Structure (Intended)

```
.
├── README.md                    # Template overview
├── AGENTS.md                    # Generic agent instructions (no tool dependencies)
├── SCOPE.md                     # Template scope (placeholder)
├── PROJECT_SCOPING.md           # Template project scoping document
├── QUICK_START.md               # Quick start guide
├── setup.sh                     # Setup script
├── .gitignore                   # Git ignore (should include .beads/)
│
├── interview/                   # Interview system
│   ├── onboarding.md           # Interview questions template
│   └── interview_script.sh     # Interview runner
│
├── docs/                        # Generated/documentation
│   ├── universal_context.md    # Generated context (test data currently)
│   ├── project_scope.md        # Scope template
│   └── setup_guide.md          # GitHub setup guide
│
└── templates/                   # Templates
    ├── context_template.md     # Universal context template
    └── project_structure.md    # Structure template
```

## Principles for This Template

1. **Generic and Clean**: No mandatory tool dependencies
2. **Reusable**: Can be forked/cloned without baggage
3. **Customizable**: Users add their own tools and workflows
4. **Self-Contained**: All necessary files included
5. **Clear Intent**: Documentation makes it clear this is a template

## Next Steps

1. ✅ Review completed
2. ⏳ Clean up `AGENTS.md`
3. ⏳ Clean up `PROJECT_SCOPING.md`
4. ⏳ Update `.gitignore`
5. ⏳ Verify project is clean and generic

---

**Review Date**: 2026-01-03
**Status**: Issues identified, cleanup ready to proceed

