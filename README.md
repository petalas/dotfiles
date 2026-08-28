# dotfiles

Personal dotfiles and machine setup for macOS and Linux (Ubuntu / Debian / Arch).

## Fresh machine — one line

```sh
curl -fsSL https://raw.githubusercontent.com/petalas/dotfiles/main/bootstrap.sh | bash
```

Installs Git if missing, clones this repo to `~/git/dotfiles` (override with `$DOTFILES_DIR`), inspects application state, then opens the state-aware visual installation plan. A persistent **Plan → Review → Run** stepper and **Ensure present**, **Leave unchanged**, and **Remove** outcome counts show where you are and what will happen. Compact mode is the default: each colored application row shows any safely detected installed version and its current state, adds `(installed -> latest)` when package metadata reports an available update, and adds `-> desired` only when the run would change its presence. Press `v` to show/hide custody and evidence. The planning tree has dependency groups as collapsible roots and applications as leaves: use up/down to navigate, left/right to collapse/expand, `[`/`]` to filter groups, and `e`/`u`/`r` to change the selected leaf or entire selected group subtree. `Shift+E/U/R` applies an outcome to the current leaf's parent group. Disabled reasons appear only after a rejected action. Enter opens review; Enter again approves exactly what is displayed. Execution is then fully unattended and shows overall plus active-operation progress. The run count expands package-manager entries and multi-phase toolchain installers separately, so batched packages, nvm/Node, and rustup/the Rust toolchain remain visible as distinct work.

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

The most recently confirmed visual selection is saved under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/installation-plan` and becomes the next visual run's defaults. Missing or invalid saved defaults safely fall back to repository defaults. The **AI skills** group lists curated global agent skills individually, so each skill can be ensured, left unchanged, or removed with the same `e`/`u`/`r` controls as applications.

After a pull, relink managed files without downloads or package/plugin installation:

```sh
cd ~/git/dotfiles
git pull --ff-only
./link-dotfiles.sh
```

The linker is local-only, idempotent, and preserves any replaced file, directory, or symlink as `<path>.old`. To restore generated repositories, plugins, and caches separately, run `./setup-tools.sh`. When GitHub CLI authentication is available, generated tool setup also clones the private notes vault at `~/git/notes` when it is missing; an existing checkout is left untouched. Without authentication, setup prints the required `gh auth login` command and safely skips that repository.

Obsidian settings are managed per vault. When `~/git/notes` exists, the linker installs `dot/.config/obsidian/app.json` as its `.obsidian/app.json`; with the default vault selection, generated tool setup also installs it immediately after cloning a missing notes vault. Set `OBSIDIAN_VAULT_DIR` when using a different vault path. A selected vault that does not exist is skipped rather than cloned automatically.

## Per-machine intent and safe removal

The selector exposes the same dependency groups on every supported OS and reports each application's current presence/custody beside its desired post-run outcome. Foundation and the Bun, Node, and Rust applications are required and cannot be removed. Group actions only edit the reviewed desired-outcome plan; they never cross the destructive confirmation boundary or initiate execution.

**Remove** immediately cancels a pending installation when the application is already absent. Otherwise it prefers the exact package-manager registration or matching installation receipt; if exact custody is unavailable, it automatically uses the application's catalog-reviewed cleanup recipe and discloses that fallback in the confirming review. Retained dependents block prerequisite removal; package-manager dependency checks are never bypassed. Removal never deletes package-manager orphans, shared prerequisites, projects, profiles, vaults, sessions, editor configuration, browser data, Docker data, or other user data. Changed support files are retained rather than deleted.

Only wanted/not-wanted defaults are saved in `${XDG_STATE_HOME:-~/.local/state}/dotfiles/installation-plan`; Remove never persists or replays. The latest permission-restricted, non-replayable result is written to `${XDG_STATE_HOME:-~/.local/state}/dotfiles/latest-run-report`. Timestamped events and adapter stdout/stderr are captured from run start in the permission-restricted `${XDG_STATE_HOME:-~/.local/state}/dotfiles/latest-run.log`, whose path remains visible in progress.

## Run a single installer

```sh
./install rust         # install Rust toolchain
./install yazi         # install/upgrade a compatible yazi + ya pair
./install docker       # install Docker (Linux)
./install locale       # repair/reconfigure UTF-8 locale manually
./install ssh_keys     # generate ed25519 key + copy pubkey to clipboard
./install ai_skills    # install every curated global AI agent skill
./install list         # show all available installers
```

Installer modules are internal; use the dispatcher rather than executing files under `installers/` directly.

## Update an existing machine

From Zsh, run `upd`, or invoke the underlying command directly:

```sh
~/git/dotfiles/update-dotfiles
```

It fast-forwards this repository, resolves the saved installation plan, reconciles selected missing software/state, then upgrades software already present—including deselected applications and installed Pi packages. Deselection never suppresses maintenance or triggers uninstallation. Independent failures are collected and reported at the end. The complete output is saved with mode 0600 in `${XDG_STATE_HOME:-~/.local/state}/dotfiles/latest-update.log`, and failed summaries repeat that path.

Bun upgrades use an existing `GITHUB_TOKEN`, `GITHUB_ACCESS_TOKEN`, or `GH_TOKEN`, or a process-scoped token from an authenticated GitHub CLI. Without one, `upd` skips Bun and prints `gh auth login` guidance rather than consuming GitHub's anonymous API quota.

## Notes

- Ordinary users need sudo administrator access. Before selection starts, setup may request the sudo password once, installs a validated `/etc/sudoers.d/zz-dotfiles-<uid>` entry granting that user passwordless sudo, and verifies `sudo -n`. Linux root runs avoid sudo. macOS setup must run as the target non-root user because Homebrew refuses root installs; Command Line Tools must still be provisioned outside the script. After visual confirmation, child processes receive closed stdin and non-interactive package-manager settings.
- Linux setup uses process-scoped systemd idle/sleep inhibition and, when a GNOME session is available, GNOME idle/suspend inhibition. Each optional lock is used only when it can be acquired without interactive authorization, so environments such as WSL2 continue without it. Locks are released automatically when setup exits.
- As the last action of a successful visual run on Linux or macOS, setup verifies that Zsh is the account's login shell, then opens a fresh Ghostty window running that Zsh login shell. By then the default plan has linked the managed `.zshrc` and Ghostty config, so Powerlevel10k can perform any first-run setup there. Unattended runs do not launch a terminal.
- On macOS, setup runs the selected font step immediately after plan confirmation, before application installation. It installs the generated `SeaShells` Terminal profile with Hack Nerd Font Mono and the palette from `dot/.config/ghostty/config.ghostty`. A running Terminal imports the native profile itself, makes it the default and startup profile, and applies it to every open tab immediately. Regenerate the tracked profile with `/usr/bin/osascript -l JavaScript tools/generate-macos-terminal-profile.js dot/.config/ghostty/config.ghostty >dot/terminal/SeaShells.terminal`.
- Linux software comes from distro repositories whenever available. Debian/Ubuntu install `apt-fast` from its signed PPA, preconfigure it for 8 parallel downloads, and fall back to Nala or `apt-get`. Arch configures pacman for 8 parallel downloads. Official vendor APT repositories, `.deb` files, or native release binaries are fallbacks for applications absent from distro repositories. Flatpak is not used.
- Debian selects and caches its fastest archive mirror with `netselect-apt`; Arch ranks current HTTPS mirrors with Reflector (or `rankmirrors` on Arch ARM). Original source/mirror files are retained as `.dotfiles` backups. Set `DOTFILES_REFRESH_MIRRORS=1` for one setup run to rerank them.
- `catalog/` is the canonical inventory for installation steps, dependency groups, applications, prerequisites, ordered application providers, payload/support/effect actions, platform adapters, curated AI skills, and bounded cleanup recipes. `Brewfile` is a generated full compatibility artifact; regenerate it with `./tools/generate-brewfile >Brewfile`. Dependencies otherwise come from current Homebrew, npm, Cargo, GitHub releases, and official installer endpoints. There is no repository-maintained application version lockfile.
- Plan inspection snapshots each local package-manager inventory once and shows installed versions where they can be read safely. Available-update arrows use the current APT/Pacman/Homebrew metadata and a bounded npm registry check cached for six hours under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/update-cache`; unsupported or failed upstream checks remain unmarked rather than being reported as current. Set `DOTFILES_UPDATE_CACHE_MINUTES` to adjust npm cache freshness and `DOTFILES_UPDATE_CHECK_TIMEOUT_TENTHS` to adjust its default three-second cold-check limit.
- Visual mode uses the repository-owned Bubble Tea/Bubbles/Lip Gloss helper. `tools/run-install-tui` downloads a pinned release binary only after matching its SHA-256 manifest entry. If acquisition fails, it builds from source only when a compatible Go toolchain already exists; it never installs Go. Set `DOTFILES_TUI_DISPLAY=rich|plain|ascii` to force an accessibility fallback; `NO_COLOR` selects plain rendering and `TERM=dumb` selects ASCII.
- Package lists are installed in batches. After bounded retries, a failed batch is retried one package at a time so an unavailable package does not block unrelated packages. Required failures stop setup after all entries have been attempted; individual applications and language add-ons are best effort.
- The required Foundation group configures `en_US.UTF-8` during dependency installation; `./install locale` is only needed for a manual repair.
- Linux writes Ghostty's `xdg-terminal-exec` preference under `XDG_CONFIG_HOME`; macOS leaves the default-terminal choice to the user.
- `./tests/run.sh` runs deterministic tests with local fake executables instead of live package repositories or mirrors. Latest-release Yazi compatibility is a separate scheduled/manual CI integration check.
- `./tools/run-act` replays the complete Linux GitHub Actions `checks` job through Docker against the current working tree. It cannot emulate the Apple Silicon/macOS smoke job; that boundary still requires GitHub's `macos-14` runner. See [`docs/research/act-local-actions.md`](docs/research/act-local-actions.md).
- Commits are gated by ShellCheck plus Bash/Zsh syntax validation in `.githooks/pre-commit`. The linker activates it through `core.hooksPath`.
- See [`AGENTS.md`](AGENTS.md) for project structure and conventions, and [`docs/LEARNINGS.md`](docs/LEARNINGS.md) for repo-specific gotchas.
