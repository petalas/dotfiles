- Always use the ?? operator instead of || for setting default values (for example empty arrays)

## Agent Execution Model — Async & Parallel by Default

**Core principle**: The main agent is an **orchestrator** — it plans, delegates, synthesizes, and makes decisions. It does not do bulk research or file reading itself. The context window is finite; filling it with raw file contents wastes capacity that should be used for reasoning and decision-making.

### When to spawn agents

- **Reading/investigating code**: Don't read files into the main context just to understand them. Spawn an agent to read, analyze, and report back a summary.
- **Research & exploration**: Any open-ended search ("find all usages of X", "understand how Y works") goes to a background agent.
- **Independent subtasks**: When a task has multiple independent parts, spawn agents for each in parallel — don't serialize work you can parallelize.
- **Builds, tests, linting**: Run these in background agents so you can continue working while they execute.
- **Threshold**: 1–2 known files with a specific question → read directly. 3+ files or open-ended exploration → spawn an agent.

### Parallel by default, serial when necessary

Always prefer parallel execution, but use judgment about when work must be sequential:

- **Parallel**: independent investigations, reading unrelated subsystems, running tests while editing, multiple non-overlapping file edits.
- **Serial**: when one agent's result determines what the next agent should do (e.g., "find the bug" before "fix the bug"), when edits have logical dependencies (e.g., change a struct definition before updating its call sites), or when you need to validate an approach before committing to it.
- **Rule of thumb**: if you can write the agent's full prompt without waiting for another result, it can run in parallel.

### Parallel edits — avoid conflicts

When multiple agents edit files simultaneously:

- **Partition by file**: never assign the same file to two parallel agents. If two changes touch the same file, either combine them into one agent or serialize them.
- **Partition by concern**: each agent owns a clear, non-overlapping set of files. Define this explicitly in the prompt.
- **Dependent edits**: if changing file A requires corresponding changes in file B (e.g., renaming a function and updating all callers), one agent should handle both, or the second agent should run after the first completes.

### How agents should work

- Each agent reads its own files in its own context — the main agent should NOT pre-read files "to pass context" to the agent.
- Give agents clear, self-contained prompts with enough context to work independently (file paths, function names, what you need to know).
- Agents return **structured, concise summaries**: what they found, what's relevant to the task, and what they recommend — not a dump of everything they read.
- Prefer `run_in_background: true` for agents whose results you don't need before your next step. Use foreground only when you're blocked on the result.
- **Resume over re-spawn**: if you need follow-up from an agent, resume it (preserves its context) rather than spawning a fresh one that has to re-read everything.

### What stays in the main context

- User communication and decision-making
- Synthesizing results from agents into coherent responses
- Small, targeted edits where you already know exactly what to change
- Orchestration: deciding what agents to spawn, reviewing their results, planning next steps

### Anti-patterns to avoid

- Reading 3+ files into main context "to understand the codebase" — spawn an Explore agent instead
- Doing sequential file reads when you could send parallel agents
- Repeating work an agent already did (e.g., re-reading files the agent summarized)
- Spawning an agent for trivial single-file reads where you already know the path and just need a few lines
- Running two agents that edit the same file — one will clobber the other

## Git Commits
- Do not add Co-Authored-By lines

## Knowledge System

Projects should have a **routing table** in CLAUDE.md mapping file patterns to docs, and a **"When You Struggle"** capture process. Run `/knowledge-audit` to check any project, set one up, or migrate from an older format.

Do NOT proactively audit on every session start — only when asked or when you notice a project lacks a routing table.

**Active Warnings**: Projects can have a temporary `## Active Warnings` section at the top of CLAUDE.md for cross-cutting concerns (broken CI, in-progress migrations, etc.). Remove entries when resolved.

**Quality bar**: Only capture things specific to the project or that contradict reasonable assumptions. General programming knowledge doesn't belong in LEARNINGS.md.

**Pruning**: When adding or updating a doc entry, scan nearby entries for anything outdated and fix or remove them.
