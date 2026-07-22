ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE}

ARG DISTRO

COPY tests/integration/bootstrap-container.sh /usr/local/bin/bootstrap-dotfiles-container
RUN chmod +x /usr/local/bin/bootstrap-dotfiles-container \
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
RUN ./easy-install.sh \
    && ./tests/integration/assert-install.sh
