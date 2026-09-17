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
