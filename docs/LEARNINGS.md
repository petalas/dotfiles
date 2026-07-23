# Learnings

Gotchas and insights discovered while maintaining these dotfiles.

---

## Zsh substitution replacements preserve unnecessary backslashes

- In zsh `${value//pattern/replacement}`, a backslash needed to quote the pattern is not also needed before an ordinary `%` in the replacement.
- Using `${value//\%244F/\%8F}` produced a literal `\%8F` in the Powerlevel10k frame. Use `${value//\%244F/%8F}` so the prompt receives `%8F` without a visible backslash.

---

## Pi Codex fast-mode benchmarks need visible-token timing and socket cleanup

- `gpt-5.6-sol` advertises Codex's `fast` speed tier as request `service_tier: "priority"`; this is the correct mapping, not a reversed toggle.
- Pi's `usage.output` includes hidden reasoning tokens. For the footer's user-visible TPS, subtract `usage.reasoning` and measure from the first `text_start` through the last `text_end`. Measuring all output from stream start mixes reasoning/prefill latency into TPS and can make a faster tier look slower.
- Short responses are noisy, and prompt-cache state can dominate comparisons. The first manual fast test after `/reload` had a full cache miss while the standard test immediately reused the prompt cache, so those two numbers were not comparable.
- Standalone Codex WebSocket benchmarks must call `closeOpenAICodexWebSocketSessions()` when finished; otherwise Pi's reusable connection timer keeps Node alive for several minutes and looks like a hung benchmark.

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

## Homebrew 6 requires explicit third-party tap trust

- Symptom: `brew bundle` aborts with `Refusing to load formula ... from untrusted tap`, and `set -e` prevents every later installer from running.
- Cause: Homebrew 6 treats non-official taps as executable, untrusted code by default. A short formula name can resolve to an already-tapped third-party repository, but Homebrew will not evaluate it without explicit trust.
- Fix: declare formula-scoped trust in the Brewfile, e.g. `brew "wix-incubator/brew/applesimutils", trusted: true`. Do not disable tap trust globally or trust a whole tap when only one formula is needed.
- Failure boundary: `brew-deps.sh` treats Homebrew itself and `jq` as hard prerequisites because the required dotfile-linking stage consumes them. Brewfile apps and language-package batches are best-effort: collect failures, skip only their dependants, continue unrelated work, and print a warning summary. If Homebrew's batch fetch fails, snapshot the installed taps, formulae, and casks once, then retry only missing evaluated entries individually. Replaying installed entries is both slow and noisy because `brew install` emits an `already installed and up-to-date` warning for each one. Guard expected failures explicitly rather than removing `set -e` wholesale.
- Do not run `brew bundle cleanup` from unattended setup. Without `--force`, Homebrew 6 hard-codes a confirmation prompt when it finds drift; with `--force`, it actually uninstalls software. Keep cleanup as an explicit manual operation.

---

## Vite+ npm shims prompt on TTYs, and SDKMAN must stay inside modern Bash

- Vite+ places its `npm` shim before nvm's npm in `PATH`. After `npm install -g`, the shim checks whether each package binary is reachable and prompts once per invocation before linking it into `~/.vite-plus/bin`.
- The shim's non-interactive behavior is already safe: when stdin is not a TTY, it creates the links automatically. Global Node dependency installs therefore redirect stdin from `/dev/null` instead of setting `CI` for the entire machine setup.
- npm 12 blocks unapproved lifecycle scripts. `@anthropic-ai/claude-code` needs its postinstall to install the native binary, so its global install explicitly allows scripts for that package only.
- macOS still launches root scripts with Apple Bash 3.2 even after Homebrew installs Bash 5. SDKMAN's path helpers use Bash 4+ `${name^^}` expansion; sourcing them into the Bash 3 parent is a fatal expansion error that cannot be caught by an ordinary optional-stage wrapper.
- After sudo is available, `easy-install.sh` bootstraps Homebrew, updates or installs Homebrew Bash, verifies it is Bash 4+, prepends its directory to `PATH`, and re-executes itself under that binary before general dependency setup. Both steps matter: re-exec changes the current interpreter, while the `PATH` change makes later `#!/usr/bin/env bash` child scripts use Homebrew Bash too.
- `install_sdkman` may download SDKMAN with Homebrew Bash, but it never sources SDKMAN into an incompatible parent. SDKMAN package installation is delegated to a Bash 4+ subprocess instead, with `sdkman_auto_answer=true` and closed stdin so older SDKMAN configs cannot prompt.

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
- **Drift trap:** the clone used to be set up once and never updated, while `upd` kept updating the Neovim binary and plugins. A config left far behind the plugins it configures breaks when a plugin changes its API (this is how a Treesitter breakage happened).
- **Fork synchronization:** `link-dotfiles.sh` clones `petalas/nvim@custom`; `lib/nvim-sync.sh` then keeps the fork's `master` branch as a clean mirror of `nvim-lua/kickstart.nvim@master` and merges upstream into `custom`. Use ordinary merge commits rather than repeatedly rebasing and force-pushing: every machine can then fast-forward safely. The helper refuses dirty/diverged worktrees, aborts conflicts, smoke-tests clean merges, and pushes only successful merges. `sync-nvim` runs it directly and `upd` runs it before plugin updates.
- **Plugin synchronization:** current Kickstart uses Neovim's built-in `vim.pack`, not lazy.nvim. `upd` force-updates managed plugins, waits for asynchronous Treesitter parser updates, then commits and pushes the resulting tracked `nvim-pack-lock.json`. This keeps plugin revisions reproducible across machines.
- **Headless Treesitter repairs must wait for the asynchronous task.** A command such as `nvim --headless '+TSUpdate diff' +qa` can exit after the download starts but before compilation and installation finish, leaving the old parser and errors such as `Invalid node type "special"`. For a scripted repair, wait explicitly: `nvim --headless '+lua require("nvim-treesitter").update({"diff"}):wait(300000)' +qa`.

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
- Sourced installers also inherit `set -u` from callers such as `./install` and focused tests. Optional globals (notably terminal colors when an installer is sourced directly) must use default-safe expansion such as `${yellow:-}` rather than assuming the central loader ran.

---

## Test the public installer without pretending Docker is a desktop host

- A disposable locale-only container proved the immediate Mosh fix, but it did not protect the ordering or idempotency of `easy-install.sh`.
- The checked-in suite under `tests/integration/` starts from clean Debian, Ubuntu, and Arch images and invokes `./easy-install.sh` twice. Assertions cover the generated locale, Mosh, tmux mouse mode and plugin installation, zsh startup, external config clones, and the managed symlinks.
- `DOTFILES_INTEGRATION_TEST=1` is set only by the Dockerfile. It keeps the real orchestration, package manager, locale setup, shell configuration, and linking stages while limiting Linux packages to portable core dependencies and skipping fonts, GUI apps, services, SDKs, and AUR packages that have no useful container behavior.
- Even the container's one-package bootstrap can hit transient mirror or DNS failures before repository retry logic exists, so `bootstrap-container.sh` gives APT and pacman three bounded attempts.
- Configure APT mirrors before the integration container's first bootstrap refresh: Debian uses its official `deb.debian.org` CDN, and amd64 Ubuntu normally uses Canonical's requester-local `mirrors.ubuntu.com/mirrors.txt` service with APT-managed fallback. GitHub-hosted Ubuntu runners are in Azure, so the workflow supplies `azure.archive.ubuntu.com` explicitly instead of putting provider detection or a noisy network benchmark in the reusable integration runner. Local amd64 builds use the official mirror list; non-amd64 builds keep their image defaults. Primary and security overrides are separate so normal machine installs retain `security.ubuntu.com` and do not wait for downstream mirrors to synchronize.
- Although the mirror setup executes on Linux hosts, its fixture test also runs under macOS. Rewrite source files through a temporary file instead of relying on incompatible GNU/BSD `sed -i` syntax.
- Do not use that profile for a normal machine install: its intentionally reduced dependency set is a test boundary, not a lightweight install mode.

---

## TPM's CLI uses state from the running tmux server

- Symptom: `bin/install_plugins` prints `unknown variable: TMUX_PLUGIN_MANAGER_PATH`, says TPM is not configured in `tmux.conf`, and aborts even though the linked config contains both `@plugin` declarations and the final TPM `run` line.
- Cause: TPM parses plugin declarations from the config file, but obtains its installation path from the tmux server's global environment. If `easy-install.sh` is run while an older tmux server is alive, that server may never have loaded the newly linked config and therefore lacks the variable.
- Fix: after linking the config and cloning TPM, `link-dotfiles.sh` starts or connects to the tmux server and sources `~/.tmux.conf` before invoking TPM's command-line installer. The second Docker integration pass deliberately removes the variable from a live server to cover this state.

---

## Yazi's `ya` and `yazi` binaries are a versioned pair

- Symptom: `easy-install.sh` reaches Yazi package restoration after TPM, then aborts with `error: unrecognized subcommand 'pkg'`.
- Cause: Yazi 25.4.8 exposes the legacy `ya pack` interface; `ya pkg` arrived in 25.5.28. The old Rust dependency installer treated the presence of any `yazi-fm` crate as sufficient, so rerunning setup preserved an incompatible `ya`/`yazi` pair after the managed config moved to `ya pkg` and `[mgr]` syntax.
- Fix: Yazi has its own ordered installer after Rust and the other Cargo tools. It checks crates.io for a newer `yazi-build`, repairs with `--force` when the child binaries are missing, stale, or mismatched, and verifies that `ya`/`yazi` versions match and `ya pkg` exists before setup continues.
- Current `[filetype].rules` match paths with `url`, not `name`; use `url = "*"` and `url = "*/"` for the file and directory fallbacks. The latest stable Yazi rejects the old `name` form and falls back to its preset theme.
- `dot/.config/yazi/package.toml` is canonical. Restore it with `ya pkg install`; do not re-add each dependency, which can rewrite the lockfile instead of installing its pinned revisions.
- The Docker profile intentionally skips language toolchains, so `tests/test-yazi.sh` provides the fast regression seam for legacy migration, forced repair, post-install verification, and lockfile restoration. `tests/test-yazi-config.sh` downloads the latest stable official binary and rejects config syntax that release no longer accepts.
