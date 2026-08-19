# Running GitHub Actions locally with act

## Question

Can [`nektos/act`](https://github.com/nektos/act) shorten the feedback loop for this repository's GitHub Actions checks?

## Findings

`act` reads GitHub Actions workflows and executes Linux runners through the Docker Engine API. The repository's Ubuntu `checks` job works locally with a small derived runner image and the wrapper at `tools/run-act`. The wrapper runs against the current working tree, including uncommitted changes. [act overview](https://github.com/nektos/act#how-does-it-work)

The stock medium runner image is intentionally smaller than a GitHub-hosted runner and does not include every preinstalled tool. This workflow specifically needs ShellCheck and Zsh, so `tools/act.Dockerfile` adds them. The job must also run as the image's UID 1000 `ubuntu` user with passwordless sudo and `HOME=/home/ubuntu`; running the container as root changes the behavior of the bootstrap and installer tests. [act runner images](https://nektosact.com/usage/runners.html#default-runners-are-intentionally-incomplete)

`act` cannot emulate the `macos-14` job from this Debian/WSL host. Its documentation permits macOS jobs to run without Docker only when `act` itself is running on a macOS host, using a self-hosted platform mapping. Mapping `macos-14` to a Linux container or Linux host would not exercise Darwin, Apple Silicon, Apple Bash 3.2, `open`, or other macOS behavior. The hosted macOS smoke job remains the authoritative boundary for those failures. [act runners](https://nektosact.com/usage/runners.html#runners)

## Usage

Install `act` using an official method, ensure Docker is running, then execute:

```sh
./tools/run-act
```

The first run downloads the medium runner image and builds `dotfiles-act:latest`; later runs reuse Docker and Go/action caches. Additional `act` flags can be appended, for example:

```sh
./tools/run-act --dryrun
./tools/run-act --verbose
```

The underlying verified command is:

```sh
act push -j checks -W .github/workflows/lint.yml \
  -P ubuntu-latest=dotfiles-act:latest --pull=false \
  --container-options '--user 1000:1000' --env HOME=/home/ubuntu
```

## Result

On Debian 13 under WSL2 with Docker Engine 29.7.2 and act 0.2.89, the complete Linux `checks` job passes locally. Continue using GitHub's `macos-14` runner for `tests/test-macos-arm.sh`.
