# dotfiles

Personal dotfiles and machine setup for macOS and Linux (Ubuntu / Debian / Arch).

## Fresh machine — one line

```sh
curl -fsSL https://raw.githubusercontent.com/petalas/dotfiles/main/bootstrap.sh | bash
```

Installs git if missing, clones this repo to `~/git/dotfiles` (override with `$DOTFILES_DIR`), then runs `easy-install.sh`.

## Already cloned

```sh
cd ~/git/dotfiles && ./easy-install.sh
```

## Per-machine subsetting

Skip optional Brewfile groups:

```sh
SKIP_GAMING=1 SKIP_CAD=1 SKIP_MOBILE=1 ./easy-install.sh
```

## Run a single installer

```sh
./install rust         # install Rust toolchain
./install docker       # install Docker (Linux)
./install ssh_keys     # generate ed25519 key + copy pubkey to clipboard
./install list         # show all available installers
```

## Notes

- Setup needs passwordless sudo to avoid repeated prompts. `easy-install.sh` adds a `/etc/sudoers.d/<user>` entry on first run.
- Commits are gated by a shellcheck pre-commit hook (`.githooks/pre-commit`). Wired up automatically by `link-dotfiles.sh` via `core.hooksPath`.
- See [`AGENTS.md`](AGENTS.md) for project structure and conventions, and [`docs/LEARNINGS.md`](docs/LEARNINGS.md) for repo-specific gotchas.
