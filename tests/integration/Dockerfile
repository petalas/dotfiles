ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE}

ARG DISTRO
ARG APT_PRIMARY_MIRROR

COPY setup-apt-mirrors.sh /usr/local/bin/setup-dotfiles-apt-mirrors
COPY tests/integration/bootstrap-container.sh /usr/local/bin/bootstrap-dotfiles-container
RUN chmod +x /usr/local/bin/setup-dotfiles-apt-mirrors /usr/local/bin/bootstrap-dotfiles-container \
    && APT_PRIMARY_MIRROR="$APT_PRIMARY_MIRROR" /usr/local/bin/setup-dotfiles-apt-mirrors \
    && DISTRO="$DISTRO" /usr/local/bin/bootstrap-dotfiles-container

COPY --chown=dotfiles:dotfiles . /home/dotfiles/repo

USER dotfiles
ENV HOME=/home/dotfiles \
    SHELL=/bin/bash \
    TERM=xterm-256color \
    DOTFILES_INTEGRATION_TEST=1
WORKDIR /home/dotfiles/repo

# A clean install validates bootstrapping and ordering. The second install
# validates that the same public entry point is idempotent.
RUN ./easy-install.sh \
    && ./tests/integration/assert-install.sh
# Keep a tmux server alive but remove TPM's server-local path to reproduce a
# machine whose tmux session predates the newly linked configuration.
RUN tmux new-session -d -s stale-config \
    && tmux set-environment -gu TMUX_PLUGIN_MANAGER_PATH \
    && ./easy-install.sh \
    && ./tests/integration/assert-install.sh
