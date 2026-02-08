Save a checkpoint of the current work state now.

Write to your session's checkpoint file (the path shown at session start: `memory/checkpoint-{branch}-{pid}.md`). Create the file if it doesn't exist.

Required fields:
- **Last Updated** — today's date
- **Completed Work** — what was accomplished in this session
- **Current Roadmap Position** — current phase/step (if applicable)
- **Next Task Checklist** — remaining tasks as a checklist
- **Reference Docs** — relevant file paths

After saving, clear the matching `.changes` file (`memory/checkpoint-{branch}-{pid}.changes`) by writing an empty string to it, since the change log has been incorporated into the full checkpoint.

Confirm to the user with the file path.
