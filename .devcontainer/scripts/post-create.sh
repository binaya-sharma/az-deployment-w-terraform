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

printf '\nContainer ready. Run az login explicitly when cloud access is needed.\n'
