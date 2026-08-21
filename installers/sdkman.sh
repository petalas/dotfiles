#!/usr/bin/env bash

_sdkman_enable_auto_answer() {
    local config=$SDKMAN_DIR/etc/config

    [[ -f "$config" ]] || return 0
    if grep -q '^sdkman_auto_answer=' "$config"; then
        sed -i.bak 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/' "$config" || return 1
        rm -f "$config.bak"
    else
        printf '\nsdkman_auto_answer=true\n' >>"$config"
    fi
}

sdkman_candidate_operations() {
    local candidate=$1 label=$2

    printf '%s\t%s\n' sdkman 'Ensure SDKMAN'
    printf '%s\tEnsure %s\n' "$candidate" "$label"
}

_ensure_sdkman() {
    export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
    if [[ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
        echo "Installing SDKMAN..."
        run_downloaded_script bash 'https://get.sdkman.io?ci=true&rcupdate=false' || return 1
    fi

    [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] || {
        echo "SDKMAN did not install its loader at $SDKMAN_DIR/bin/sdkman-init.sh" >&2
        return 1
    }
    _sdkman_enable_auto_answer
}

_install_sdkman_candidate() {
    local candidate=$1 executable=$2 expected result=0 nounset_enabled=0

    # SDKMAN reads unset internal variables and is incompatible with nounset.
    # Keep the caller's setting intact outside the SDKMAN load and command.
    case $- in *u*) nounset_enabled=1; set +u ;; esac
    # SDKMAN is a shell function and candidate activation changes this process.
    # shellcheck disable=SC1091
    . "$SDKMAN_DIR/bin/sdkman-init.sh" || result=$?
    if ((result == 0)); then sdk install "$candidate" || result=$?; fi
    if ((nounset_enabled == 1)); then set -u; fi
    ((result == 0)) || return "$result"
    hash -r 2>/dev/null || true

    expected=$SDKMAN_DIR/candidates/$candidate/current/bin/$executable
    [[ "$(command -v "$executable" 2>/dev/null || true)" == "$expected" ]] || {
        echo "The SDKMAN-managed $candidate executable is not active" >&2
        return 1
    }
}

install_sdkman_candidate() {
    local candidate=$1 executable=$2 label=$3

    run_installer_operation sdkman 'Ensure SDKMAN' _ensure_sdkman || return 1
    run_installer_operation "$candidate" "Ensure $label" \
        _install_sdkman_candidate "$candidate" "$executable"
}
