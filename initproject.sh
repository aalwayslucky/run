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

# Check if git repository already exists and has a remote
REPO_EXISTS=false
if git remote get-url origin &> /dev/null; then
    echo "Repository already exists and has a remote configured."
    echo "Proceeding with workflow files and secrets update..."
    REPO_EXISTS=true
else
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

    # Create GitHub Actions workflow directory if they don't exist
    mkdir -p .github/workflows
    mkdir -p .github/scripts
    echo "Created necessary directories"

    # Download and update workflow files
    echo "----------------------------------------"
    echo "Downloading latest workflow files..."

    # Create a temporary directory
    temp_dir=$(mktemp -d)
    
    # Clone the repository
    echo "Cloning template repository..."
    if ! git clone --depth 1 git@github.com:aalwayslucky/run.git "$temp_dir"; then
        echo "Failed to clone template repository"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Copy the workflow files
    echo "Copying workflow files..."
    mkdir -p .github/workflows .github/scripts
    cp "$temp_dir/.github/workflows/todo_list.yaml" .github/workflows/
    cp "$temp_dir/.github/scripts/upload_todos.py" .github/scripts/

    # Cleanup
    rm -rf "$temp_dir"
    
    # Make the Python script executable
    chmod +x .github/scripts/upload_todos.py
    echo "✓ Successfully updated workflow files"

    # Commit and push the changes
    if [ -n "$(git status --porcelain)" ]; then
        echo "----------------------------------------"
        echo "Committing and pushing changes..."
        git add .github/workflows/todo_list.yaml .github/scripts/upload_todos.py
        git commit -m "Update workflow files"
        git push
        echo "✓ Changes pushed to repository"
    fi

    if [ "$REPO_EXISTS" = false ]; then
        # Ask for repository visibility and continue with repository creation
        echo "Creating new repository..."
        # Create repository on GitHub and push
        gh repo create "$repo_name" --"$visibility" --source=. --remote=origin --push || {
            echo "Failed to create repository. Check if it already exists or if you have correct permissions."
            exit 1
        }
    fi

    # Set up GitHub secrets from local environment
    echo "----------------------------------------"
    echo "Setting up GitHub secrets..."
    if [ -z "$TODO_URL" ] || [ -z "$TODO_KEY" ]; then
        echo "Warning: TODO_URL or TODO_KEY environment variables not found."
        echo "Please set them in your environment and then run:"
        echo "gh secret set TODO_URL --body \"\$TODO_URL\""
        echo "gh secret set TODO_KEY --body \"\$TODO_KEY\""
    else
        echo "Setting TODO_URL secret..."
        gh secret set TODO_URL --body "$TODO_URL"
        echo "Setting TODO_KEY secret..."
        gh secret set TODO_KEY --body "$TODO_KEY"
    fi

    echo "Repository setup complete!"
fi