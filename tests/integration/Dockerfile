ARG BASE_IMAGE=debian:trixie-slim

FROM alpine:3.22 AS repository-fixture
RUN apk add --no-cache git
COPY . /source
RUN rm -rf /source/.git \
    && git -C /source init --initial-branch=main \
    && git -C /source config user.name "Dotfiles Integration" \
    && git -C /source config user.email "integration@example.invalid" \
    && git -C /source add --all \
    && git -C /source commit -m "Integration fixture" \
    && git clone --bare /source /dotfiles.git

FROM ${BASE_IMAGE} AS test-base

ARG DISTRO
ARG APT_PRIMARY_MIRROR
ARG APT_SECURITY_MIRROR

COPY setup-apt-mirrors.sh /usr/local/bin/setup-dotfiles-apt-mirrors
COPY tests/integration/bootstrap-container.sh /usr/local/bin/bootstrap-dotfiles-container
COPY bootstrap.sh /usr/local/bin/bootstrap-dotfiles
COPY tests/integration/test-bootstrap.sh /usr/local/bin/test-dotfiles-bootstrap
RUN chmod +x \
        /usr/local/bin/setup-dotfiles-apt-mirrors \
        /usr/local/bin/bootstrap-dotfiles-container \
        /usr/local/bin/bootstrap-dotfiles \
        /usr/local/bin/test-dotfiles-bootstrap \
    && /usr/local/bin/setup-dotfiles-apt-mirrors \
    && DISTRO="$DISTRO" /usr/local/bin/bootstrap-dotfiles-container

ENV HOME=/home/dotfiles \
    SHELL=/bin/bash \
    TERM=xterm-256color \
    DOTFILES_INTEGRATION_TEST=1

FROM test-base AS bootstrap
COPY --from=repository-fixture --chown=dotfiles:dotfiles /dotfiles.git /home/dotfiles/dotfiles.git
USER dotfiles
WORKDIR /home/dotfiles
RUN DOTFILES_DIR=/home/dotfiles/bootstrap-repo \
    DOTFILES_REPO_URL=file:///home/dotfiles/dotfiles.git \
    DOTFILES_PREFLIGHT_URL=file:///home/dotfiles/dotfiles.git/HEAD \
    /usr/local/bin/test-dotfiles-bootstrap

FROM test-base AS integration
COPY --chown=dotfiles:dotfiles . /home/dotfiles/repo
USER dotfiles
WORKDIR /home/dotfiles/repo

# A clean install validates bootstrapping and ordering. Record the resulting
# managed state so the second pass must be content- and package-idempotent.
RUN ./tests/integration/run-install.sh first \
    && ./tests/integration/state-manifest.sh record /tmp/dotfiles-first-state

# Keep a tmux server alive but remove TPM's server-local path to reproduce a
# machine whose tmux session predates the newly linked configuration.
RUN tmux new-session -d -s stale-config \
    && tmux set-environment -gu TMUX_PLUGIN_MANAGER_PATH \
    && EXPECT_STALE_TMUX_RELOAD=1 ./tests/integration/run-install.sh second \
    && ./tests/integration/state-manifest.sh compare /tmp/dotfiles-first-state
