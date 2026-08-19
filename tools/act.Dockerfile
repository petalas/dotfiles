FROM catthehacker/ubuntu:act-latest

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends shellcheck zsh \
    && printf 'ubuntu ALL=(ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/ubuntu-act \
    && chmod 0440 /etc/sudoers.d/ubuntu-act \
    && rm -rf /var/lib/apt/lists/*
