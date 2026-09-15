# Global agent instructions

Harness-neutral rules for every coding agent (Claude Code, Codex, Pi, OMP). Linked to each
harness's global instructions path by `link-dotfiles.sh`; Claude Code imports this file from
`~/.claude/CLAUDE.md`. Keep this file free of harness-specific tools or commands.

## Engineering mode

- For any change to code that will be kept, load the `engineering-mode` skill first and follow
  it. It picks a playbook and routes to the principle skills and `power-of-ten`.
- Skip it for throwaway scripts, one-off commands, pure config or documentation edits, and
  casual questions. A project's own instructions may narrow or disable it.

## Git commits

- Before creating, amending, or proposing any commit, load the `commit-guidelines` skill and follow it.

## Working with agents

- Decompose before reading. Split the task into slices that are independent by file and by
  decision. Fan the independent slices out to subagents in one batch; keep only the coupled
  design decisions in the main thread.
- Route by job:
  - Mapping unfamiliar code, tracing a lifecycle, or answering "where is X used" goes to a fast
    read-only researcher. Never read file after file in the main thread.
  - Edits with a known recipe (dependency arrays, type imports, config flags, one-line fixes
    across files) go to a low-reasoning editor, one slice per file group.
  - Self-contained investigations (a broken test environment, a flaky build step) go to a
    general subagent while the main thread continues.
  - After a non-trivial change, an independent reviewer reads the diff before you report.
- Threshold: if a task touches more than three files, or a question needs more than three reads
  to answer, delegate that part.
- Width follows the slice count, not the kind of work. Six one-line fixes in six files are six
  subagents in one batch, not one subagent with a list. The concurrency cap is high; the only
  reason to merge slices is a shared file or a shared decision.
- Delegate first, then think. The first action on a multi-file task is one batch that starts
  every researcher and every recipe editor; do the coupled design work while they run.
- Never idle on subagents. If the next step depends on their output, pick an independent one
  (verification setup, docs, cleanup) and do it while you wait.
- The main thread owns decomposition, cross-slice contracts, coupled decisions, verification on
  the real artifact, and the final answer. Do not outsource the plan.
- Give parallel subagents disjoint files. If one file must be shared, assign disjoint regions and
  use targeted edits, never whole-file rewrites.
- Subagents skip formatters, linters, and full test suites. Run those once at the end.
