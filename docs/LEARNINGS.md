# Learnings

Gotchas and insights discovered while maintaining these dotfiles.

---

## Homebrew package name collisions

- `maestro` on Homebrew is an unrelated desktop app cask, not the Mobile Dev Maestro CLI used for mobile E2E tests.
- Install the CLI with `mobile-dev-inc/tap/maestro` after tapping `mobile-dev-inc/tap`.
- Maestro CLI also needs Java 17+, so install `temurin@17` alongside it on macOS.
