#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dockerfile="$repo_dir/tests/integration/Dockerfile"

run_distro() {
    local distro="$1"
    local image
    local platform=""
    local apt_primary_mirror="${APT_PRIMARY_MIRROR:-}"
    local apt_security_mirror="${APT_SECURITY_MIRROR:-}"

    case "$distro" in
        debian) image="debian:bookworm-slim" ;;
        ubuntu)
            image="ubuntu:24.04"
            ;;
        arch)
            image="archlinux:base"
            platform="linux/amd64"
            ;;
        *)
            echo "Usage: $0 [all|debian|ubuntu|arch]" >&2
            return 2
            ;;
    esac

    local build_command=(docker build --progress plain)
    if [[ -n "$platform" ]]; then
        build_command+=(--platform "$platform")
    else
        platform="the Docker host's native architecture"
    fi
    if [[ -n "$apt_primary_mirror" ]]; then
        build_command+=(--build-arg "APT_PRIMARY_MIRROR=$apt_primary_mirror")
    fi
    if [[ -n "$apt_security_mirror" ]]; then
        build_command+=(--build-arg "APT_SECURITY_MIRROR=$apt_security_mirror")
    fi

    echo "==> Testing $distro from $image on $platform"
    "${build_command[@]}" \
        --build-arg "BASE_IMAGE=$image" \
        --build-arg "DISTRO=$distro" \
        --file "$dockerfile" \
        --tag "dotfiles-integration:$distro" \
        "$repo_dir"
}

selection="${1:-all}"
if [[ "$selection" == "all" ]]; then
    for distro in debian ubuntu arch; do
        run_distro "$distro"
    done
else
    run_distro "$selection"
fi
