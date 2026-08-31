#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TSONIC_ROOT="$(cd "$REPO_ROOT/../tsonic" && pwd -P)"

if [[ ! -f "$REPO_ROOT/../tsonic-mojo/dist/index.d.ts" ]]; then
  printf 'Missing prebuilt Mojo target output: %s\n' "$REPO_ROOT/../tsonic-mojo/dist/index.d.ts" >&2
  exit 1
fi

node "$REPO_ROOT/scripts/clean-dist.mjs"
"$TSONIC_ROOT/scripts/build/tsgo-project.sh" "$REPO_ROOT/tsconfig.json" --pretty false
