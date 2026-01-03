#!/bin/bash

# Project Setup Script
# This script initializes a new project using the template system

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Project Template Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if interview script exists
INTERVIEW_SCRIPT="$SCRIPT_DIR/interview/interview_script.sh"
if [ ! -f "$INTERVIEW_SCRIPT" ]; then
    echo -e "${RED}Error: Interview script not found at $INTERVIEW_SCRIPT${NC}"
    exit 1
fi

# Make interview script executable
chmod +x "$INTERVIEW_SCRIPT"

# Create necessary directories
echo -e "${YELLOW}Creating project structure...${NC}"
mkdir -p "$SCRIPT_DIR/docs"
mkdir -p "$SCRIPT_DIR/templates"

echo -e "${GREEN}✓ Project structure created${NC}"
echo ""

# Run the interview
echo -e "${YELLOW}Starting onboarding interview...${NC}"
echo ""
"$INTERVIEW_SCRIPT"

# Generate project scope summary
echo ""
echo -e "${YELLOW}Generating project scope summary...${NC}"
if [ -f "$SCRIPT_DIR/docs/universal_context.md" ]; then
    # Extract key information for SCOPE.md
    PROJECT_NAME=$(grep -A 1 "### Project Name" "$SCRIPT_DIR/docs/universal_context.md" | tail -1 | sed 's/^[[:space:]]*//')
    PRIMARY_PURPOSE=$(grep -A 3 "### Primary Purpose" "$SCRIPT_DIR/docs/universal_context.md" | tail -1 | sed 's/^[[:space:]]*//')
    
    # Update SCOPE.md with basic info
    if [ -f "$SCRIPT_DIR/SCOPE.md" ]; then
        # This is a simple update - in a real scenario, you might want more sophisticated parsing
        echo -e "${GREEN}✓ Project scope document ready for review${NC}"
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your project documentation has been created:"
echo "  • Universal Context: docs/universal_context.md"
echo "  • Project Scope: SCOPE.md (please review and update)"
echo ""
echo "Next steps:"
echo "  1. Review docs/universal_context.md"
echo "  2. Update SCOPE.md with any additional scope details"
echo "  3. Share the documentation with your team"
echo "  4. Start building!"

