#!/usr/bin/env bash

install_node_deps() {
    command -v npm >/dev/null 2>&1 || return 1
    npm install --global \
        --allow-scripts=@anthropic-ai/claude-code \
        @anthropic-ai/claude-code \
        @openai/codex \
        typescript \
        typescript-language-server </dev/null || return 1
    npm install --global --ignore-scripts \
        @earendil-works/pi-coding-agent </dev/null
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install node_deps" >&2
    exit 2
fi
