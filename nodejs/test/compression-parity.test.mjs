import assert from "node:assert/strict";
import test from "node:test";
import { projectArtifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

const capability = createMojoNodejsCapability();
const definition = capability.createTargetContributions({})[0].definition;
const module = definition.modules.find((entry) => entry.moduleSpecifier === "node:zlib");

test("all compression factories and one-shot calls have matching codec-family options", () => {
  for (const [name, options] of [
    ["gzip", "ZlibOptions"], ["gunzip", "ZlibOptions"], ["deflate", "ZlibOptions"],
    ["inflate", "ZlibOptions"], ["deflateRaw", "ZlibOptions"], ["inflateRaw", "ZlibOptions"],
    ["unzip", "ZlibOptions"], ["brotliCompress", "BrotliOptions"], ["brotliDecompress", "BrotliOptions"],
  ]) {
    for (const sourceName of [name, `${name}Sync`, `create${name[0].toUpperCase()}${name.slice(1)}`]) {
      const declaration = module.exports.find((entry) => entry.name === sourceName);
      assert.ok(declaration, sourceName);
      const optionSignature = declaration.signatures.find((signature) => signature.parameters.some((parameter) => parameter.name === "options" && parameter.type.exportName === options));
      const parameter = optionSignature.parameters.find((entry) => entry.name === "options");
      assert.equal(parameter.type.exportName, options, sourceName);
      const operations = definition.operations.filter((entry) => entry.exportId === declaration.id && entry.signatureId === optionSignature.id);
      assert.equal(operations.length, 1, optionSignature.id);
      const position = optionSignature.parameters.indexOf(parameter);
      assert.equal(operations[0].parameterTypes[position].name, options);
    }
  }
  const brotli = module.exports.find((entry) => entry.name === "BrotliOptions");
  assert.equal(brotli.members.some((entry) => entry.name === "quality" || entry.name === "level"), false);
  assert.equal(brotli.members.find((entry) => entry.name === "params").type.name, "Record");
});

test("compression result variants follow exact option signatures instead of discarding info", () => {
  const gzip = module.exports.find((entry) => entry.name === "gzipSync");
  const info = gzip.signatures.find((entry) => entry.id.endsWith("(input,infoOptions)"));
  const buffer = gzip.signatures.find((entry) => entry.id.endsWith("(input,bufferOptions)"));
  const dynamic = gzip.signatures.find((entry) => entry.id.endsWith("(input,options)"));
  assert.equal(info.returnType.exportName, "ZlibInfo");
  assert.equal(buffer.returnType.exportName, "Buffer");
  assert.equal(dynamic.returnType.kind, "union");
  assert.deepEqual(dynamic.returnType.types.map((entry) => entry.exportName), ["Buffer", "ZlibInfo"]);
  const result = compileMojo({ capabilities: [capability], files: { "index.ts": `
import { Buffer } from "node:buffer";
import { gzipSync, gunzipSync, createGzip, gzip } from "node:zlib";

export function main(): void {
  const input = Buffer.from("payload");
  const detailed = gzipSync(input, { info: true });
  const decoded = gunzipSync(detailed.buffer);
  const consumed = detailed.engine.bytesWritten;
  const closed = detailed.engine.closed;
  const stream = createGzip();
  stream.write("one");
  stream.flush();
  stream.read();
  stream.params(1, 0, () => {});
  stream.end("two");
  gzip(input, { info: true }, (error, result) => {
    if (result !== undefined) { result.engine.bytesWritten; result.buffer.length; }
  });
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const source = projectArtifactTexts(result).map((entry) => entry.text).join("\n");
  assert.ok(source.includes("gzip_sync_info_options"));
  assert.ok(source.includes("gzip_callback_info_options"));
  assert.ok(source.includes("bytes_written"));
  assert.ok(source.includes("params_callback"));
});

test("native Brotli parameters and unzip factories pass through complete source checking and sealed planning", () => {
  const result = compileMojo({ capabilities: [capability], files: { "index.ts": `
import { Buffer } from "node:buffer";
import { constants, brotliCompressSync, brotliDecompressSync, createUnzip, createBrotliCompress, createBrotliDecompress } from "node:zlib";

export function main(): void {
  const params: Record<number, number | boolean> = {};
  params[constants.BROTLI_PARAM_QUALITY] = 4;
  params[constants.BROTLI_PARAM_LARGE_WINDOW] = false;
  const compressed = brotliCompressSync(Buffer.from("payload"), { params, chunkSize: 64, maxOutputLength: 128 });
  brotliDecompressSync(compressed, { maxOutputLength: 1024 });
  createUnzip();
  createBrotliCompress({ params });
  createBrotliDecompress();
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const source = projectArtifactTexts(result).map((entry) => entry.text).join("\n");
  for (const name of ["brotli_compress_sync_options", "brotli_decompress_sync_options", "create_unzip", "create_brotli_compress_options", "create_brotli_decompress"]) {
    assert.ok(source.includes(name), name);
  }
});
