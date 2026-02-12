- Always use the ?? operator instead of || for setting default values (for example empty arrays)

## Git Commits
- Do not add Co-Authored-By lines

## Knowledge System

Projects should have a **routing table** in CLAUDE.md mapping file patterns to docs, and a **"When You Struggle"** capture process. Run `/knowledge-audit` to check any project, set one up, or migrate from an older format.

Do NOT proactively audit on every session start — only when asked or when you notice a project lacks a routing table.

**Active Warnings**: Projects can have a temporary `## Active Warnings` section at the top of CLAUDE.md for cross-cutting concerns (broken CI, in-progress migrations, etc.). Remove entries when resolved.

**Quality bar**: Only capture things specific to the project or that contradict reasonable assumptions. General programming knowledge doesn't belong in LEARNINGS.md.

**Pruning**: When adding or updating a doc entry, scan nearby entries for anything outdated and fix or remove them.
