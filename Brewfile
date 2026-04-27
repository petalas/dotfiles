# Brewfile — consumed by `brew bundle` from brew-deps.sh.
#
# Per-machine subsetting (via brew-deps.sh):
#   SKIP_GAMING=1 SKIP_CAD=1 SKIP_MOBILE=1 ./brew-deps.sh
# (brew-deps.sh re-exports these as HOMEBREW_SKIP_* because Homebrew
#  sanitises non-HOMEBREW_ env vars before the Brewfile is evaluated.
#  If you invoke `brew bundle` directly, use HOMEBREW_SKIP_* here.)
#
# Skip individual entries by commenting out the line.
# Find drift (installed but not declared here):
#   brew bundle cleanup --file=Brewfile

# --- Core CLI ---
brew "aria2"
brew "bash"
brew "bc"
brew "bind"
brew "btop"
brew "fastfetch"
brew "gcc"
brew "htop"
brew "iperf3"
brew "mosh"
brew "mtr"
brew "nmap"
brew "rsync"
brew "tmux"
brew "watch"
brew "wget"

# --- Modern CLI ---
brew "bottom"
brew "dust"
brew "eza"
brew "fd"
brew "fzf"
brew "jq"
brew "procs"
brew "sevenzip"
brew "xh"

# --- Dev tools ---
brew "cmake"
brew "gh"
brew "git-delta"
brew "gnupg"
brew "hyperfine"
brew "lazydocker"
brew "lazygit"
brew "luarocks"
brew "mas"
brew "neovim"
brew "shellcheck"

# --- Languages ---
brew "elixir"
brew "nvm"
brew "python@3.14"
brew "python-setuptools"
brew "uv"

# --- Media tooling ---
brew "ffmpeg"
brew "imagemagick"
brew "media-info"
brew "poppler"
brew "yt-dlp"

# --- Terminal ---
cask "kitty"

# --- Browsers / comms ---
cask "discord"
cask "google-chrome"
cask "slack"
cask "whatsapp"

# --- macOS utilities ---
cask "grandperspective"
cask "jordanbaird-ice"
cask "keepingyouawake"
cask "keka"
cask "raycast"
cask "rectangle"
cask "shottr"
cask "stats"

# --- Productivity / password / VPN / sync ---
cask "bitwarden"
cask "private-internet-access"
cask "syncthing-app"
brew "tailscale"
cask "tailscale-app"

# --- Creative / media apps ---
cask "capcut"
cask "gimp"
cask "qbittorrent"
cask "spotify"
cask "vlc"

# --- Editors / IDEs / DB tools ---
cask "codex-app"
cask "dbeaver-community"
cask "sublime-text"
cask "t3-code"
cask "visual-studio-code"
cask "zed"

# --- Containers ---
cask "docker-desktop"

# --- AI ---
cask "lm-studio"

# --- Mobile dev (fastlane, maestro, Java runtime) ---
unless ENV["HOMEBREW_SKIP_MOBILE"]
  tap "mobile-dev-inc/tap"
  brew "applesimutils"
  brew "cocoapods"
  brew "fastlane"
  brew "mobile-dev-inc/tap/maestro"
  cask "android-commandlinetools"
  cask "android-platform-tools"
  cask "android-studio"
  cask "temurin@17"
end

# --- 3D printing / CAD ---
unless ENV["HOMEBREW_SKIP_CAD"]
  cask "bambu-studio"
  cask "openscad@snapshot"
end

# --- Gaming / streaming ---
unless ENV["HOMEBREW_SKIP_GAMING"]
  cask "parsec"
  cask "steam"
end
