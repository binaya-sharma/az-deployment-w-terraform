#!/usr/bin/env bash
set -uo pipefail

required_extensions=(
    openai.chatgpt
    eamodio.gitlens
    github.vscode-github-actions
)

if ! command -v code >/dev/null 2>&1; then
    printf "Warning: VS Code CLI is unavailable; Dev Container metadata will install editor extensions.\n" >&2
    exit 0
fi

installed_extensions="$(code --list-extensions 2>/dev/null | tr "[:upper:]" "[:lower:]")"
for extension_id in "${required_extensions[@]}"; do
    if ! grep -Fqx "${extension_id}" <<< "${installed_extensions}"; then
        printf "Installing required VS Code extension %s\n" "${extension_id}"
        if ! code --install-extension "${extension_id}" --force; then
            printf "Warning: could not install VS Code extension %s; retry after reloading VS Code.\n" "${extension_id}" >&2
        fi
    fi
done
