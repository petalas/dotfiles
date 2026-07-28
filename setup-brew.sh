#!/usr/bin/env bash
set -e

if command -v brew >/dev/null 2>&1; then
    echo "Homebrew is already installed."
else
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_bin=/opt/homebrew/bin/brew
elif [[ -x /usr/local/bin/brew ]]; then
    brew_bin=/usr/local/bin/brew
else
    echo "Homebrew installation did not produce a brew executable." >&2
    return 1 2>/dev/null || exit 1
fi

eval "$("$brew_bin" shellenv)"
profile="$HOME/.zprofile"
shellenv_line="eval \"\$($brew_bin shellenv)\""
touch "$profile"
grep -Fqx "$shellenv_line" "$profile" || printf '%s\n' "$shellenv_line" >>"$profile"
