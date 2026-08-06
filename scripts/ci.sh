#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

ci_tmp_dir="$(mktemp -d)"
trap 'rm -rf "$ci_tmp_dir"' EXIT

echo "== Python tests =="
uv run pytest

echo "== Python lint and format =="
uv run ruff check .
uv run ruff format --check .

echo "== Python types =="
uv run mypy

echo "== Python wheel =="
uv build --wheel

echo "== YAML =="
uv run yamllint .github databricks.yml resources

echo "== Shell =="
shellcheck .devcontainer/scripts/post-create.sh scripts/ci.sh

echo "== Terraform format =="
terraform fmt -check -diff -recursive infrastructure

echo "== Terraform resource-group module =="
TF_DATA_DIR="$ci_tmp_dir/resource-group" terraform -chdir=infrastructure/modules/resource-group init -backend=false -input=false
TF_DATA_DIR="$ci_tmp_dir/resource-group" terraform -chdir=infrastructure/modules/resource-group validate -no-color
TF_DATA_DIR="$ci_tmp_dir/resource-group" terraform -chdir=infrastructure/modules/resource-group test -no-color

echo "== Terraform bootstrap root =="
TF_DATA_DIR="$ci_tmp_dir/bootstrap" terraform -chdir=infrastructure/bootstrap init -backend=false -input=false
TF_DATA_DIR="$ci_tmp_dir/bootstrap" terraform -chdir=infrastructure/bootstrap validate -no-color

echo "== Terraform platform root =="
TF_DATA_DIR="$ci_tmp_dir/platform" terraform -chdir=infrastructure/stacks/platform init -backend=false -input=false
TF_DATA_DIR="$ci_tmp_dir/platform" terraform -chdir=infrastructure/stacks/platform validate -no-color

echo "All CI quality gates passed."
