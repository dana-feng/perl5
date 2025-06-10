# Task Manager System

## Setup Instructions

1. **Install Required Perl Modules:**
   ```bash
   cpan install JSON File::Slurp DateTime List::Util
   ```

2. **Make the script executable:**
   ```bash
   chmod +x task_manager.pl
   ```

3. **Test the basic functionality:**
   ```bash
   # Add some sample tasks
   ./task_manager.pl add "Fix login bug" "Users can't log in with special characters"
   ./task_manager.pl add "Update documentation" "API docs need updating"
   ./task_manager.pl add "Code review" "Review pull request #123"
   
   # List all tasks
   ./task_manager.pl list
   
   # Show task details
   ./task_manager.pl show task_1234567890
   ```

## Current System Overview

The task manager has three main components:

- **TaskManager::Task** - Represents individual tasks with properties like ID, title, status, priority, tags, etc.
- **TaskManager::Storage** - Handles persistence to/from JSON files
- **TaskManager::CLI** - Command-line interface for user interactions

### Current Features:
- Add tasks with title and description
- List all tasks or filter by status
- Show detailed task information
- Update individual task fields
- Mark tasks as completed
- Delete tasks
- Interactive and command-line modes

## 🎯 FEATURE REQUEST: Task Search Functionality

**Your task is to implement a search feature that allows users to find tasks based on various criteria.**

### Requirements:

1. **Add a new CLI command called `search`**
   - Should accept search terms as arguments
   - Usage: `./task_manager.pl search <search_terms>`

2. **Search should work across multiple fields:**
   - Task title (case-insensitive)
   - Task description (case-insensitive)
   - Tags (exact match)
   - Assigned user (if assigned)

3. **Support for search options:**
   - `--field <fieldname>` - Search only in specific field (title, description, tags, assigned_to)
   - `--status <status>` - Only search within tasks of specific status
   - `--priority <priority>` - Only search within tasks of specific priority

4. **Display results:**
   - Use the same format as the `list` command
   - Show "No tasks found matching criteria" if no results
   - Sort results by relevance (exact matches first, then partial matches)

### Example Usage:
```bash
# Basic search
./task_manager.pl search "login"

# Search only in titles
./task_manager.pl search --field title "bug"

# Search in completed tasks only
./task_manager.pl search --status completed "documentation"

# Search for tasks assigned to specific user
./task_manager.pl search --field assigned_to "john"
```

### Testing Your Implementation:
After implementing, test with:
```bash
# Add some test data first
./task_manager.pl add "Fix login bug" "Users can't log in with special characters"
./task_manager.pl add "Update API documentation" "REST API docs need updating"
./task_manager.pl update task_xxx assigned_to "alice"
./task_manager.pl update task_yyy status "completed"

# Then test your search
./task_manager.pl search "login"
./task_manager.pl search --field description "API"
./task_manager.pl search --status completed "documentation"
```
