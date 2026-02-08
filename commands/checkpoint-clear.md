Clean up old checkpoint files for the current branch.

Steps:
1. Detect the current git branch
2. List all `checkpoint-{branch}-*.md` and `checkpoint-{branch}-*.changes` files in the `memory/` directory
3. Show the list to the user with last modified dates
4. Ask the user which ones to delete (or offer to delete all except the most recent one)
5. Delete only the files the user confirms (both `.md` and matching `.changes` files)
6. Report what was deleted
