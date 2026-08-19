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

## Apple Bash 3.2 cannot combine nounset with empty catalog arrays

- Under Apple Bash 3.2, expanding a declared but empty array such as `"${step_ids[@]}"` still raises `unbound variable` when `set -u` is active. The live Homebrew adapter smoke reached the first catalog row and exposed this before any removal.
- `lib/install-plan` keeps errexit and pipefail but disables nounset only on Bash versions older than 4. External catalog/protocol fields remain explicitly validated. Keep the macOS live adapter job because Linux Bash cannot reproduce this shell-runtime boundary.

## Pacman removal does not accept the APT-style `--` separator

- The catalog already validates package names and invokes pacman without a shell, so an option separator is unnecessary. `pacman -R --noconfirm -- package` was interpreted incorrectly and reported the installed package as an unavailable target in the disposable Arch adapter smoke.
- Use `pacman -R --noconfirm package`. Keep the scheduled Arch container smoke because fake adapters cannot catch package-manager CLI grammar differences.

## Frozen catalog fixtures need a fixed collation locale

- Catalog parity fixtures are sorted text. `en_US.UTF-8` orders `python@3.14` before `python-setuptools`, while the GitHub runner's C locale orders the hyphen first; a silent `cmp` then fails only in CI.
- `tests/test-install-catalog.sh` exports `LC_ALL=C`, and every sorted frozen fixture must be generated under that same locale.

## Debian availability should use guest-native providers, not host assumptions

- Debian 13 carries many applications that were accidentally macOS-only in the catalog (`fastfetch`, `glab`, `git-delta`, `hyperfine`, Poppler tools, GIMP, VLC, OpenSCAD, and others). Treat absence of a platform row as a catalog gap, not evidence that upstream lacks Linux support.
- Prefer Debian package registrations when trixie owns the package. For `dust` and `bottom`, use the projects' documented Cargo packages and declare the Rust application prerequisite, preserving exact custody through Cargo. First-party direct providers are also valid when they have verified artifacts, same-run command activation, custody receipts, bounded cleanup, and deterministic tests; uv and Zed now establish that boundary.
- WSL2 supports Debian GUI packages through WSLg, but it does not make VPNs, emulators, hardware tools, game clients, or host desktop utilities safe guest defaults. Zed can be installed from its verified Linux release, but its Vulkan requirement remains a runtime capability rather than catalog availability. Keep the other hardware- or host-sensitive applications unavailable until a specific WSL policy and receipt-aware adapter exist. See `docs/research/debian-unavailable-applications.md`.

## Required language toolchains need managed providers and same-run activation

- Debian's `nodejs`/`npm` and `cargo`/`rustc` packages can satisfy a command-presence probe while being too old for the current npm and Cargo applications. This caused global npm permission failures under `/usr/local`, Pi's Node version rejection, and Cargo packages rejecting the system compiler.
- Node is therefore owned by the pinned nvm installer and tracks nvm's `node` alias (the latest release); Rust is owned by rustup and tracks the stable channel. Keep the native package rows out of every platform catalog so one application has one toolchain owner.
- User-scoped installers must activate their bin directories in the current catalog process, not only modify a future login shell. The dependent npm/Cargo actions run immediately afterward. Keep nvm loading in `dot/zshrc`, Cargo's bin directory in `PATH`, and the Bun installer's same-run PATH refresh covered by `tests/test-managed-toolchains.sh`.

## Platform catalog schema changes must include language-addon readers

- `lib/install-plan` is not the only reader of `catalog/platforms/*.tsv`: `installers/install_node_deps.sh` and `installers/install_rust_deps.sh` read those rows directly to restore npm and Cargo add-ons.
- When provider and action-role columns were added, catalog parity and plan tests still passed while both addon installers silently selected zero packages. Keep `tests/test-language-deps.sh` in the full migration gate and search for direct platform-catalog readers before changing columns.
- `tests/test-language-deps.sh` executes the direct reader for the runner's detected OS. Expectations for Debian-only Cargo rows must be conditional; otherwise they pass in a Debian development VM and fail on the Ubuntu CI runner before exercising retries.

## Aggregate custody cannot authorize an exact removal method

- An application can have several possible providers (for example APT plus a direct installer). Reporting only `custody=managed` loses which mechanism actually established custody and can make preparation remove every candidate package identity.
- Inspection artifacts therefore include one aggregate `observation` plus exact `mechanism` rows. Remove prefers those exact mechanism rows and expands the broader cleanup recipe only when no exact mechanism is available. Do not prepare both sets speculatively: a package identity often appears in both the install action and cleanup recipe, and executing the duplicate removes it once then falsely fails on the second attempt.
- A direct-install receipt may be created only when the command was absent before a successful installer run or when an existing valid receipt is being refreshed. A successful no-op installer over a pre-existing unreceipted command must not claim custody.
- Receipt version discovery must not execute an arbitrary installed target. Bitwarden's Debian launcher prints display diagnostics and starts Electron for `--version`; piping that through `head` closes stdout after the first diagnostic and crashes Electron's logger with `write EPIPE`. Read versions from package metadata for packaged desktop applications, invoke `--version` only for explicitly known CLI installers, and capture complete CLI output before selecting its first line.
- Prepared-run application arrays contain only platform-available applications, while catalog arrays include unavailable entries. Their numeric indices diverge at the first unavailable application. Never pass a prepared-run index into catalog inspection; cross that boundary by stable application ID. Otherwise adapters can succeed but post-operation verification inspects neighboring applications, producing a false exit 1 and a shifted run report.

## Release helper hashes must disable Go VCS stamping

- `-trimpath` and an empty build ID are not enough for reproducible Go binaries when building inside a Git checkout. Go also embeds VCS revision and dirty-state metadata by default, so an artifact built before commit has a different SHA-256 after the same source is committed.
- Build release helpers and verify `catalog/tui-releases.tsv` with `go build -buildvcs=false -trimpath -ldflags='-s -w -buildid='`. The release-manifest test intentionally rebuilds every target after commit so this cannot silently recur.

## A terminal TUI must treat height and stage context as part of its interface

- Tracking only terminal width made the first state-aware selector render dozens of application-card lines below an 80×24 viewport. It also rendered all four lanes as columns until 90 cells, where labels and evidence were already unreadable.
- Every interactive view now consumes both dimensions, reserves fixed rows for the Plan/Review/Run stepper, all four outcome names, and controls, and windows the variable application/review content around the cursor. Tiny terminals show a bounded resize view rather than overflowing.
- The `choose` command must honor its own “Enter opens review” help text. Exiting directly from Plan made the separate prepared-run review feel like an unrelated second UI. Keep the state-transition and 80×24 bounds tests at the model seam.
- Successful interactive inspection uses the alternate screen and leaves no static “run settled” report behind before Plan opens. Redirected runs still print their final report for automation and diagnostics.
- Compact rows should carry state text independently of color: rich mode colors the application/current state and any changed desired state, while plain and ASCII modes retain the same `current -> desired` wording. Once rows contain ANSI styling, truncate with the ANSI-aware `x/ansi.Truncate`; rune slicing can cut an escape sequence and corrupt the rest of the terminal.
- Outcome buckets are summaries, not list-navigation surfaces. Moving an application into another filtered lane after `e/u/r` destroys spatial context just when the user needs to verify the new scheduled state. Keep one catalog-order, group-filtered planning tree; update the selected node and outcome counts in place.
- A pre-preparation choice review and a prepared-run review look like the same screen but require two Enter presses. Choice collection should leave Plan immediately; only the prepared artifact has exact/cleanup methods and blockers, so it is the sole meaningful review and confirmation boundary.
- The catalog's real tree is dependency-group root → application leaves. Application prerequisites form a graph with shared nodes and must not be presented as tree parentage. Emit canonical group labels in the TUI selection artifact; deriving labels from IDs loses names such as “Terminal & shell.”
- Persistent disabled-reason rows make the tree jump even before an action is attempted. Keep compact rows one line and replace the fixed summary/status line with the rejection reason only after an invalid `e/u/r` action.
- Exact removal and cleanup fallback are execution methods, not separate user intents. Expose one Remove outcome: prefer exact custody-backed mechanisms, automatically select a curated cleanup recipe only when exact removal is unavailable, and disclose fallback targets in the confirming review. Keep accepting legacy `force` artifacts without writing new ones.
- The prepared review itself is the destructive confirmation boundary. Requiring application labels and `REMOVE <count>` after showing the digest-bound artifact adds friction without adding information or stronger binding; Enter approves exactly the displayed artifact, Esc cancels, and execution remains unattended.
- Removal capability gates apply only when machine state might actually be changed. An absent application already satisfies Remove: `r` must cancel `absent -> present` even though inspection correctly reports exact and cleanup capabilities as disabled, and preparation must emit no removal adapter for that no-op. Otherwise group counts can change while absent children incorrectly remain scheduled for installation.
- A trusted test plan skips live post-operation inspection; it does not suppress unrelated Ensure adapters in the same prepared run. Tests for absent-removal no-ops must assert that no `remove`/`force` adapter was invoked, not that the entire adapter log is absent.
- A few happy-path transition examples are insufficient because availability, four presence values, three desired outcomes, and two removal capabilities are independent axes. Keep a literal 24-row availability × presence × outcome matrix at the interactive render seam, plus a 16-case presence × exact/cleanup capability matrix and separate required/retained/group tests. Literal expected transitions avoid reproducing the implementation algorithm inside the test.

## GitHub Action runtimes come from each action, not setup-node

- `actions/checkout@v4` declares `using: node20` in its own `action.yml`. GitHub-hosted runners may temporarily force that action onto Node 24, but emit a deprecation warning on every job.
- `actions/setup-node` would not change another action's internal runtime. Upgrade the action itself: `actions/checkout@v7` and the existing `actions/setup-go@v6` both declare Node 24. Major action refs intentionally receive compatible fixes within that major; the workflow does not need a separate project Node runtime.

## Bubble Tea progress needs consumed terminal replies and a dedicated event channel

- Bubble Tea v2 sends mode 2026/2027 capability queries even when `WithInput(nil)` disables the reader. Ghostty replies were left in canonical input, echoed as `^[[?2026;2$y`, and later appeared at the shell prompt. For progress-only views, pass Bubble Tea a conservative renderer environment with terminal-query triggers removed; the child command still receives the real environment. Keep the Python PTY emulator test, which answers the queries and detects unread replies exactly as a terminal does.
- Engine events cannot share stdout with adapter diagnostics. A command can emit a tab-separated line beginning with `event` and be mistaken for a malformed protocol record. The helper now gives the engine a dedicated inherited file descriptor 3; stdout and stderr are logs only. Direct engine callers retain stdout events when no descriptor is declared.
- Build each event as one shell string and write it once so a logical record cannot be split across writes. Initialize that shell string with ANSI-C quoting (`$'event\t1'`), not ordinary single quotes, which preserve `\t` literally. Rejected records include a safely quoted value in the error.
- The progress helper reads the event descriptor, stdout, and stderr concurrently. Sending the completion message as soon as `cmd.Wait()` returns can overtake queued scanner messages, leaving the final view at `0/N` even though execution settled. Wait for all three scanners before sending completion; the deterministic TUI test uses a fast command intentionally so this ordering regression remains visible.
- Closed stdin does not prevent an unattended child from reopening `/dev/tty`. A live run stalled in `yazi --version`: Yazi opened the progress pane's TTY, initialized terminal-query workers, and waited while Bubble Tea was also consuming replies. Start the engine in a new session with no controlling TTY and signal its process group for cancellation. The PTY regression child explicitly attempts to open `/dev/tty`.
- Do not mask terminal deadlocks with a guessed installer timeout, and do not generically retry arbitrary adapters after unknown partial effects. Preserve adapter exit codes and post-operation inspection; use the existing bounded retry/repair logic only where the package or language installer owns idempotent retry semantics.
- Progress keeps only five diagnostics on screen, which is insufficient for a live stall. Mirror timestamped event/stdout/stderr records into mode-0600 `latest-run.log` from process start, include start/finish records, and show the path in the progress view. Do not log the environment or authorization material.

## Brewfile environment gates are not a selection interface

- `brew bundle` evaluates the Brewfile as Ruby, but Homebrew sanitises arbitrary environment variables before evaluation. This made historical `SKIP_*` gates unreliable unless wrappers translated them to `HOMEBREW_*` names.
- Installation-plan records now own group and application selection on every platform. `Brewfile` is a generated full compatibility artifact, while catalog reconciliation materializes a selected temporary Brewfile.
- Do not reintroduce environment-variable selection gates in `Brewfile`; they create a second ownership surface and do not apply consistently to direct and wrapped Homebrew runs.

---

## Homebrew 6 requires explicit third-party tap trust

- Symptom: `brew bundle` aborts with `Refusing to load formula ... from untrusted tap`, and `set -e` prevents every later installer from running.
- Cause: Homebrew 6 treats non-official taps as executable, untrusted code by default. A short formula name can resolve to an already-tapped third-party repository, but Homebrew will not evaluate it without explicit trust.
- Fix: declare formula-scoped trust in the Brewfile, e.g. `brew "wix-incubator/brew/applesimutils", trusted: true`. Do not disable tap trust globally or trust a whole tap when only one formula is needed.
- `brew-deps.sh` first runs one ordinary `brew bundle`. If reconciliation fails, `lib/homebrew.sh` retries active entries with one-entry Brewfiles copied exactly from the original, preserving options such as formula-scoped `trusted: true`. Homebrew itself is required, while individual non-Homebrew language tools remain best effort.
- Do not run `brew bundle cleanup` from unattended setup. Without `--force`, Homebrew 6 hard-codes a confirmation prompt when it finds drift; with `--force`, it actually uninstalls software. Keep cleanup as an explicit manual operation.

---

## Homebrew upgrades must isolate broken packages

- Symptom: `brew bundle` fetched several upgrades, then one cask checksum mismatch made the whole command fail and prevented `upd` from reaching `brew upgrade`. In July 2026, T3 Code 0.0.29's GitHub release asset had been replaced after the Homebrew cask recorded its SHA-256, so the downloaded file no longer matched Homebrew's expected checksum.
- Never bypass a checksum mismatch or patch the cask automatically. It can indicate either an unsafe download or an upstream release that was mutated; Homebrew or the vendor must publish corrected metadata.
- `brew bundle` upgrades declared entries by default. Use `--no-upgrade` to make it a reconciliation step, with a fallback that retries only missing entries individually if the batch fails.
- The interactive `upd` shell function uses `lib/homebrew.sh` to isolate upgrades so one broken package does not hide later updates.

---

## Vite+ npm shims prompt on TTYs

- Vite+ places its `npm` shim before npm in `PATH`. After `npm install -g`, the shim checks whether each package binary is reachable and prompts once per invocation before linking it into `~/.vite-plus/bin`.
- The shim's non-interactive behavior is safe when stdin is closed, so global Node installs redirect stdin from `/dev/null`.
- npm 12 blocks unapproved lifecycle scripts, so a global package that needs its postinstall must be allowlisted with `--allow-scripts=<package>`. No current package needs it: Claude Code was the only one, and it now comes from the `claude-code` Homebrew cask on macOS and `install_claude_code` on Linux.

---

## Bash/Zsh shared libraries must avoid Zsh readonly parameter names

- Symptom: sourcing `lib/nvim-sync.sh` from the zsh `upd` function failed with `_nvim_sync_prune_legacy_lazy_lock:14: read-only variable: status`.
- Cause: `status` is a readonly special parameter in zsh, so a Bash-style `local status` declaration fails when the shared file is sourced by zsh.
- Fix: avoid zsh special parameter names in files advertised as safe for Bash and Zsh; use specific names such as `lazy_lock_status` instead.

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

## Managed nested Git checkouts need explicit parent allowances

- `~/.oh-my-zsh/themes/powerlevel10k` is a separate Git checkout inside the Oh My Zsh checkout. Oh My Zsh does not ignore that path, so its parent reports the valid nested repository as `?? themes/powerlevel10k/`.
- A blanket clean-worktree check therefore rejects a correctly configured machine. Do not weaken the check for arbitrary untracked files: `configure-zsh.sh` explicitly names the one allowed nested path and expected origin, and `lib/git-sync.sh` verifies that nested checkout is clean before updating the parent.
- Keep the tracked parent directory in test fixtures; otherwise Git collapses the status to `?? themes/` and the fixture does not reproduce the real state.

---

## The nvim config is a separate repo (cloned, not symlinked) — keep it pulled

- `~/.config/nvim` is **not** part of this dotfiles repo and is **not** symlinked. `setup-tools.sh` clones it from `petalas/nvim` (a kickstart.nvim fork); `link-dotfiles.sh` is deliberately local-only. Edit and commit nvim config **in that repo**, not under `dot/` — adding it to `dot/.config/nvim/` would duplicate a repo that manages itself.
- **Drift trap:** the clone used to be set up once and never updated, while `upd` kept updating the Neovim binary and plugins. A config left far behind the plugins it configures breaks when a plugin changes its API (this is how a Treesitter breakage happened).
- **Fork synchronization:** `setup-tools.sh` clones `petalas/nvim@custom`; `lib/nvim-sync.sh` then keeps the fork's `master` branch as a clean mirror of `nvim-lua/kickstart.nvim@master` and merges upstream into `custom`. Use ordinary merge commits rather than repeatedly rebasing and force-pushing: every machine can then fast-forward safely. The helper refuses dirty/diverged worktrees, aborts conflicts, smoke-tests clean merges, and pushes only successful merges. For the HTTPS fork remote, it verifies `gh` authentication and injects `gh auth git-credential` only into its network commands; an interactive run starts browser authentication when needed, while unattended runs fail with the exact login command instead of prompting for a GitHub username. Do not use `gh auth setup-git` here: `~/.gitconfig` is symlinked to the tracked `dot/gitconfig`, so that command dirties this repository and records a machine-specific `gh` path. `sync-nvim` runs it directly and `upd` runs it before plugin updates.
- GitHub repository identity is host + owner + repository, not transport spelling. Managed-origin checks accept HTTPS, SCP-style SSH, and `ssh://git@github.com` for the same identity while still rejecting another owner/repository. Keep anonymous HTTPS as the no-prerequisite fresh-clone path; preserve existing SSH origins. GitHub account/SSH-key onboarding is a separate human action for writable operations and must not become a prerequisite for public bootstrap or start inside unattended execution.
- **Editor/config compatibility is one managed boundary.** Commit `b6e42f4` fixed a Kickstart API break by installing Neovim nightly and selecting it ahead of distro packages; the package-management refactor in `628fe67` accidentally removed both guarantees and restored Debian's stale `/usr/bin/nvim`. Native package presence is not sufficient because Kickstart master can adopt nightly APIs before apt, pacman, or stable Homebrew. Every platform now uses the official nightly archive at `~/.local/share/nvim-nightly`, verifies the SHA-256 digest published in GitHub's release-asset metadata, and atomically selects `~/.local/bin/nvim`. Keep native Neovim packages out of platform payload actions; legacy registrations remain removal mechanisms only.
- **Do not trust Neovim's process status for command-line Lua errors.** Neovim 0.10 returned exit 0 after `E5113`/`E5108`, causing plugin reconciliation to print “already up to date.” Sync resolves the managed nightly explicitly instead of relying on inherited `PATH`, preflights `vim.pack`/`PackChanged`, and wraps plugin Lua calls so failures execute `:cquit`. A successful direct installer may receive a custody receipt when the selected command path or digest demonstrably changes; an unchanged pre-existing command still must not receive one.
- **Plugin synchronization:** current Kickstart uses Neovim's built-in `vim.pack`, not lazy.nvim. `upd` force-updates managed plugins, waits for asynchronous Treesitter parser updates, then commits and pushes the resulting tracked `nvim-pack-lock.json`. This keeps plugin revisions reproducible across machines.
- **Legacy lazy.nvim lockfile:** after the vim.pack migration, upstream stopped ignoring `lazy-lock.json`. Any stale untracked `lazy-lock.json` left from the old lazy.nvim config then becomes visible as a dirty worktree and makes `upd` refuse to sync. `lib/nvim-sync.sh` now prunes an untracked `lazy-lock.json` only when the repo tracks `nvim-pack-lock.json`; unknown untracked files still block the sync.
- **Headless Treesitter repairs must wait for the asynchronous task.** A command such as `nvim --headless '+TSUpdate diff' +qa` can exit after the download starts but before compilation and installation finish, leaving the old parser and errors such as `Invalid node type "special"`. For a scripted repair, wait explicitly: `nvim --headless '+lua require("nvim-treesitter").update({"diff"}):wait(300000)' +qa`.

---

## Numeric sudoers users must escape the leading hash

- A sudoers user ID is written as `#<uid>`, but at the beginning of a sudoers line an unescaped `#` is treated as a comment. `visudo -cf` still reports that file as valid because comments are valid syntax, so syntax validation alone does not catch the missing authorization rule.
- Write the identity as `\#<uid>`, invalidate the authentication timestamp with `sudo -k`, then verify `sudo -n true`. An immediate check can produce a false positive while the temporary sudo timestamp is active.
- Sudoers uses the last matching rule's tag. Name the managed include `zz-dotfiles-<uid>` so it sorts after ordinary per-user and cloud-init files; otherwise a later `PASSWD` rule can silently override `NOPASSWD`.

---

## apt-fast must be configured before its package is installed

- `apt-fast` is not assumed to exist in Debian/Ubuntu's configured repositories. Add its signed Launchpad PPA through a deb822 source and install `apt-fast` with `aria2` in one bootstrap transaction; fall back to Nala or `apt-get` if that setup fails.
- Pipe `apt-fast/maxdownloads`, `apt-fast/dlflag`, and `apt-fast/aptmanager` into `debconf-set-selections` before the non-interactive install. Editing `/etc/apt-fast.conf` afterward does not answer the package's installation prompts.
- Package managers get the full package list first. After bounded retries, `run_resilient_batch` retries each item independently, which is intentionally less clever than recursive splitting and still prevents one unavailable package from blocking unrelated packages.

---

## Mirror selectors should rank mirrors, not replace source definitions

- `netselect-apt` emits a legacy one-suite `sources.list`, even on Debian releases that use deb822 `.sources` files. Installing that output directly duplicates repositories and can discard updates, security suites, components, and third-party sources.
- `lib/packages.sh` uses `netselect-apt` only to discover the fastest Debian archive URI, then rewrites that URI in the existing `.list` and `.sources` files. Security and third-party repositories remain untouched, and original files are backed up under `/etc/apt/.dotfiles-backups/`.
- Mirror ranking is cached because rerating on every idempotent setup is slow and can create needless source drift. Use `DOTFILES_REFRESH_MIRRORS=1` to force a new Debian `netselect-apt` or Arch Reflector/rankmirrors run.
- The package helper is shared with zsh. Keep it compatible with both Bash and Zsh, and avoid readonly zsh parameter names such as `status`.
- Package-manager tests must use local fake executables. Clean-container installs measure the current mirror and network conditions, not deterministic package-management behavior.
- Tests for root setup entry points must inject a fake catalog engine or run a copied fixture. Never invoke `setup-deps.sh` from a test before its execution seam is substituted: it immediately performs live package reconciliation on the host.

---

## Login-shell changes need a fresh terminal, not a reboot

- `chsh` updates the account database immediately, but a child installer cannot rewrite the parent shell or the `SHELL` exported by an already-running desktop login session. Waiting for a reboot only appeared to make the change itself take effect because rebooting created a fresh login environment.
- The catalog adapter must remain non-interactive because it runs in the detached execution phase. After a successful visual run, `easy-install.sh` re-reads the account's verified login shell and launches Ghostty with that Zsh path explicitly as a login shell. This avoids both the stale parent `SHELL` value and ambiguity in GUI-launcher environment propagation while opening the linked `.zshrc` in the configured terminal. Unattended and redirected runs must still terminate without launching a terminal.
- Linux installation runs use standard process-scoped inhibitors rather than changing global desktop settings or simulating input. The logind inhibitor protects against OS idle sleep; GNOME's session inhibitor additionally prevents its independent idle lock and is used only when its session API is reachable. Keep the final Ghostty launch in the outer entry-point process so both child-scoped inhibitors are released before the terminal starts; otherwise they remain held for the entire terminal session.
- Debian 13's `gnome-session-inhibit` manually recognizes `--app-id`, `--reason`, and `--inhibit` only when each option and value are separate arguments. The GNU-style `--app-id=value` form is treated as the child command and fails with `Failed to execute --app-id=...`. Keep the fake inhibitor's parser strict enough to reject equals-form options; a `--list` probe alone does not exercise invocation grammar.
- A background `nohup` launched as the PTY-owning installer exits can lose a race with terminal teardown before the child starts. Use `setsid -f` for the Linux Ghostty launch when available, with `nohup` only as a compatibility fallback, and keep the PTY regression test polling the launch marker.

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
- Installer modules are not standalone executables. Source them through `installers/source_installers.sh` (or invoke the public `./install NAME` dispatcher) so the explicit platform, download, and package APIs are available. Focused tests must use the loader too; sourcing one installer directly recreates hidden dependencies.
- A helper called as `helper || return` executes in a conditional context where Bash can suppress `errexit` throughout the helper, including a subshell with `set -e`. Do not rely on an intermediate failing command to stop an installer transaction: join required operations with explicit `if ! command` checks (or `&&`) and test a late failure to prove the previous installation is restored.

---

## TPM's CLI uses state from the running tmux server

- Symptom: `bin/install_plugins` prints `unknown variable: TMUX_PLUGIN_MANAGER_PATH`, says TPM is not configured in `tmux.conf`, and aborts even though the linked config contains both `@plugin` declarations and the final TPM `run` line.
- Cause: TPM parses plugin declarations from the config file, but obtains its installation path from the tmux server's global environment. If `easy-install.sh` is run while an older tmux server is alive, that server may never have loaded the newly linked config and therefore lacks the variable.
- Fix: after linking the config and cloning TPM, `link-dotfiles.sh` starts or connects to the tmux server and sources `~/.tmux.conf` before invoking TPM's command-line installer. The second Docker integration pass deliberately removes the variable from a live server to cover this state.
- `tests/test-setup-tools.sh` must not inherit whether the host happens to provide tmux. Its fixture supplies a fake tmux command, linked config, and the TPM executable that a real clone would contain; otherwise the test skips locally when tmux is absent but fails on GitHub runners after entering an incomplete fake checkout.

---

## Yazi's `ya` and `yazi` binaries are a versioned pair

- Symptom: `easy-install.sh` reaches Yazi package restoration after TPM, then aborts with `error: unrecognized subcommand 'pkg'`.
- Cause: Yazi 25.4.8 exposes the legacy `ya pack` interface; `ya pkg` arrived in 25.5.28. The old Rust dependency installer treated the presence of any `yazi-fm` crate as sufficient, so rerunning setup preserved an incompatible `ya`/`yazi` pair after the managed config moved to `ya pkg` and `[mgr]` syntax.
- A later `yazi-build` 26.8.15 regression showed why a successful meta-installer exit is not sufficient. Its crates.io build script cloned the upstream `shipped` tag, which still pointed to 26.5.6; that older nested installer ignored its child Cargo exit status. The outer install therefore succeeded with only a `yazi-build` executable while both `ya` and `yazi` remained missing. In the detached execution session, the nested build-script diagnostics also fell back to Cargo's captured build output and were not visible in the run log.
- Fix: Yazi has its own ordered installer using the latest official GitHub release archive and the SHA-256 digest from GitHub's release metadata. It atomically selects the matching `ya`/`yazi` pair under `~/.local`, verifies equal versions and `ya pkg`, and removes the obsolete Cargo meta-package during migration.
- Current `[filetype].rules` match paths with `url`, not `name`; use `url = "*"` and `url = "*/"` for the file and directory fallbacks. The latest stable Yazi rejects the old `name` form and falls back to its preset theme.
- `dot/.config/yazi/package.toml` is canonical. Restore it with `ya pkg install`; do not re-add each dependency, which can rewrite the lockfile instead of installing its pinned revisions.
- The Docker profile intentionally skips language toolchains, so `tests/test-yazi.sh` provides the fast deterministic regression seam for legacy migration, release asset/digest validation, multiline version parsing, post-install verification, and lockfile restoration. `tests/test-yazi-config.sh` downloads the latest stable official binary as a scheduled/manual integration check and rejects config syntax that release no longer accepts.
