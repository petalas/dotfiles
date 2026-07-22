#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dockerfile="$repo_dir/tests/integration/Dockerfile"

select_fastest_ubuntu_mirror() {
    local codename="noble"
    local country_code=""
    local geoip_response
    local candidate elapsed best_mirror="" best_time="" seen=""

    if ! command -v curl >/dev/null 2>&1; then
        return 1
    fi

    geoip_response=$(curl --silent --show-error --fail --max-time 3 \
        https://geoip.ubuntu.com/lookup 2>/dev/null || true)
    country_code=$(printf '%s\n' "$geoip_response" |
        sed -n 's:.*<CountryCode>\([A-Za-z][A-Za-z]\)</CountryCode>.*:\1:p' |
        tr '[:upper:]' '[:lower:]')

    local candidates=(
        "http://azure.archive.ubuntu.com/ubuntu"
        "http://archive.ubuntu.com/ubuntu"
    )
    if [[ "$country_code" =~ ^[a-z][a-z]$ ]]; then
        candidates=("http://$country_code.archive.ubuntu.com/ubuntu" "${candidates[@]}")
    fi

    echo "==> Benchmarking official Ubuntu mirrors" >&2
    for candidate in "${candidates[@]}"; do
        if [[ " $seen " == *" $candidate "* ]]; then
            continue
        fi
        seen="$seen $candidate"

        if elapsed=$(curl --silent --show-error --fail --location \
            --connect-timeout 2 --max-time 5 --output /dev/null \
            --write-out '%{time_total}' \
            "$candidate/dists/$codename/InRelease"); then
            printf '    %ss  %s\n' "$elapsed" "$candidate" >&2
            if [[ -z "$best_time" ]] ||
                awk -v candidate_time="$elapsed" -v current_time="$best_time" \
                    'BEGIN { exit !(candidate_time < current_time) }'; then
                best_time="$elapsed"
                best_mirror="$candidate"
            fi
        else
            printf '    unavailable  %s\n' "$candidate" >&2
        fi
    done

    [[ -n "$best_mirror" ]] || return 1
    printf '==> Selected Ubuntu mirror: %s (%ss)\n' "$best_mirror" "$best_time" >&2
    printf '%s\n' "$best_mirror"
}

run_distro() {
    local distro="$1"
    local image
    local platform=""
    local apt_primary_mirror=""

    case "$distro" in
        debian) image="debian:bookworm-slim" ;;
        ubuntu)
            image="ubuntu:24.04"
            apt_primary_mirror=$(select_fastest_ubuntu_mirror || true)
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
