## Session Protocol
- Checkpoints: `checkpoint-{branch}-{pid}.md` (isolated per branch + session, auto-routed by hooks)
- On commit → Hook triggers checkpoint save for this session
- On session start/clear/compact → Hook injects all checkpoints for the current branch into context
- Stale checkpoints (>24h) are automatically cleaned up
- This file (MEMORY.md) is for long-term knowledge only. Session state goes in checkpoints
