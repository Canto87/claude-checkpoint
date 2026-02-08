List all checkpoint files for the current branch.

Steps:
1. Detect the current git branch
2. List all `checkpoint-{branch}-*.md` files in the `memory/` directory (the auto-memory directory for this project)
3. For each file, show: filename, last modified date, and first few lines (summary)
4. Sort by most recent first
5. Present the results in a table format to the user
