#!/usr/bin/env bash
set -euo pipefail

PIXI_BIN="${PIXI_BIN:-pixi}"
NATIVE_BUILD=".temp/native-tests"

"${PIXI_BIN}" run mojo format --quiet mojo tests
git diff --exit-code -- mojo tests

mkdir -p "${NATIVE_BUILD}"
for source in node_bridge zlib_bridge tls_bridge; do
  "${PIXI_BIN}" run cc -O3 -fPIC -std=c11 \
    -I"$("${PIXI_BIN}" run printenv CONDA_PREFIX)/include" \
    -c "mojo/tsonic_node.native/${source}.c" \
    -o "${NATIVE_BUILD}/${source}.o"
done

link_arguments=(
  -Xlinker "${NATIVE_BUILD}/node_bridge.o"
  -Xlinker "${NATIVE_BUILD}/zlib_bridge.o"
  -Xlinker "${NATIVE_BUILD}/tls_bridge.o"
  -Xlinker "-L$("${PIXI_BIN}" run printenv CONDA_PREFIX)/lib"
  -Xlinker -lbrotlicommon
  -Xlinker -lbrotlidec
  -Xlinker -lbrotlienc
  -Xlinker -lcrypto
  -Xlinker -lssl
  -Xlinker -lz
)

for test_file in tests/*.mojo; do
  test_name="$(basename "${test_file}" .mojo)"
  "${PIXI_BIN}" run mojo build \
    -j 2 \
    -I mojo \
    -I ../mojo-runtime/mojo \
    -I ../mojo-js/mojo \
    "${link_arguments[@]}" \
    "${test_file}" \
    -o "${NATIVE_BUILD}/${test_name}"
  SSL_CERT_FILE="${PWD}/tests/fixtures/localhost-cert.pem" \
    "${NATIVE_BUILD}/${test_name}"
done

"${NATIVE_BUILD}/process_arguments_test" "first" "" "two words" "--flag" "😀"
