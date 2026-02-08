# Dotfiles

Personal dotfiles and machine setup scripts for macOS and Linux.

## Active Warnings

<!-- Temporary alerts for cross-cutting concerns. Remove when resolved. -->

*(None currently.)*

## Knowledge System

This project uses a routing table (below) to map file patterns to docs you must read before editing. When you struggle with something, capture what you learned (see [When You Struggle](#when-you-struggle-mandatory)).

## Project Structure

```
*.sh                  # Root setup scripts (main entry points)
installers/           # Individual tool installer scripts
dot/                  # Config files symlinked to ~
  .config/            # XDG configs (kitty, alacritty, bat, yazi)
  claude/             # Claude Code config (symlinked to ~/.claude/)
  zshrc               # Shell config
  gitconfig           # Git config
  work/               # Work-specific overrides
```

## Required Reading Before Editing

Before modifying code, find the matching file pattern and **read the linked doc first**:

| File pattern you are editing | Read first |
|------------------------------|-----------|
| `*.sh` (root) | README.md for sudoers note; check script dependencies |
| `installers/*.sh` | Existing installers for patterns (apt vs brew detection) |
| `dot/zshrc` | Current aliases/functions before adding duplicates |
| `dot/.config/**` | App's official docs for config syntax |
| `dot/claude/**` | This is GLOBAL Claude config — changes affect all projects |
| `link-dotfiles.sh` | Understand symlink structure before adding new dotfiles |
| Weird bug or unexpected behavior | [LEARNINGS.md](docs/LEARNINGS.md) — search for the symptom |

## When You Struggle (Mandatory)

If a fix takes more than one attempt, follow these steps BEFORE moving on:

1. **Check if it's already documented** — grep `docs/` for the key terms
2. **If documented**: improve the entry if it wasn't clear enough to prevent this
3. **If new**: add to the appropriate doc (or [LEARNINGS.md](docs/LEARNINGS.md) if unsure). Only capture things **specific to this project** — not general programming knowledge.
4. **Add a routing entry** to this table if it doesn't already cover this file pattern
5. **Consider code prevention**: can a wrapper function or validation prevent this? If yes, implement it
6. **Prune while you're there**: if you spot outdated entries nearby, fix or remove them

## Conventions

- Use `??` instead of `||` for default values (empty arrays, etc.)
- Installers should detect OS and use appropriate package manager
- Scripts should be idempotent (safe to run multiple times)
- Prefer symlinks over copying files (managed via `link-dotfiles.sh`)
