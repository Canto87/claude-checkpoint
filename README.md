<h1 align="center">claude-checkpoint</h1>

<p align="center">
  <strong>Persistent session context for Claude Code</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg" alt="Platform">
  <img src="https://img.shields.io/badge/requires-Claude%20Code%20CLI-blueviolet.svg" alt="Requires Claude Code">
  <img src="https://img.shields.io/badge/shell-bash-green.svg" alt="Shell: Bash">
  <br>
  <a href="README.md"><img src="https://img.shields.io/badge/🇺🇸_English-white.svg" alt="English"></a>
  <a href="README.ko.md"><img src="https://img.shields.io/badge/🇰🇷_한국어-white.svg" alt="한국어"></a>
  <a href="README.ja.md"><img src="https://img.shields.io/badge/🇯🇵_日本語-white.svg" alt="日本語"></a>
</p>

<p align="center">
  Automatically saves and restores work state across sessions using Claude Code's hook system.<br>
  No more <em>"where was I?"</em> when starting a new session.
</p>

---

## The Problem

Claude Code is a powerful coding agent, but its context window is finite.

- **Compact** — when the context grows large, it gets compressed into a summary. Concrete details like file paths, task checklists, and step-by-step progress are often lost in the process
- **Context window saturation** — when the context is completely full, even `/resume` can't help. You're forced to start a fresh session with no working state at all
- **`/clear`** — intentionally resetting context also wipes your current working state

On long-running projects, this means critical progress details slip away the longer you work.

## The Solution

`claude-checkpoint` hooks into Claude Code's lifecycle to create **automatic save points**:

```
  You work normally
       │
       ▼
  git commit / file edit ──► Checkpoint saved automatically
       │
       ▼
  Session ends (crash, close, compact, /clear)
       │
       ▼
  New session starts
       │
       ▼
  Checkpoint restored into context ──► Claude picks up where you left off
```

Zero configuration after install. Zero commands to remember.

## Quick Start

```bash
# 1. Clone
git clone https://github.com/Canto87/claude-checkpoint.git

# 2. Install into your project
./claude-checkpoint/install.sh /path/to/your/project

# 3. Done. Start working normally.
```

> **Requirements:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code), `jq`, Git

## How It Works

### Events & Actions

| Event | Action |
|:------|:-------|
| `git commit` | Saves checkpoint (completed work, next tasks, references) |
| File edit/write | Auto-saves checkpoint (10-minute cooldown between saves) |
| Session start | Restores most recent checkpoints into context |
| `/clear` | Restores most recent checkpoints into context |
| Compact | Restores checkpoints + prompts Claude to save any unsaved state |

### Slash Commands

| Command | Description |
|:--------|:------------|
| `/save` | Manually save a checkpoint anytime |
| `/checkpoints` | List all checkpoint files for the current branch |
| `/checkpoint-clear` | Clean up old checkpoint files |

### File Structure

Checkpoints live in Claude Code's auto-memory directory:

```
~/.claude/projects/{encoded-project-path}/memory/
├── MEMORY.md                        # Long-term knowledge (you manage this)
├── checkpoint-main-12345.md         # Session A on main branch
├── checkpoint-main-67890.md         # Session B on main branch
└── checkpoint-feat-auth-11111.md    # Session on feature branch
```

- **MEMORY.md** — project patterns, key decisions, long-lived notes
- **checkpoint-\*.md** — current task state, next steps, references (auto-managed)

### Multi-Session Safety

Each session writes to its own checkpoint file using the naming pattern:

```
checkpoint-{branch}-{session-pid}.md
```

Parallel sessions on the same project never conflict. On restore, the **3 most recent** checkpoints for the current branch are loaded to keep context injection lightweight. Older checkpoints can be viewed with `/checkpoints`.

Stale checkpoints older than **24 hours** are automatically cleaned up.

### Checkpoint Format

```markdown
# Checkpoint

## Last Updated
- Date: 2025-01-15
- Commit: abc1234

## Completed Work
- Implemented user authentication module

## Current Roadmap Position
- Roadmap: docs/plans/ROADMAP.md
- Current step: Phase 2 - API integration
- Status: in progress

## Next Task Checklist
- [ ] Add token refresh logic
- [ ] Write integration tests

## Reference Docs
- docs/plans/auth-design.md
- docs/API.md
```

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     Claude Code CLI                      │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  PostToolUse Hooks                                       │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Bash  → detects git commit → checkpoint save      │  │
│  │  Edit  → auto-save with 10min cooldown             │  │
│  │  Write → auto-save with 10min cooldown             │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  SessionStart Hooks                                      │
│  ┌────────────────────────────────────────────────────┐  │
│  │  startup / clear / compact → checkpoint restore    │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  Slash Commands                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │  /save  /checkpoints  /checkpoint-clear            │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  ~/.claude/projects/*/memory/                            │
│  ┌──────────────┐  ┌──────────────────────────────────┐  │
│  │  MEMORY.md   │  │  checkpoint-{branch}-{pid}.md    │  │
│  │  (long-term) │  │  (short-term, per session)       │  │
│  └──────────────┘  └──────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

## Install / Uninstall

### Install

```bash
./install.sh /path/to/your/project
```

What it does:
1. Copies hook scripts to `.claude/hooks/`
2. Copies slash commands to `.claude/commands/`
3. Merges hook config into `.claude/settings.json` (existing hooks are preserved)
4. Adds session protocol section to your project's `MEMORY.md`

### Uninstall

```bash
./uninstall.sh /path/to/your/project
```

Removes only `claude-checkpoint` hook entries, commands, and temp files. Other hooks and settings are untouched.

> Checkpoint files in `~/.claude/projects/*/memory/` are **not** deleted automatically.
> Remove them manually if no longer needed.

## Token Cost

The hook scripts themselves are **plain shell scripts** — they consume **zero API tokens**.

The only token cost comes from:
- **Checkpoint restore on session start** — ~200-500 tokens per checkpoint (max 3 loaded)
- **Checkpoint save on commit** — ~300-600 tokens
- **Auto-save on file edit** — ~300-600 tokens (at most once per 10 minutes)

Negligible compared to normal conversation usage.

## FAQ

**Q: What if I forget to commit?**
Checkpoints are also auto-saved when you edit files (with a 10-minute cooldown). You can also run `/save` anytime for a manual save. So even without committing, your progress is periodically captured.

**Q: Can I edit checkpoint files manually?**
Yes, they're plain Markdown. But they'll be overwritten on the next auto-save or commit in that session.

**Q: Does it work with worktrees?**
Yes. Each worktree has its own branch, so checkpoints are naturally isolated.

**Q: What happens if `jq` is not installed?**
The installer will exit with an error. Install it with `brew install jq` (macOS) or `apt install jq` (Linux).

**Q: How many checkpoints are loaded on restore?**
Up to 3 most recent checkpoints for the current branch. Older ones are available via `/checkpoints`.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

[MIT](LICENSE)
