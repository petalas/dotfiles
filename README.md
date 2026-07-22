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
./install yazi         # install/upgrade a compatible yazi + ya pair
./install docker       # install Docker (Linux)
./install locale       # repair/reconfigure UTF-8 locale manually
./install ssh_keys     # generate ed25519 key + copy pubkey to clipboard
./install list         # show all available installers
```

## Test clean Linux installs

The Docker integration suite starts with minimal Debian, Ubuntu, and Arch
images, creates a normal passwordless-sudo user, and runs the same public
entry point twice:

```sh
./tests/integration/run.sh          # all supported Linux distributions
./tests/integration/run.sh debian   # one distribution
```

Each image runs `./easy-install.sh`, validates the configured UTF-8 locale,
Mosh, tmux mouse mode and plugins, zsh startup, cloned configuration repos,
and dotfile symlinks, then reruns the pipeline to check idempotency. The
container profile skips desktop fonts, GUI applications, system services,
language SDKs, and AUR packages because they cannot be exercised meaningfully
inside Docker. Fast host-independent tests separately cover the Yazi
installer's legacy-version migration, component matching, and locked plugin
restoration, and validate the managed config against the latest stable Yazi
release. Normal host installs continue to install the complete set.

macOS cannot be represented by a Docker image; its scripts remain covered by
the shared ShellCheck gate and should be smoke-tested on a Mac when changing
Homebrew-specific behavior.

## Notes

- Setup needs passwordless sudo to avoid repeated prompts. `easy-install.sh` adds a `/etc/sudoers.d/<user>` entry on first run.
- On macOS, `easy-install.sh` disables Homebrew confirmation prompts for the entire run, including Homebrew's own installer and package upgrades. A fresh machine can still require the initial administrator authentication and the Xcode Command Line Tools GUI.
- Optional package, font, and shell-customization failures are reported at the end without blocking independent setup. The installer still stops when sudo, Homebrew, a required bootstrap dependency, or dotfile linking is unavailable.
- Once the repository is available, Debian and amd64 Ubuntu package sources are routed through their official nearby-mirror services before dependency setup; existing source files are backed up under `/etc/apt/.dotfiles-backups/`. The one-line bootstrap may need one initial package refresh to install Git, and non-amd64 Ubuntu keeps its `ports.ubuntu.com` source unchanged.
- `easy-install.sh` configures `en_US.UTF-8` before installing the remaining dependencies; `./install locale` is only needed for a manual repair.
- CI runs `easy-install.sh` twice on clean Debian, Ubuntu, and Arch images using the Docker suite above.
- Commits are gated by a shellcheck pre-commit hook (`.githooks/pre-commit`). Wired up automatically by `link-dotfiles.sh` via `core.hooksPath`.
- See [`AGENTS.md`](AGENTS.md) for project structure and conventions, and [`docs/LEARNINGS.md`](docs/LEARNINGS.md) for repo-specific gotchas.
