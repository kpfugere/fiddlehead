#!/bin/bash

# Test script for setup - creates a demo universal context document
# This simulates the interview process with sample answers

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$SCRIPT_DIR/docs"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Setup Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create docs directory
mkdir -p "$DOCS_DIR"

# Copy template
OUTPUT_FILE="$DOCS_DIR/universal_context.md"
cp "$TEMPLATES_DIR/context_template.md" "$OUTPUT_FILE"

# Replace date
DATE=$(date +"%Y-%m-%d")
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|\[DATE\]|$DATE|g" "$OUTPUT_FILE"
else
    sed -i "s|\[DATE\]|$DATE|g" "$OUTPUT_FILE"
fi

# Sample answers for testing
echo -e "${YELLOW}Populating with sample test data...${NC}"

# Replace all placeholders with test data
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|\[PROJECT_NAME\]|Test Project|g" "$OUTPUT_FILE"
    sed -i '' "s|\[PROJECT_TYPE\]|Web Application|g" "$OUTPUT_FILE"
    sed -i '' "s|\[PRIMARY_PURPOSE\]|This is a test project to verify the template system works correctly.|g" "$OUTPUT_FILE"
    sed -i '' "s|\[GOAL_1\]|1. Test the interview script\n2. Verify documentation generation\n3. Ensure GitHub integration works|g" "$OUTPUT_FILE"
    sed -i '' "s|\[METRIC_1\]|Successful generation of universal_context.md|g" "$OUTPUT_FILE"
    sed -i '' "s|\[TARGET_USERS\]|Developers using this template|g" "$OUTPUT_FILE"
    sed -i '' "s|\[LANGUAGES\]|Bash, Markdown|g" "$OUTPUT_FILE"
    sed -i '' "s|\[FRAMEWORKS\]|None|g" "$OUTPUT_FILE"
    sed -i '' "s|\[TOOLS\]|Git, GitHub|g" "$OUTPUT_FILE"
    sed -i '' "s|\[INFRASTRUCTURE\]|GitHub repositories|g" "$OUTPUT_FILE"
    sed -i '' "s|\[ARCHITECTURE_DESCRIPTION\]|Template-based documentation system with interview-driven context gathering|g" "$OUTPUT_FILE"
    sed -i '' "s|\[DEPENDENCY_1\]|Git, GitHub account|g" "$OUTPUT_FILE"
    sed -i '' "s|\[PLATFORM_1\]|macOS, Linux|g" "$OUTPUT_FILE"
    sed -i '' "s|\[TIME_CONSTRAINTS\]|None for testing|g" "$OUTPUT_FILE"
    sed -i '' "s|\[RESOURCE_CONSTRAINTS\]|Minimal - bash and standard tools only|g" "$OUTPUT_FILE"
    sed -i '' "s|\[TECHNICAL_CONSTRAINTS\]|Must work on macOS and Linux|g" "$OUTPUT_FILE"
    sed -i '' "s|\[COMPLIANCE_REQUIREMENTS\]|None|g" "$OUTPUT_FILE"
    sed -i '' "s|\[TEAM_STRUCTURE\]|Single developer|g" "$OUTPUT_FILE"
    sed -i '' "s|\[COMMUNICATION_METHODS\]|GitHub issues and documentation|g" "$OUTPUT_FILE"
    sed -i '' "s|\[DEVELOPMENT_PROCESS\]|Agile/Iterative|g" "$OUTPUT_FILE"
    sed -i '' "s|\[TOOLS_AND_WORKFLOWS\]|Git, GitHub, bash scripts|g" "$OUTPUT_FILE"
    sed -i '' "s|\[EXISTING_DOCUMENTATION\]|README, AGENTS.md, templates|g" "$OUTPUT_FILE"
    sed -i '' "s|\[KNOWLEDGE_SOURCES\]|docs/universal_context.md|g" "$OUTPUT_FILE"
    sed -i '' "s|\[DECISION_LOG_LOCATION\]|PROJECT_SCOPING.md|g" "$OUTPUT_FILE"
    sed -i '' "s|\[PLANNED_FEATURES\]|Enhanced interview questions, web interface|g" "$OUTPUT_FILE"
    sed -i '' "s|\[SCALABILITY_REQUIREMENTS\]|Support multiple project types|g" "$OUTPUT_FILE"
    sed -i '' "s|\[MAINTENANCE_EXPECTATIONS\]|Community maintained|g" "$OUTPUT_FILE"
    sed -i '' "s|\[ADDITIONAL_CONTEXT\]|This is a test run to verify the system works.|g" "$OUTPUT_FILE"
else
    sed -i "s|\[PROJECT_NAME\]|Test Project|g" "$OUTPUT_FILE"
    sed -i "s|\[PROJECT_TYPE\]|Web Application|g" "$OUTPUT_FILE"
    sed -i "s|\[PRIMARY_PURPOSE\]|This is a test project to verify the template system works correctly.|g" "$OUTPUT_FILE"
    sed -i "s|\[GOAL_1\]|1. Test the interview script\n2. Verify documentation generation\n3. Ensure GitHub integration works|g" "$OUTPUT_FILE"
    sed -i "s|\[METRIC_1\]|Successful generation of universal_context.md|g" "$OUTPUT_FILE"
    sed -i "s|\[TARGET_USERS\]|Developers using this template|g" "$OUTPUT_FILE"
    sed -i "s|\[LANGUAGES\]|Bash, Markdown|g" "$OUTPUT_FILE"
    sed -i "s|\[FRAMEWORKS\]|None|g" "$OUTPUT_FILE"
    sed -i "s|\[TOOLS\]|Git, GitHub|g" "$OUTPUT_FILE"
    sed -i "s|\[INFRASTRUCTURE\]|GitHub repositories|g" "$OUTPUT_FILE"
    sed -i "s|\[ARCHITECTURE_DESCRIPTION\]|Template-based documentation system with interview-driven context gathering|g" "$OUTPUT_FILE"
    sed -i "s|\[DEPENDENCY_1\]|Git, GitHub account|g" "$OUTPUT_FILE"
    sed -i "s|\[PLATFORM_1\]|macOS, Linux|g" "$OUTPUT_FILE"
    sed -i "s|\[TIME_CONSTRAINTS\]|None for testing|g" "$OUTPUT_FILE"
    sed -i "s|\[RESOURCE_CONSTRAINTS\]|Minimal - bash and standard tools only|g" "$OUTPUT_FILE"
    sed -i "s|\[TECHNICAL_CONSTRAINTS\]|Must work on macOS and Linux|g" "$OUTPUT_FILE"
    sed -i "s|\[COMPLIANCE_REQUIREMENTS\]|None|g" "$OUTPUT_FILE"
    sed -i "s|\[TEAM_STRUCTURE\]|Single developer|g" "$OUTPUT_FILE"
    sed -i "s|\[COMMUNICATION_METHODS\]|GitHub issues and documentation|g" "$OUTPUT_FILE"
    sed -i "s|\[DEVELOPMENT_PROCESS\]|Agile/Iterative|g" "$OUTPUT_FILE"
    sed -i "s|\[TOOLS_AND_WORKFLOWS\]|Git, GitHub, bash scripts|g" "$OUTPUT_FILE"
    sed -i "s|\[EXISTING_DOCUMENTATION\]|README, AGENTS.md, templates|g" "$OUTPUT_FILE"
    sed -i "s|\[KNOWLEDGE_SOURCES\]|docs/universal_context.md|g" "$OUTPUT_FILE"
    sed -i "s|\[DECISION_LOG_LOCATION\]|PROJECT_SCOPING.md|g" "$OUTPUT_FILE"
    sed -i "s|\[PLANNED_FEATURES\]|Enhanced interview questions, web interface|g" "$OUTPUT_FILE"
    sed -i "s|\[SCALABILITY_REQUIREMENTS\]|Support multiple project types|g" "$OUTPUT_FILE"
    sed -i "s|\[MAINTENANCE_EXPECTATIONS\]|Community maintained|g" "$OUTPUT_FILE"
    sed -i "s|\[ADDITIONAL_CONTEXT\]|This is a test run to verify the system works.|g" "$OUTPUT_FILE"
fi

echo -e "${GREEN}✓ Test universal context document created${NC}"
echo ""
echo "Test document location: $OUTPUT_FILE"
echo ""
echo -e "${BLUE}Verifying file was created...${NC}"
if [ -f "$OUTPUT_FILE" ]; then
    echo -e "${GREEN}✓ File exists${NC}"
    echo ""
    echo "First few lines of generated document:"
    head -20 "$OUTPUT_FILE"
    echo ""
    echo -e "${GREEN}Test completed successfully!${NC}"
else
    echo -e "${RED}✗ File was not created${NC}"
    exit 1
fi

