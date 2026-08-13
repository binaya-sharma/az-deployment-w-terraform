#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"
cd "${repo_root}"

# Create the project-local environment. Never authenticate or deploy here.
uv sync --extra dev

uv run python --version
uv --version
terraform version | head -n 1
az version --query '"azure-cli"' --output tsv
databricks version
java -version

# Dev Container metadata normally installs these before this script runs. Verify and
# repair the essential editor extensions because Marketplace installation can be skipped
# or interrupted during a rebuild.
required_extensions=(
    openai.chatgpt
    eamodio.gitlens
    github.vscode-github-actions
)

if [[ "${CI:-}" == "true" ]]; then
    printf "Skipping editor extension repair in headless CI.\n"
elif command -v code >/dev/null 2>&1; then
    installed_extensions="$(code --list-extensions 2>/dev/null | tr "[:upper:]" "[:lower:]")"
    for extension_id in "${required_extensions[@]}"; do
        if ! grep -Fqx "${extension_id}" <<< "${installed_extensions}"; then
            printf "Installing required VS Code extension %s\n" "${extension_id}"
            if ! code --install-extension "${extension_id}" --force; then
                printf "Warning: could not install VS Code extension %s; VS Code will retry from Dev Container metadata.\n" "${extension_id}" >&2
            fi
        fi
    done
else
    printf "Warning: VS Code CLI is unavailable; Dev Container metadata will install editor extensions.\n" >&2
fi

printf '\nContainer ready. Run az login explicitly when cloud access is needed.\n'
