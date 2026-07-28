# dotfiles

Personal dotfiles and machine setup for macOS and Linux (Ubuntu / Debian / Arch).

## Fresh machine — one line

```sh
curl -fsSL https://raw.githubusercontent.com/petalas/dotfiles/main/bootstrap.sh | bash
```

Installs git if missing, clones this repo to `~/git/dotfiles` (override with `$DOTFILES_DIR`), then runs `easy-install.sh`.

## Already cloned

Run the full setup pipeline:

```sh
cd ~/git/dotfiles && ./easy-install.sh
```

After a pull, relink managed files without reinstalling packages:

```sh
cd ~/git/dotfiles
git pull --ff-only
./link-dotfiles.sh
```

The linker is idempotent and preserves any replaced file, directory, or symlink as `<path>.old`.

## Per-machine subsetting

Skip optional Brewfile groups:

```sh
SKIP_GAMING=1 SKIP_CAD=1 SKIP_MOBILE=1 ./easy-install.sh
```

## Run a single installer

```sh
./install rust         # install Rust toolchain
./install yazi         # install/upgrade a compatible yazi + ya pair
./install docker       # install Docker (Linux)
./install locale       # repair/reconfigure UTF-8 locale manually
./install ssh_keys     # generate ed25519 key + copy pubkey to clipboard
./install list         # show all available installers
```

## Test clean Linux installs

The Docker integration suite starts with minimal Debian stable, Ubuntu, and
Arch images, creates a normal passwordless-sudo user, and runs the public setup
pipeline twice:

```sh
./tests/integration/run.sh             # all supported Linux distributions
./tests/integration/run.sh debian      # one distribution
./tests/integration/run.sh bootstrap   # fresh-machine bootstrap path
INTEGRATION_PULL=0 ./tests/integration/run.sh ubuntu  # reuse local images
```

Each image runs `./easy-install.sh`, validates the configured UTF-8 locale with a real Mosh server launch, checks
tmux, zsh, Git checkouts, permissions, sudoers, and dotfile links, then compares
managed-file and installed-package manifests after a second run. The bootstrap
target additionally installs Git, clones an injectable local fixture, syncs an
existing clone, and rejects a dirty worktree. CI pulls fresh images for normal
runs; a weekly compatibility matrix covers Debian oldstable and arm64 Debian
and Ubuntu.

The container profile skips desktop fonts, GUI applications, system services,
and language toolchains because they cannot be exercised meaningfully
inside Docker. Fast host-independent tests separately cover the Yazi
installer's legacy-version migration, component matching, and locked plugin
restoration, and validate the managed config against the latest stable Yazi
release. Normal host installs continue to install the complete set.

macOS cannot be represented by Docker; CI covers shell syntax and the
non-interactive orchestration on an Apple Silicon runner.

## Notes

- Setup is non-interactive and requires `sudo -n` to work before it starts. Provision administrator access and macOS Command Line Tools outside the script.
- Linux software comes from distro repositories whenever available. Debian/Ubuntu use a repository-installed parallel APT frontend (`apt-fast` when available, otherwise Nala); `apt-get` is only the bootstrap/fallback. Arch uses pacman with 16 concurrent downloads. Official vendor APT repositories, `.deb` files, or native release binaries are fallbacks for applications absent from distro repositories. Flatpak is not used.
- Debian selects and caches its fastest archive mirror with `netselect-apt`; Arch ranks current HTTPS mirrors with Reflector (or `rankmirrors` on Arch ARM). Original source/mirror files are retained as `.dotfiles` backups. Set `DOTFILES_REFRESH_MIRRORS=1` for one setup run to rerank them.
- Dependencies otherwise come from current Homebrew, npm, Cargo, GitHub releases, and official installer endpoints. There is no repository-maintained version lockfile.
- Required package and dotfile-linking failures stop setup. Individual applications and language add-ons are best effort. Fonts, login-shell changes, and Zsh plugins continue independently and produce a nonzero final status if they fail.
- `easy-install.sh` configures `en_US.UTF-8` before installing the remaining dependencies; `./install locale` is only needed for a manual repair.
- Linux writes Ghostty's `xdg-terminal-exec` preference under `XDG_CONFIG_HOME`; macOS leaves the default-terminal choice to the user.
- CI runs `easy-install.sh` twice on clean Debian, Ubuntu, and Arch images using the Docker suite above.
- Commits are gated by a shellcheck pre-commit hook (`.githooks/pre-commit`). Wired up automatically by `link-dotfiles.sh` via `core.hooksPath`.
- See [`AGENTS.md`](AGENTS.md) for project structure and conventions, and [`docs/LEARNINGS.md`](docs/LEARNINGS.md) for repo-specific gotchas.
