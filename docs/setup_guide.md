# GitHub Setup and Installation Guide

This guide explains how to set up this project template on GitHub and how others can install and use it.

## Setting Up on GitHub

### Initial Setup

1. **Create a new repository on GitHub**:
   - Go to GitHub and create a new repository
   - Name it something like `project-template` or `universal-context-template`
   - Choose whether it should be public or private

2. **Initialize and push to GitHub**:
   ```bash
   git init
   git add .
   git commit -m "Initial commit: Project template system"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
   git push -u origin main
   ```

3. **Create a GitHub Template Repository** (Optional but Recommended):
   - Go to your repository settings on GitHub
   - Scroll to "Template repository" section
   - Check "Template repository"
   - This allows others to use "Use this template" button

### Repository Structure

Your GitHub repository should contain:
```
.
├── README.md
├── AGENTS.md
├── SCOPE.md
├── setup.sh
├── .gitignore
├── interview/
│   ├── onboarding.md
│   └── interview_script.sh
├── docs/
│   ├── setup_guide.md (this file)
│   └── (generated files after setup)
└── templates/
    ├── project_structure.md
    └── context_template.md
```

## Installation for New Users

### Method 1: Using GitHub Template (Recommended)

1. **Create a new repository from template**:
   - Go to the template repository on GitHub
   - Click "Use this template" button
   - Choose "Create a new repository"
   - Name your new project repository
   - Create the repository

2. **Clone your new repository**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/YOUR_NEW_REPO.git
   cd YOUR_NEW_REPO
   ```

3. **Run the setup script**:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

4. **Complete the interview**:
   - The script will guide you through the onboarding interview
   - Answer all questions to generate your universal context document

### Method 2: Clone and Customize

1. **Clone the repository**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/project-template.git
   cd project-template
   ```

2. **Remove git history** (if starting fresh):
   ```bash
   rm -rf .git
   git init
   ```

3. **Run setup**:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

4. **Initialize your own repository**:
   ```bash
   git add .
   git commit -m "Initial project setup"
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_PROJECT.git
   git push -u origin main
   ```

### Method 3: Download as ZIP

1. **Download the template**:
   - Go to the repository on GitHub
   - Click "Code" → "Download ZIP"
   - Extract the ZIP file

2. **Navigate to the directory**:
   ```bash
   cd project-template-main
   ```

3. **Run setup**:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

## Post-Installation

After running the setup script:

1. **Review generated documentation**:
   - Check `docs/universal_context.md` for completeness
   - Update `SCOPE.md` with any additional scope details

2. **Customize for your project**:
   - Update `README.md` with project-specific information
   - Modify `AGENTS.md` if you have specific agent workflows
   - Add project-specific files and directories

3. **Share with your team**:
   - Commit and push the generated documentation
   - Ensure team members have access to the repository
   - Point them to `docs/universal_context.md` for project context

## File Structure After Setup

After running setup, your project will have:

```
.
├── README.md                    # Project overview
├── AGENTS.md                    # Agent instructions
├── SCOPE.md                     # Project scope (updated)
├── setup.sh                     # Setup script
├── interview/
│   ├── onboarding.md           # Interview questions
│   └── interview_script.sh     # Interview runner
├── docs/
│   ├── universal_context.md    # ⭐ Final compiled doc (main reference)
│   ├── project_scope.md        # Detailed scope (if generated)
│   └── setup_guide.md          # This file
└── templates/
    ├── project_structure.md    # Structure template
    └── context_template.md     # Context template
```

## Key Documentation Locations

- **Final Compiled Doc**: `docs/universal_context.md` ⭐
  - This is the primary reference document for all agents
  - Contains all project context gathered during interview
  - Should be updated as the project evolves

- **Project Scope**: `SCOPE.md`
  - High-level project scope summary
  - Quick reference for project boundaries

- **Agent Instructions**: `AGENTS.md`
  - Workflow instructions for AI agents
  - Task tracking and completion guidelines

## Troubleshooting

### Setup script not executable
```bash
chmod +x setup.sh
chmod +x interview/interview_script.sh
```

### Interview script fails
- Ensure you're using bash (not zsh or other shells)
- Check that all template files exist in `templates/` directory
- Verify file permissions

### Documentation not generated
- Check that `docs/` directory exists and is writable
- Review interview script output for errors
- Manually check `docs/universal_context.md` if needed

## Contributing Back

If you improve this template:

1. Fork the original template repository
2. Make your improvements
3. Submit a pull request with:
   - Description of changes
   - Why the change improves the template
   - Any updated documentation

## Support

For issues or questions:
- Open an issue on the GitHub repository
- Check existing issues for solutions
- Review the documentation in `docs/` directory

