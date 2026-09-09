#!/usr/bin/env bash
set -euo pipefail

PIXI_BIN="${PIXI_BIN:-pixi}"
NATIVE_BUILD=".temp/native-tests"

"${PIXI_BIN}" run mojo format --quiet mojo tests
git diff --exit-code -- mojo tests

mkdir -p "${NATIVE_BUILD}"
native_object="$("${PIXI_BIN}" run bash ../mojo-runtime/scripts/build-native.sh)"
for source in crypto_bridge crypto_catalog node_bridge zlib_bridge tls_bridge fs_watch_bridge fs_stream_bridge fs_bridge os_bridge http_client_bridge; do
  "${PIXI_BIN}" run bash -c 'exec "${CONDA_PREFIX:?}/bin/gcc" "$@"' -- -O3 -fPIC -std=c11 \
    -I"$("${PIXI_BIN}" run printenv CONDA_PREFIX)/include" \
    -c "mojo/tsonic_node.native/${source}.c" \
    -o "${NATIVE_BUILD}/${source}.o"
done

for source in url_bridge vendor/ada/ada; do
  object="${source//\//_}"
  "${PIXI_BIN}" run bash -c 'exec "${CONDA_PREFIX:?}/bin/g++" "$@"' -- -O3 -fPIC -std=c++20 \
    -c "mojo/tsonic_node.native/${source}.cpp" -o "${NATIVE_BUILD}/${object}.o"
done

link_arguments=(
  -Xlinker "$native_object"
  -Xlinker -lstdc++
  -Xlinker "${NATIVE_BUILD}/crypto_bridge.o"
  -Xlinker "${NATIVE_BUILD}/crypto_catalog.o"
  -Xlinker "${NATIVE_BUILD}/node_bridge.o"
  -Xlinker "${NATIVE_BUILD}/zlib_bridge.o"
  -Xlinker "${NATIVE_BUILD}/tls_bridge.o"
  -Xlinker "${NATIVE_BUILD}/fs_watch_bridge.o"
  -Xlinker "${NATIVE_BUILD}/fs_stream_bridge.o"
  -Xlinker "${NATIVE_BUILD}/fs_bridge.o"
  -Xlinker "${NATIVE_BUILD}/http_client_bridge.o"
  -Xlinker "${NATIVE_BUILD}/os_bridge.o"
  -Xlinker "${NATIVE_BUILD}/url_bridge.o"
  -Xlinker "${NATIVE_BUILD}/vendor_ada_ada.o"
  -Xlinker "-L$("${PIXI_BIN}" run printenv CONDA_PREFIX)/lib"
  -Xlinker -lbrotlicommon
  -Xlinker -lbrotlidec
  -Xlinker -lbrotlienc
  -Xlinker -lcrypto
  -Xlinker -lssl
  -Xlinker -lz
  -Xlinker -luv
  -Xlinker -lcurl
)

failed=0
for test_file in tests/*.mojo; do
  test_name="$(basename "${test_file}" .mojo)"
  if "${PIXI_BIN}" run mojo build \
    -j 2 \
    -I mojo \
    -I ../mojo-runtime/mojo \
    -I ../mojo-js/mojo \
    "${link_arguments[@]}" \
    "${test_file}" \
    -o "${NATIVE_BUILD}/${test_name}" && \
    SSL_CERT_FILE="${PWD}/tests/fixtures/localhost-cert.pem" "${NATIVE_BUILD}/${test_name}"; then
    printf 'PASS %s\n' "$test_file"
  else
    printf 'FAIL %s\n' "$test_file"
    failed=1
  fi
done

if ! "${NATIVE_BUILD}/process_arguments_test" "first" "" "two words" "--flag" "😀"; then failed=1; fi
exit "$failed"
