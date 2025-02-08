import os
import re
import requests

TODO_URL = os.getenv("TODO_URL")
TODO_KEY = os.getenv("TODO_KEY")
GITHUB_REPO = os.getenv("GITHUB_REPO")
GITHUB_SHA = os.getenv("GITHUB_SHA")

SUPABASE_TABLE = "github_todo"
SUPABASE_HEADERS = {
    "apikey": TODO_KEY,
    "Authorization": f"Bearer {TODO_KEY}",
    "Content-Type": "application/json"
}

def parse_issue_line(line):
    print(f"Parsing line: {line.strip()}")
    
    # Updated regex to capture time estimates in format: 0.4-1.5
    match = re.search(r'([^:]+):(\d+):(?:[/#\s]*)(TODO|BUG|FIX|NEW):([1-5]):(\d*\.?\d+-\d*\.?\d+):(.+)$', line.strip())
    
    if not match:
        print(f"No match found for line: {line.strip()}")
        return None

    file_path, line_number, issue_type, priority, time_estimate, text = match.groups()
    
    # Clean up the text
    text = text.strip()
    # Remove any comment markers
    text = re.sub(r'^[/#\s]*', '', text)
    
    # Split on first comma if it exists
    parts = text.split(",", 1)
    title = parts[0].strip()
    description = parts[1].strip() if len(parts) > 1 else ""

    # Parse time estimates
    estimate_min, estimate_max = map(float, time_estimate.split('-'))

    issue = {
        "type": issue_type,
        "priority": int(priority),
        "title": title,
        "description": description,
        "file": file_path,
        "line": int(line_number),
        "link": f"https://github.com/{GITHUB_REPO}/blob/{GITHUB_SHA}/{file_path}#L{line_number}",
        "category": GITHUB_REPO.split("/")[-1],
        "created_at": None,
        "estimate_min": estimate_min,
        "estimate_max": estimate_max
    }
    
    print(f"Successfully parsed issue: {issue}")
    return issue

def upload_to_supabase(issues):
    if not issues:
        print("No issues to upload.")
        return
    
    print(f"Attempting to upload {len(issues)} issues to Supabase")
    
    try:
        response = requests.post(
            f"{TODO_URL}/rest/v1/{SUPABASE_TABLE}",
            headers=SUPABASE_HEADERS,
            json=issues
        )

        print(f"Response status: {response.status_code}")
        print(f"Response body: {response.text}")

        if response.status_code in [200, 201]:
            print(f"Successfully uploaded {len(issues)} issues to Supabase.")
        else:
            print(f"Failed to upload: Status {response.status_code}")
            print(f"Response: {response.text}")
            raise Exception("Upload failed")
            
    except Exception as e:
        print(f"Error uploading to Supabase: {str(e)}")
        raise

def fetch_existing_todos(category):
    print(f"Fetching existing todos for category: {category}")
    try:
        response = requests.get(
            f"{TODO_URL}/rest/v1/{SUPABASE_TABLE}",
            headers=SUPABASE_HEADERS,
            params={
                "select": "*",
                "category": f"eq.{category}"
            }
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            print(f"Failed to fetch existing todos: Status {response.status_code}")
            print(f"Response: {response.text}")
            return []
    except Exception as e:
        print(f"Error fetching existing todos: {str(e)}")
        return []

def delete_removed_todos(existing_todos, new_todo_links):
    todos_to_delete = [todo for todo in existing_todos if todo['link'] not in new_todo_links]
    
    if not todos_to_delete:
        print("No todos to delete")
        return
        
    print(f"Deleting {len(todos_to_delete)} old todos")
    
    try:
        links_to_delete = [todo['link'] for todo in todos_to_delete]
        response = requests.delete(
            f"{TODO_URL}/rest/v1/{SUPABASE_TABLE}",
            headers=SUPABASE_HEADERS,
            params={"link": f"in.({','.join(links_to_delete)})"}
        )
        
        if response.status_code == 200:
            print(f"Successfully deleted {len(todos_to_delete)} old todos")
        else:
            print(f"Failed to delete old todos: Status {response.status_code}")
            print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error deleting old todos: {str(e)}")
        raise

def filter_existing_todos(new_todos, existing_todos):
    existing_links = {todo['link'] for todo in existing_todos}
    return [todo for todo in new_todos if todo['link'] not in existing_links]

def main():
    issues = []
    with open("results/issues.txt") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
                
            issue = parse_issue_line(line)
            if issue:
                issues.append(issue)
                print(f"Added issue: {issue}")
            else:
                print(f"Failed to parse line: {line}")

    print(f"Found {len(issues)} issues")
    
    # Get current category
    category = GITHUB_REPO.split("/")[-1]
    
    # Fetch existing todos
    existing_todos = fetch_existing_todos(category)
    print(f"Found {len(existing_todos)} existing todos")
    
    # Delete todos that no longer exist
    new_todo_links = {issue['link'] for issue in issues}
    delete_removed_todos(existing_todos, new_todo_links)
    
    # Filter out todos that already exist
    new_todos = filter_existing_todos(issues, existing_todos)
    print(f"Found {len(new_todos)} new todos to upload")
    
    # Upload new todos
    if new_todos:
        upload_to_supabase(new_todos)

if __name__ == "__main__":
    main()
