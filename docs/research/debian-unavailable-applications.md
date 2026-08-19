# Debian/WSL application availability

## Question

Which applications currently reported as unavailable by the visual installer can be installed safely on Debian 13, and which should remain unavailable inside a Debian WSL2 guest?

## Environment and method

The observed machine is Debian 13 (trixie) on WSL2. The current inspection artifact reported 52 unavailable applications. Package candidates were checked against the machine's configured APT metadata and then verified against Debian's first-party trixie package pages. Non-Debian methods were checked against the application's own installation documentation or source repository.

Microsoft documents that Linux GUI applications are supported under WSL2 through WSLg, but this does not make the Debian guest equivalent to the Windows host or a complete Linux desktop. GUI applications packaged by Debian can reasonably be offered; VPNs, hardware-accelerated tools, emulators, game clients, and host-integration utilities need an explicit WSL policy rather than being installed merely because a Linux build exists. [Microsoft: Run Linux GUI apps with WSL](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps)

## Providers safe to add now

These are native Debian packages in trixie and fit the existing APT adapter and dependency/removal safety model:

| Application | Debian provider | Primary source |
|---|---|---|
| DNS tools | `bind9-dnsutils` | [Debian package](https://packages.debian.org/trixie/bind9-dnsutils) |
| fastfetch | `fastfetch` | [Debian package](https://packages.debian.org/trixie/fastfetch) |
| mtr | `mtr-tiny` | [Debian package](https://packages.debian.org/trixie/mtr-tiny) |
| 7-Zip | `7zip` | [Debian package](https://packages.debian.org/trixie/7zip) |
| watch | `procps` | [Debian package](https://packages.debian.org/trixie/procps) |
| GitLab CLI | `glab` | [Debian package](https://packages.debian.org/trixie/glab) |
| git-delta | `git-delta` | [Debian package](https://packages.debian.org/trixie/git-delta) |
| hyperfine | `hyperfine` | [Debian package](https://packages.debian.org/trixie/hyperfine) |
| Elixir | `elixir` | [Debian package](https://packages.debian.org/trixie/elixir) |
| LuaRocks | `luarocks` | [Debian package](https://packages.debian.org/trixie/luarocks) |
| Syncthing | `syncthing` | [Debian package](https://packages.debian.org/trixie/syncthing) |
| Poppler | `poppler-utils` | [Debian package](https://packages.debian.org/trixie/poppler-utils) |
| yt-dlp | `yt-dlp` | [Debian package](https://packages.debian.org/trixie/yt-dlp) |
| GIMP | `gimp` | [Debian package](https://packages.debian.org/trixie/gimp) |
| qBittorrent | `qbittorrent` | [Debian package](https://packages.debian.org/trixie/qbittorrent) |
| VLC | `vlc` | [Debian package](https://packages.debian.org/trixie/vlc) |
| OpenSCAD | `openscad` | [Debian package](https://packages.debian.org/trixie/openscad) |

`dust` and `bottom` should use the existing Cargo adapter. Their projects explicitly document `cargo install du-dust` and `cargo install bottom --locked`; this also gives exact Cargo custody and avoids inventing a direct installer. [dust README](https://github.com/bootandy/dust#cargo), [bottom README](https://github.com/ClementTsang/bottom#installation)

Two first-party direct providers also fit the catalog now:

- **uv** documents its standalone installer for Linux, supports `UV_INSTALL_DIR` and `UV_NO_MODIFY_PATH`, verifies the downloaded release inside the upstream script, and installs only `uv` and `uvx` into the selected executable directory. The catalog wrapper selects `~/.local/bin`, suppresses shell-profile edits, verifies both commands, and records its own custody receipt. Uninstallation removes the two binaries and upstream installer receipt while retaining caches, managed Python versions, tools, and configuration as user data. [Astral installation docs](https://docs.astral.sh/uv/getting-started/installation/), [installer options](https://docs.astral.sh/uv/reference/installer/), and [storage reference](https://docs.astral.sh/uv/reference/storage/)
- **Zed** officially supports Linux x86_64 and aarch64 with glibc 2.31+ and 2.35+ respectively. Its release assets expose SHA-256 digests in first-party GitHub release metadata, so the catalog downloads and verifies the stable tarball, installs `~/.local/zed.app`, and creates the documented command symlink and desktop entry. Zed requires a Vulkan-capable GPU; catalog availability means the provider can install it, not that every WSL graphics stack can run it. Removal retains settings and application data. [Zed Linux docs](https://zed.dev/docs/linux), [latest release metadata](https://api.github.com/repos/zed-industries/zed/releases/latest)

## Linux-supported, but needing a curated adapter before enablement

The following have first-party Linux distribution instructions or artifacts, but cannot safely be represented by a bare APT/Cargo row today. They need repository-key handling or a direct installer with a validated receipt, bounded cleanup recipe, and deterministic tests:

- **DBeaver**, **Sublime Text**, and **Slack** — official Linux packages/repositories exist. [DBeaver downloads](https://dbeaver.io/download/), [Sublime Linux repositories](https://www.sublimetext.com/docs/linux_repositories.html), [Slack Linux download](https://slack.com/downloads/linux)
- **Private Internet Access**, **Tailscale**, and **Spotify** — official Linux methods exist, but service/repository setup and WSL networking or desktop behavior need explicit policy. [PIA Linux](https://www.privateinternetaccess.com/download/linux-vpn), [Tailscale Linux](https://tailscale.com/download/linux), [Spotify Linux](https://www.spotify.com/download/linux/)
- **LM Studio**, **Maestro**, **Android command-line tools**, **Android Studio**, and **Temurin 17** — official Linux distributions exist; each needs a versioned artifact/receipt adapter. Android emulator support must not be inferred from command-line-tool support under WSL. [LM Studio](https://lmstudio.ai/download), [Maestro Linux](https://docs.maestro.dev/getting-started/installing-maestro/linux), [Android Studio](https://developer.android.com/studio), [Adoptium Linux](https://adoptium.net/installation/linux/)
- **Bundletool** and **Fastlane** are cross-platform command-line projects, but need dedicated Java/Ruby installation and receipt semantics before enablement. [Bundletool releases](https://github.com/google/bundletool/releases), [Fastlane setup](https://docs.fastlane.tools/getting-started/android/setup/)
- **Bambu Studio**, **Parsec**, and **Steam** publish Linux software, but are poor automatic WSL guest defaults because they depend on desktop, graphics, USB, streaming, or game-runtime integration. Prefer the Windows-host application unless a separate WSL policy is intentionally added. [Bambu Studio downloads](https://bambulab.com/en/download/studio), [Parsec downloads](https://parsec.app/downloads), [Steam](https://store.steampowered.com/about/)

T3 Code could not be assigned a Linux provider from a first-party installation source and remains unavailable pending authoritative coverage.

## Keep unavailable in the Debian guest

These are platform-specific products or have no authoritative Linux client suitable for this catalog:

- GrandPerspective, Ice, KeepingYouAwake, Keka, `mas`, Rectangle, Shottr, and Stats are macOS utilities.
- Apple simulator utilities require Apple's simulator/Xcode environment. CocoaPods can run Ruby code on Linux, but the catalog application exists for Apple build workflows and must not imply that iOS builds are available in WSL.
- WhatsApp and CapCut do not provide a supported Linux desktop package in their first-party download surfaces; use their web or Windows-host versions.
- Raycast and the Codex desktop app remain unavailable until their first-party download surfaces publish a supported Linux artifact.

## Decision

Enable the native Debian/Cargo set plus the receipt-aware uv and Zed direct providers now. Keep all other entries visibly unavailable rather than deriving installers from PATH, third-party repositories, Flatpak, AppImage aggregators, or unofficial wrappers. Follow-up adapters can move items from the deferred list only after they satisfy the same custody, receipt, cleanup, and unattended-execution contracts as existing direct installers.
