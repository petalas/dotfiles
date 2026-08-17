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

After a pull, relink managed files without downloads or package/plugin installation:

```sh
cd ~/git/dotfiles
git pull --ff-only
./link-dotfiles.sh
```

The linker is local-only, idempotent, and preserves any replaced file, directory, or symlink as `<path>.old`. To restore generated repositories, plugins, and caches separately, run `./setup-tools.sh`.

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

Installer modules are internal; use the dispatcher rather than executing files under `installers/` directly.

## Update an existing machine

From Zsh, run `upd`, or invoke the underlying command directly:

```sh
~/git/dotfiles/update-dotfiles
```

It fast-forwards and relinks this repository, then updates system packages, language tools, Neovim configuration/plugins, and global skills. Independent failures are collected and reported at the end.

## Notes

- Setup is non-interactive and requires `sudo -n` for ordinary users before it starts. Linux root runs avoid sudo; macOS setup must run as the target non-root user because Homebrew refuses root installs. Provision administrator access and macOS Command Line Tools outside the script.
- Linux software comes from distro repositories whenever available. Debian/Ubuntu install `apt-fast` from its signed PPA, preconfigure it for 8 parallel downloads, and fall back to Nala or `apt-get`. Arch configures pacman for 8 parallel downloads. Official vendor APT repositories, `.deb` files, or native release binaries are fallbacks for applications absent from distro repositories. Flatpak is not used.
- Debian selects and caches its fastest archive mirror with `netselect-apt`; Arch ranks current HTTPS mirrors with Reflector (or `rankmirrors` on Arch ARM). Original source/mirror files are retained as `.dotfiles` backups. Set `DOTFILES_REFRESH_MIRRORS=1` for one setup run to rerank them.
- Dependencies otherwise come from current Homebrew, npm, Cargo, GitHub releases, and official installer endpoints. There is no repository-maintained version lockfile.
- Package lists are installed in batches. After bounded retries, a failed batch is retried one package at a time so an unavailable package does not block unrelated packages. Required failures stop setup after all entries have been attempted; individual applications and language add-ons are best effort.
- `easy-install.sh` configures `en_US.UTF-8` before installing the remaining dependencies; `./install locale` is only needed for a manual repair.
- Linux writes Ghostty's `xdg-terminal-exec` preference under `XDG_CONFIG_HOME`; macOS leaves the default-terminal choice to the user.
- `./tests/run.sh` runs deterministic tests with local fake executables instead of live package repositories or mirrors. Latest-release Yazi compatibility is a separate scheduled/manual CI integration check.
- Commits are gated by ShellCheck plus Bash/Zsh syntax validation in `.githooks/pre-commit`. The linker activates it through `core.hooksPath`.
- See [`AGENTS.md`](AGENTS.md) for project structure and conventions, and [`docs/LEARNINGS.md`](docs/LEARNINGS.md) for repo-specific gotchas.
