# dotfiles

Personal dotfiles and machine setup for macOS and Linux (Ubuntu / Debian / Arch).

## Fresh machine — one line

```sh
curl -fsSL https://raw.githubusercontent.com/petalas/dotfiles/main/bootstrap.sh | bash
```

Installs Git if missing, clones this repo to `~/git/dotfiles` (override with `$DOTFILES_DIR`), inspects application state, then opens the state-aware visual installation plan. A persistent **Plan → Review → Run** stepper and **Ensure present**, **Leave unchanged**, **Remove**, and **Force removal** outcome counts show where you are and what will happen. Compact mode is the default: each colored application row shows its current state and adds `-> desired` only when the run would change it. Press `v` to show/hide custody and evidence. The planning tree has dependency groups as collapsible roots and applications as leaves: use up/down to navigate, left/right to collapse/expand, `[`/`]` to filter groups, and `e`/`u`/`r`/`f` to change the selected leaf or entire selected group subtree. `Shift+E/U/R/F` applies an outcome to the current leaf's parent group. Disabled reasons appear only after a rejected action. Enter opens review. Once differentiated confirmation succeeds, execution is fully unattended and shows overall plus active-operation progress.

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

## Per-machine intent and safe removal

The selector exposes the same dependency groups on every supported OS and reports each application's current presence/custody beside its desired post-run outcome. Foundation and the Bun, Node, and Rust applications are required and cannot be removed. Group actions only edit the reviewed desired-outcome plan; they never cross the destructive confirmation boundary or initiate execution.

**Exact Remove** is enabled only for a package-manager registration or matching installation receipt. **Force removal** is a separately confirmed, best-effort cleanup through catalog-reviewed package identities and bounded paths. Retained dependents block prerequisite removal; package-manager dependency checks are never bypassed. Neither mode removes package-manager orphans, shared prerequisites, projects, profiles, vaults, sessions, editor configuration, browser data, Docker data, or other user data. Changed support files are retained rather than deleted.

Only wanted/not-wanted defaults are saved in `${XDG_STATE_HOME:-~/.local/state}/dotfiles/installation-plan`; Remove and Force removal never persist or replay. The latest permission-restricted, non-replayable result is written to `${XDG_STATE_HOME:-~/.local/state}/dotfiles/latest-run-report`.

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
- `catalog/` is the canonical inventory for installation steps, dependency groups, applications, prerequisites, ordered application providers, payload/support/effect actions, platform adapters, and bounded cleanup recipes. `Brewfile` is a generated full compatibility artifact; regenerate it with `./tools/generate-brewfile >Brewfile`. Dependencies otherwise come from current Homebrew, npm, Cargo, GitHub releases, and official installer endpoints. There is no repository-maintained application version lockfile.
- Visual mode uses the repository-owned Bubble Tea/Bubbles/Lip Gloss helper. `tools/run-install-tui` downloads a pinned release binary only after matching its SHA-256 manifest entry. If acquisition fails, it builds from source only when a compatible Go toolchain already exists; it never installs Go. Set `DOTFILES_TUI_DISPLAY=rich|plain|ascii` to force an accessibility fallback; `NO_COLOR` selects plain rendering and `TERM=dumb` selects ASCII.
- Package lists are installed in batches. After bounded retries, a failed batch is retried one package at a time so an unavailable package does not block unrelated packages. Required failures stop setup after all entries have been attempted; individual applications and language add-ons are best effort.
- The required Foundation group configures `en_US.UTF-8` during dependency installation; `./install locale` is only needed for a manual repair.
- Linux writes Ghostty's `xdg-terminal-exec` preference under `XDG_CONFIG_HOME`; macOS leaves the default-terminal choice to the user.
- `./tests/run.sh` runs deterministic tests with local fake executables instead of live package repositories or mirrors. Latest-release Yazi compatibility is a separate scheduled/manual CI integration check.
- Commits are gated by ShellCheck plus Bash/Zsh syntax validation in `.githooks/pre-commit`. The linker activates it through `core.hooksPath`.
- See [`AGENTS.md`](AGENTS.md) for project structure and conventions, and [`docs/LEARNINGS.md`](docs/LEARNINGS.md) for repo-specific gotchas.
