#!/bin/bash
# Verification script for setup.sh output

PROJECT_NAME="day150-cloud-deployment"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/$PROJECT_NAME"

echo "Verifying setup.sh output..."
echo "Project directory: $PROJECT_DIR"
echo ""

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Project directory $PROJECT_NAME does not exist"
    exit 1
fi

# Expected files
declare -a expected_files=(
    "requirements.txt"
    "requirements-terraform.txt"
    "terraform/modules/aws/compute/main.tf"
    "terraform/modules/aws/storage/main.tf"
    "terraform/modules/aws/network/main.tf"
    "terraform/environments/dev/main.tf"
    "scripts/deploy.py"
    "web/app.py"
    "web/templates/dashboard.html"
    "tests/test_terraform_validation.py"
    "tests/test_cost_estimation.py"
    "docs/DEPLOYMENT_GUIDE.md"
    "Dockerfile"
    "docker-compose.yml"
    ".dockerignore"
    "start.sh"
    "stop.sh"
)

missing_files=0
for file in "${expected_files[@]}"; do
    full_path="$PROJECT_DIR/$file"
    if [ -f "$full_path" ]; then
        echo "✅ $file"
    else
        echo "❌ MISSING: $file"
        missing_files=$((missing_files + 1))
    fi
done

echo ""
if [ $missing_files -eq 0 ]; then
    echo "✅ All expected files are present!"
    exit 0
else
    echo "❌ $missing_files file(s) are missing"
    exit 1
fi
