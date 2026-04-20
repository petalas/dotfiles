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
