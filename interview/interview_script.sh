#!/bin/bash

# Interview Script for Project Onboarding
# This script conducts an interactive interview to gather universal context

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/docs"
TEMPLATES_DIR="$PROJECT_ROOT/templates"

# Create docs directory if it doesn't exist
mkdir -p "$DOCS_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Project Onboarding Interview${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "This interview will gather information to create your project's universal context document."
echo "Press Enter to continue..."
read

# Initialize output file
OUTPUT_FILE="$DOCS_DIR/universal_context.md"
cp "$TEMPLATES_DIR/context_template.md" "$OUTPUT_FILE"

# Function to ask question and save answer
ask_question() {
    local question="$1"
    local field="$2"
    local answer
    
    echo -e "${YELLOW}$question${NC}"
    read -r answer
    
    # Replace placeholder in template
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|\[$field\]|$answer|g" "$OUTPUT_FILE"
    else
        # Linux
        sed -i "s|\[$field\]|$answer|g" "$OUTPUT_FILE"
    fi
}

# Function to ask multi-line question
ask_multiline() {
    local question="$1"
    local field="$2"
    local answer
    local temp_file=$(mktemp)
    
    echo -e "${YELLOW}$question${NC}"
    echo "(Enter your answer, then press Ctrl+D (Mac/Linux) or Ctrl+Z (Windows) when done)"
    cat > "$temp_file"
    answer=$(cat "$temp_file")
    rm "$temp_file"
    
    # Escape special characters for sed
    answer=$(echo "$answer" | sed 's/[[\.*^$()+?{|]/\\&/g')
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|\[$field\]|$answer|g" "$OUTPUT_FILE"
    else
        sed -i "s|\[$field\]|$answer|g" "$OUTPUT_FILE"
    fi
}

# Replace date
DATE=$(date +"%Y-%m-%d")
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|\[DATE\]|$DATE|g" "$OUTPUT_FILE"
else
    sed -i "s|\[DATE\]|$DATE|g" "$OUTPUT_FILE"
fi

echo -e "${GREEN}=== Project Basics ===${NC}"
ask_question "1. What is the name of this project?" "PROJECT_NAME"
ask_question "2. What type of project is this? (e.g., web app, CLI tool, library, API)" "PROJECT_TYPE"
ask_multiline "3. What is the main problem this project solves?" "PRIMARY_PURPOSE"

echo ""
echo -e "${GREEN}=== Goals and Objectives ===${NC}"
ask_multiline "4. What are the top 3-5 primary goals for this project?" "GOAL_1"
ask_multiline "5. How will you measure success?" "METRIC_1"
ask_question "6. Who is the intended audience or user base?" "TARGET_USERS"

echo ""
echo -e "${GREEN}=== Technical Context ===${NC}"
ask_question "7. What technologies, languages, frameworks will be used?" "LANGUAGES"
ask_question "8. What frameworks or libraries?" "FRAMEWORKS"
ask_question "9. What tools?" "TOOLS"
ask_question "10. What infrastructure?" "INFRASTRUCTURE"
ask_multiline "11. What is the high-level architecture or system design?" "ARCHITECTURE_DESCRIPTION"
ask_question "12. What external services, APIs, or dependencies are required?" "DEPENDENCY_1"
ask_question "13. What platforms must this support? (OS, browsers, devices)" "PLATFORM_1"

echo ""
echo -e "${GREEN}=== Constraints and Limitations ===${NC}"
ask_question "14. What are the key deadlines or timeline requirements?" "TIME_CONSTRAINTS"
ask_question "15. What are budget, team size, or resource limitations?" "RESOURCE_CONSTRAINTS"
ask_question "16. Are there any technical limitations or requirements?" "TECHNICAL_CONSTRAINTS"
ask_question "17. Any regulatory, security, or compliance needs?" "COMPLIANCE_REQUIREMENTS"

echo ""
echo -e "${GREEN}=== Team and Process ===${NC}"
ask_question "18. Who is on the team and what are their roles?" "TEAM_STRUCTURE"
ask_question "19. How does the team communicate and collaborate?" "COMMUNICATION_METHODS"
ask_question "20. What development methodology is used? (Agile, Waterfall, etc.)" "DEVELOPMENT_PROCESS"
ask_question "21. What tools are used for development, testing, deployment?" "TOOLS_AND_WORKFLOWS"

echo ""
echo -e "${GREEN}=== Documentation and Knowledge ===${NC}"
ask_question "22. What documentation already exists?" "EXISTING_DOCUMENTATION"
ask_question "23. Where can agents find project knowledge? (docs, wikis, code comments)" "KNOWLEDGE_SOURCES"
ask_question "24. How are important decisions documented?" "DECISION_LOG_LOCATION"

echo ""
echo -e "${GREEN}=== Future Considerations ===${NC}"
ask_question "25. What features are planned for future releases?" "PLANNED_FEATURES"
ask_question "26. What are the expected scale requirements?" "SCALABILITY_REQUIREMENTS"
ask_question "27. What are the long-term maintenance expectations?" "MAINTENANCE_EXPECTATIONS"

echo ""
ask_multiline "28. Any other important context, requirements, or considerations?" "ADDITIONAL_CONTEXT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Interview Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Universal context document created at: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "1. Review the generated document at $OUTPUT_FILE"
echo "2. Update SCOPE.md with project scope summary"
echo "3. Share docs/universal_context.md with your team"

