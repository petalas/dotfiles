# Learnings

Gotchas and insights discovered while maintaining these dotfiles.

---

## Homebrew package name collisions

- `maestro` on Homebrew splits into two completely unrelated projects:
  - **Cask** `maestro` — Maestro AI agent command center from runmaestro.ai.
  - **Formula** `mobile-dev-inc/tap/maestro` — Mobile Dev Maestro CLI for mobile E2E tests (requires tapping `mobile-dev-inc/tap` first).
- Both can be installed side-by-side; the CLI binary lives at a different path from the cask app.
- The Mobile Dev CLI needs Java 17+, so install `temurin@17` alongside it on macOS.

---

## Brewfile env-var gates must be prefixed `HOMEBREW_`

- `brew bundle` evaluates the Brewfile as Ruby, so `unless ENV["..."]` conditionals *do* work — but only for env vars Homebrew lets through.
- Homebrew sanitises the environment before running the Brewfile. Arbitrary vars like `SKIP_GAMING` are stripped; only `HOMEBREW_*` (plus a small allow-list) survive.
- Symptom: a gate like `unless ENV["SKIP_GAMING"]` never fires, regardless of whether you set `SKIP_GAMING=1`. Confusing because `if false` in the same Brewfile *does* work — ruling out "Ruby isn't evaluated."
- Fix: either use `HOMEBREW_SKIP_GAMING` directly in the Brewfile, or translate in the wrapper script before invoking `brew bundle`. `brew-deps.sh` does the translation so the user-facing API stays as plain `SKIP_*`.

---

## `bun upgrade` re-appends its completions block to `~/.zshrc`

- Symptom: after `bun upgrade` (invoked via `upd`), `dot/zshrc` shows an unsolicited trailing block:
  ```
  # bun completions
  [ -s "/Users/nick/.bun/_bun" ] && source "/Users/nick/.bun/_bun"
  ```
- Cause: bun's `InstallCompletionsCommand` (Zig, `src/cli/install_completions_command.zig`) runs on every upgrade. It does a raw-text substring search over the rc file and appends unless it finds **either**:
  1. The absolute resolved path of `_bun` (e.g. `/Users/nick/.bun/_bun`) literally present, OR
  2. The exact string `# bun completions\n`.
- `$HOME/.bun/_bun` does **not** satisfy #1 — the search is on raw file text, no shell expansion.
- Fix: keep the literal `# bun completions` comment inside our `# bun` block in `dot/zshrc`. That sentinel is portable across machines; the absolute path isn't.

---

## `bunx skills update --global` can reuse a corrupt temp install

- Symptom: the `upd` skills step fails with `ERR_MODULE_NOT_FOUND` for a dependency path under `$TMPDIR/bunx-*-skills@latest/node_modules/...`, e.g. `yaml/dist/index.js`.
- Cause: `bunx` reuses per-package temp installs. If one is only partially extracted, package metadata can say the dependency exists while required files are missing on disk.
- Fix: remove the bunx temp install and rerun. `dot/zshrc` has `bunx-clean` for manual cleanup, and `upd` retries the skills step once after running it automatically.

---

## gitconfig values containing `;` or `#` must be quoted

- Symptom: `git config -f dot/gitconfig core.pager` returned `if command -v delta >/dev/null 2>&1` — the value was silently truncated at the first `;`.
- Cause: in gitconfig syntax, unquoted `;` and `#` terminate the value as inline comments. An unquoted shell pipeline with semicolons is parsed as `value;  comment`.
- Fix: wrap any multi-statement shell expression in double quotes, e.g. `pager = "if ...; then delta; else less -R; fi"`. Applies to `core.pager`, `interactive.diffFilter`, and any other config key whose value is executed by `/bin/sh -c`.

---

## kitty `globinclude` rejects absolute / `$HOME` paths

- Symptom: kitty startup aborts with `Non-relative patterns are unsupported in line: globinclude $HOME/.config/...`.
- Cause: kitty's `globinclude` directive requires the pattern to be relative to the config file's directory (`~/.config/kitty/`). Absolute paths and `$HOME` expansion are rejected. `include` accepts absolute paths; `globinclude` does not.
- Why we use globinclude anyway: `include` on a missing file still logs a warning, whereas `globinclude` is silent when the pattern matches zero files — the right semantics for **optional** machine-specific configs (ml4w, pywal).
- Fix: write the pattern relative to `~/.config/kitty/`, e.g. `globinclude ../ml4w/settings/kitty-cursor-trail.conf` or `globinclude ../../.cache/wal/colors-kitty.conf`.
