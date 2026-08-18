# dotfiles

Personal dotfiles and machine setup for macOS and Linux (Ubuntu / Debian / Arch).

## Fresh machine — one line

```sh
curl -fsSL https://raw.githubusercontent.com/petalas/dotfiles/main/bootstrap.sh | bash
```

Installs Git if missing, clones this repo to `~/git/dotfiles` (override with `$DOTFILES_DIR`), then opens the visual installation-plan selector. Use the two-pane selector to toggle steps or dependency groups, move into a group's applications with Tab/→, and review with Enter. Once confirmed, execution is fully unattended.

For an unattended full installation with every available item selected:

```sh
curl -fsSL https://raw.githubusercontent.com/petalas/dotfiles/main/bootstrap.sh |
  bash -s -- --unattended
```

## Already cloned

Build and run an installation plan visually:

```sh
cd ~/git/dotfiles && ./easy-install.sh
```

Replay a saved plan without prompting, or explicitly install everything:

```sh
./easy-install.sh --plan ~/.local/state/dotfiles/installation-plan
./easy-install.sh --unattended
```

The most recently confirmed visual selection is saved under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/installation-plan` and becomes the next visual run's defaults. Missing or invalid saved defaults safely fall back to repository defaults.

After a pull, relink managed files without downloads or package/plugin installation:

```sh
cd ~/git/dotfiles
git pull --ff-only
./link-dotfiles.sh
```

The linker is local-only, idempotent, and preserves any replaced file, directory, or symlink as `<path>.old`. To restore generated repositories, plugins, and caches separately, run `./setup-tools.sh`.

## Per-machine subsetting

The selector exposes the same dependency groups on every supported OS and marks platform-unavailable groups instead of hiding them. Toggle a group from the left pane, or customize its individual applications in the right pane. Foundation and the Bun, Node, and Rust applications are required and cannot be disabled. Deselection skips future installation and reconciliation; it never uninstalls existing software.

## Run a single installer

```sh
./install rust         # install Rust toolchain
./install yazi         # install/upgrade a compatible yazi + ya pair
./install docker       # install Docker (Linux)
./install locale       # repair/reconfigure UTF-8 locale manually
./install ssh_keys     # generate ed25519 key + copy pubkey to clipboard
./install list         # show all available installers
```

Installer modules are internal; use the dispatcher rather than executing files under `installers/` directly.

## Update an existing machine

From Zsh, run `upd`, or invoke the underlying command directly:

```sh
~/git/dotfiles/update-dotfiles
```

It fast-forwards this repository, resolves the saved installation plan, reconciles selected missing software/state, then upgrades software already present—including deselected applications. Deselection never suppresses maintenance or triggers uninstallation. Independent failures are collected and reported at the end.

## Notes

- Setup requires `sudo -n` for ordinary Linux users before selection starts. Linux root runs avoid sudo; macOS setup must run as the target non-root user because Homebrew refuses root installs. Provision administrator access and macOS Command Line Tools outside the script. After visual confirmation, child processes receive closed stdin and non-interactive package-manager settings.
- Linux software comes from distro repositories whenever available. Debian/Ubuntu install `apt-fast` from its signed PPA, preconfigure it for 8 parallel downloads, and fall back to Nala or `apt-get`. Arch configures pacman for 8 parallel downloads. Official vendor APT repositories, `.deb` files, or native release binaries are fallbacks for applications absent from distro repositories. Flatpak is not used.
- Debian selects and caches its fastest archive mirror with `netselect-apt`; Arch ranks current HTTPS mirrors with Reflector (or `rankmirrors` on Arch ARM). Original source/mirror files are retained as `.dotfiles` backups. Set `DOTFILES_REFRESH_MIRRORS=1` for one setup run to rerank them.
- `catalog/` is the canonical inventory for installation steps, dependency groups, applications, prerequisites, and platform adapters. `Brewfile` is a generated full compatibility artifact; regenerate it with `./tools/generate-brewfile >Brewfile`. Dependencies otherwise come from current Homebrew, npm, Cargo, GitHub releases, and official installer endpoints. There is no repository-maintained version lockfile.
- Package lists are installed in batches. After bounded retries, a failed batch is retried one package at a time so an unavailable package does not block unrelated packages. Required failures stop setup after all entries have been attempted; individual applications and language add-ons are best effort.
- The required Foundation group configures `en_US.UTF-8` during dependency installation; `./install locale` is only needed for a manual repair.
- Linux writes Ghostty's `xdg-terminal-exec` preference under `XDG_CONFIG_HOME`; macOS leaves the default-terminal choice to the user.
- `./tests/run.sh` runs deterministic tests with local fake executables instead of live package repositories or mirrors. Latest-release Yazi compatibility is a separate scheduled/manual CI integration check.
- Commits are gated by ShellCheck plus Bash/Zsh syntax validation in `.githooks/pre-commit`. The linker activates it through `core.hooksPath`.
- See [`AGENTS.md`](AGENTS.md) for project structure and conventions, and [`docs/LEARNINGS.md`](docs/LEARNINGS.md) for repo-specific gotchas.
