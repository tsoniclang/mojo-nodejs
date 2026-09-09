#!/usr/bin/env bash
set -euo pipefail

PIXI_BIN="${PIXI_BIN:-pixi}"
NATIVE_BUILD=".temp/native-tests"

"${PIXI_BIN}" run mojo format --quiet mojo tests
git diff --exit-code -- mojo tests

mkdir -p "${NATIVE_BUILD}"
native_object="$("${PIXI_BIN}" run bash ../mojo-runtime/scripts/build-native.sh)"
for source in crypto_bridge crypto_catalog node_bridge net/endpoint compression/codec compression/constants tls/context tls/handshake tls/connection tls/server tls/io tls/lifecycle tls_bio fs_watch_bridge fs_stream_bridge fs_bridge os_bridge http_client_bridge http_parser_bridge socket_io_bridge vendor/llhttp/src/llhttp vendor/llhttp/src/api vendor/llhttp/src/http; do
  object="${source//\//_}"
  "${PIXI_BIN}" run bash -c 'exec "${CONDA_PREFIX:?}/bin/gcc" "$@"' -- -O3 -fPIC -std=c11 \
    -I"$("${PIXI_BIN}" run printenv CONDA_PREFIX)/include" \
    -Imojo/tsonic_node.native/vendor/llhttp/include \
    -c "mojo/tsonic_node.native/${source}.c" \
    -o "${NATIVE_BUILD}/${object}.o"
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
  -Xlinker "${NATIVE_BUILD}/net_endpoint.o"
  -Xlinker "${NATIVE_BUILD}/compression_codec.o"
  -Xlinker "${NATIVE_BUILD}/compression_constants.o"
  -Xlinker "${NATIVE_BUILD}/tls_context.o"
  -Xlinker "${NATIVE_BUILD}/tls_handshake.o"
  -Xlinker "${NATIVE_BUILD}/tls_connection.o"
  -Xlinker "${NATIVE_BUILD}/tls_server.o"
  -Xlinker "${NATIVE_BUILD}/tls_io.o"
  -Xlinker "${NATIVE_BUILD}/tls_lifecycle.o"
  -Xlinker "${NATIVE_BUILD}/tls_bio.o"
  -Xlinker "${NATIVE_BUILD}/fs_watch_bridge.o"
  -Xlinker "${NATIVE_BUILD}/fs_stream_bridge.o"
  -Xlinker "${NATIVE_BUILD}/fs_bridge.o"
  -Xlinker "${NATIVE_BUILD}/http_client_bridge.o"
  -Xlinker "${NATIVE_BUILD}/http_parser_bridge.o"
  -Xlinker "${NATIVE_BUILD}/socket_io_bridge.o"
  -Xlinker "${NATIVE_BUILD}/vendor_llhttp_src_llhttp.o"
  -Xlinker "${NATIVE_BUILD}/vendor_llhttp_src_api.o"
  -Xlinker "${NATIVE_BUILD}/vendor_llhttp_src_http.o"
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
for test_file in tests/native/*.c; do
  test_name="$(basename "${test_file}" .c)"
  if "${PIXI_BIN}" run bash -c 'exec "${CONDA_PREFIX:?}/bin/gcc" "$@"' -- \
    -O2 -std=c11 -I"$("${PIXI_BIN}" run printenv CONDA_PREFIX)/include" \
    "$test_file" "${NATIVE_BUILD}/tls_bio.o" "${NATIVE_BUILD}/socket_io_bridge.o" "${NATIVE_BUILD}/net_endpoint.o" \
    "${NATIVE_BUILD}/tls_context.o" "${NATIVE_BUILD}/tls_handshake.o" "${NATIVE_BUILD}/tls_connection.o" \
    "${NATIVE_BUILD}/tls_server.o" "${NATIVE_BUILD}/tls_io.o" "${NATIVE_BUILD}/tls_lifecycle.o" \
    -L"$("${PIXI_BIN}" run printenv CONDA_PREFIX)/lib" -lssl -lcrypto -luv \
    -o "${NATIVE_BUILD}/${test_name}" && "${NATIVE_BUILD}/${test_name}"; then
    printf 'PASS %s\n' "$test_file"
  else
    printf 'FAIL %s\n' "$test_file"
    failed=1
  fi
done

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
if ! node scripts/verify-path-oracle.mjs "${NATIVE_BUILD}/path_oracle_test"; then failed=1; fi
exit "$failed"
