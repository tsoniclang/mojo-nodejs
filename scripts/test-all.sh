#!/usr/bin/env bash
set -uo pipefail

failed=0
if ! node --test --test-concurrency=2 nodejs/test/*.test.mjs; then failed=1; fi
if ! bash scripts/test.sh; then failed=1; fi
exit "$failed"
