#!/usr/bin/env bash
set -euo pipefail

PIXI_BIN="${PIXI_BIN:-pixi}"

"${PIXI_BIN}" run mojo format --quiet mojo tests
git diff --exit-code -- mojo tests

for test_file in tests/*.mojo; do
  "${PIXI_BIN}" run mojo run -I mojo -I ../mojo-runtime/mojo "${test_file}"
done
