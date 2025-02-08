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