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
- Fix: either use `HOMEBREW_SKIP_GAMING` directly in the Brewfile, or translate in the wrapper script before invoking `brew bundle`. `brew-deps.sh` does the translation so the user-facing API stays as plain `SKIP_*`. The `upd` shell function invokes `brew bundle` directly, so persistent per-machine skips used by both paths must use the `HOMEBREW_SKIP_*` names.

---

## Homebrew `reinstall` does not accept `--HEAD`

- Symptom: `upd` fails in `installers/install_neovim.sh` with `Error: invalid option: --HEAD` when trying to convert an existing stable `neovim` install to nightly.
- Cause: `brew install neovim --HEAD` is valid, but `brew reinstall neovim --HEAD` is not accepted by Homebrew. A linked stable keg also blocks a direct HEAD install with Homebrew's own instruction to run `brew unlink neovim` first.
- Fix: when stable Neovim is already installed on macOS, `install_neovim` unlinks it, runs `brew install neovim --HEAD`, then links the HEAD keg with `brew link --overwrite --HEAD neovim`. If the HEAD install fails, it attempts to relink the previous Homebrew install.

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

---

## kitty font families should use kitty syntax, not shell quotes

- Symptom: `kitty --debug-font-fallback` says a font is not found even though Font Book and `fc-match` can resolve it.
- Cause: shell-style single quotes in `kitty.conf` are not the right way to disambiguate a font family with spaces. Also, kitty may list only terminal-usable mono families, so a Font Book family like `Iosevka NF` can exist while kitty accepts `Iosevka Nerd Font Mono`.
- Fix: use kitty's documented font selector syntax, e.g. `font_family family="Iosevka Nerd Font Mono"`, and verify with `kitty --debug-font-fallback` or `kitten choose-fonts`.

---

## The nvim config is a separate repo (cloned, not symlinked) — keep it pulled

- `~/.config/nvim` is **not** part of this dotfiles repo and is **not** symlinked. `link-dotfiles.sh` clones it from `petalas/nvim` (a kickstart.nvim fork). Edit and commit nvim config **in that repo**, not under `dot/` — adding it to `dot/.config/nvim/` would duplicate a repo that manages itself.
- **Drift trap:** the clone used to be set up once and never updated, while `upd` kept updating the neovim binary and the lazy.nvim plugins. A config left far behind the plugins it configures breaks when a plugin changes its API (this is how a treesitter breakage happened — lazy installed a new major version of a plugin while the stale config still called the old API).
- **Fix:** `lib/git-sync.sh` provides `clone_or_ff` / `git_ff` (clone if missing, else fast-forward; non-destructive — skips a dirty or diverged worktree). `link-dotfiles.sh` uses it for the nvim repo and the oh-my-zsh theme/plugins, and `upd` fast-forwards the nvim config **before** syncing plugins so plugins always match the current specs.
- **Reconciling a diverged machine** (stale local commits vs. a rebased remote): the remote tracking branch is canonical. After confirming it contains your customizations, `git -C ~/.config/nvim fetch && git -C ~/.config/nvim reset --hard @{u}`; the reflog recovers anything if needed.

---

## Mosh needs the client locale before `.zshrc` runs remotely

- Symptom: `mosh-server` reports that a client-supplied UTF-8 locale is unavailable, falls back to US-ASCII, and exits even though Mosh is installed on both machines.
- Cause: Mosh starts its server through a non-interactive SSH command, so changing the remote `.zshrc` alone is too late. Any locale forwarded by the client must already be generated on the server.
- Fix: `easy-install.sh` configures the locale before the general dependency phase. The locale setup installs/generates `en_US.UTF-8` and selects it as the system `LANG`; the targeted `./install locale` repair command also bootstraps Debian's `locales` package when necessary. `dot/zshrc` uses the same `LANG` when available, falls back to an installed locale during bootstrap, and clears `LC_ALL`/`LC_CTYPE` overrides so SSH and Mosh forward a valid locale.

---

## Sourced detection helpers must return success explicitly

- Symptom: every `./install NAME` command exits silently on Linux while working on macOS.
- Cause: `install` uses `set -euo pipefail` and sources `source_installers.sh`. `detect_os` both treated the optional `VERSION_CODENAME` field as mandatory and ended with an ArchARM normalization check joined by `&&`; either false status could trigger `set -e` before dispatch.
- Fix: optional `/etc/os-release` fields tolerate absence, and detection helpers explicitly `return 0` after identifying a supported OS. Do not let an optional lookup or final conditional determine a sourced setup file's status.

---

## Test the public installer without pretending Docker is a desktop host

- A disposable locale-only container proved the immediate Mosh fix, but it did not protect the ordering or idempotency of `easy-install.sh`.
- The checked-in suite under `tests/integration/` starts from clean Debian, Ubuntu, and Arch images and invokes `./easy-install.sh` twice. Assertions cover the generated locale, Mosh, tmux mouse mode and plugin installation, zsh startup, external config clones, and the managed symlinks.
- `DOTFILES_INTEGRATION_TEST=1` is set only by the Dockerfile. It keeps the real orchestration, package manager, locale setup, shell configuration, and linking stages while limiting Linux packages to portable core dependencies and skipping fonts, GUI apps, services, SDKs, and AUR packages that have no useful container behavior.
- Even the container's one-package bootstrap can hit transient mirror or DNS failures before repository retry logic exists, so `bootstrap-container.sh` gives APT and pacman three bounded attempts.
- Configure APT mirrors before the integration container's first bootstrap refresh: Debian uses its official `deb.debian.org` CDN, and amd64 Ubuntu normally uses Canonical's requester-local `mirrors.ubuntu.com/mirrors.txt` service with APT-managed fallback. GitHub-hosted Ubuntu runners are in Azure, so CI selects `azure.archive.ubuntu.com` deterministically instead of maintaining a noisy network benchmark. Local amd64 builds use the official mirror list; non-amd64 builds keep their image defaults. Primary and security overrides are separate so normal machine installs retain `security.ubuntu.com` and do not wait for downstream mirrors to synchronize.
- Although the mirror setup executes on Linux hosts, its fixture test also runs under macOS. Rewrite source files through a temporary file instead of relying on incompatible GNU/BSD `sed -i` syntax.
- Do not use that profile for a normal machine install: its intentionally reduced dependency set is a test boundary, not a lightweight install mode.

---

## TPM's CLI uses state from the running tmux server

- Symptom: `bin/install_plugins` prints `unknown variable: TMUX_PLUGIN_MANAGER_PATH`, says TPM is not configured in `tmux.conf`, and aborts even though the linked config contains both `@plugin` declarations and the final TPM `run` line.
- Cause: TPM parses plugin declarations from the config file, but obtains its installation path from the tmux server's global environment. If `easy-install.sh` is run while an older tmux server is alive, that server may never have loaded the newly linked config and therefore lacks the variable.
- Fix: after linking the config and cloning TPM, `link-dotfiles.sh` starts or connects to the tmux server and sources `~/.tmux.conf` before invoking TPM's command-line installer. The second Docker integration pass deliberately removes the variable from a live server to cover this state.
