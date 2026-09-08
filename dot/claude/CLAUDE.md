@~/.claude/AGENTS.md

Harness-neutral rules (engineering-mode, defaults, commits) live in the imported `AGENTS.md`, shared with Codex, Pi, and OMP. Everything below is Claude Code specific.

## Working with agents

- Partition parallel edits by file; never let two agents edit the same file.
- Prefer resuming an existing agent over spawning a new one for follow-up questions.
