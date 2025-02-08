#!/bin/bash

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) is not installed. Please install it first."
    exit 1
fi

# Check if gh is authenticated
if ! gh auth status &> /dev/null; then
    echo "Please login to GitHub first using: gh auth login"
    exit 1
fi

# Ask for repository visibility
while true; do
    read -p "Do you want to create a private repository? (y/n): " visibility
    case $visibility in
        [Yy]* ) visibility="private"; break;;
        [Nn]* ) visibility="public"; break;;
        * ) echo "Please answer y or n.";;
    esac
done

# Ask for repository name
read -p "Enter repository name: " repo_name

# Initialize git if not already initialized
if [ ! -d .git ]; then
    git init
fi

# Create README.md if it doesn't exist
if [ ! -f README.md ]; then
    echo "# $repo_name" > README.md
    echo "Created README.md"
fi

# Create GitHub Actions workflow directory
mkdir -p .github/workflows
mkdir -p .github/scripts

# Download workflow and script files from public repository
echo "Downloading workflow and script files..."
if ! curl -o .github/workflows/todo_list.yaml https://raw.githubusercontent.com/aalwayslucky/run/main/.github/workflows/todo_list.yaml; then
    echo "Failed to download workflow file"
    exit 1
fi

if ! curl -o .github/scripts/upload_todos.py https://raw.githubusercontent.com/aalwayslucky/run/main/.github/scripts/upload_todos.py; then
    echo "Failed to download script file"
    exit 1
fi

# Make the Python script executable
chmod +x .github/scripts/upload_todos.py

# Add new files to git
git add .github/workflows/todo_list.yaml .github/scripts/upload_todos.py

# Add files and create initial commit
git add .
git commit -m "Initial commit"

# Create repository on GitHub and push
echo "Creating repository..."
gh repo create "$repo_name" --"$visibility" --source=. --remote=origin --push || {
    echo "Failed to create repository. Check if it already exists or if you have correct permissions."
    exit 1
}

echo "Repository setup complete!"