#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dockerfile="$repo_dir/tests/integration/Dockerfile"

run_distro() {
    local distro="$1"
    local image distro_id target=integration
    local platform="${DOCKER_PLATFORM:-}"

    case "$distro" in
        debian)
            image="debian:trixie-slim"
            distro_id=debian
            ;;
        debian-bookworm)
            image="debian:bookworm-slim"
            distro_id=debian
            ;;
        ubuntu)
            image="ubuntu:24.04"
            distro_id=ubuntu
            ;;
        arch)
            image="archlinux:base"
            distro_id=arch
            platform="linux/amd64"
            ;;
        bootstrap)
            image="debian:trixie-slim"
            distro_id=debian
            target=bootstrap
            ;;
        *)
            echo "Usage: $0 [all|debian|debian-bookworm|ubuntu|arch|bootstrap]" >&2
            return 2
            ;;
    esac

    local build_command=(docker build --progress plain --target "$target")
    if [[ "${INTEGRATION_PULL:-1}" != 0 ]]; then
        build_command+=(--pull)
    fi
    if [[ -n "$platform" ]]; then
        build_command+=(--platform "$platform")
    else
        platform="the Docker host's native architecture"
    fi
    build_command+=(
        --build-arg "BASE_IMAGE=$image"
        --build-arg "DISTRO=$distro_id"
        --file "$dockerfile"
        --tag "dotfiles-integration:$distro"
        "$repo_dir"
    )

    echo "==> Testing $distro from $image on $platform"
    local attempt build_status=0
    for attempt in 1 2 3; do
        if "${build_command[@]}"; then
            return 0
        else
            build_status=$?
        fi
        if ((attempt < 3)); then
            echo "Docker build failed (attempt $attempt/3); retrying..." >&2
            sleep $((attempt * 5))
        fi
    done
    echo "Docker build failed after 3 attempts (status $build_status)." >&2
    return "$build_status"
}

selection="${1:-all}"
if [[ "$selection" == "all" ]]; then
    for distro in debian ubuntu arch; do
        run_distro "$distro"
    done
else
    run_distro "$selection"
fi
