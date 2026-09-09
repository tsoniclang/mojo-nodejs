import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import path from "node:path";

const executable = process.argv[2];
assert.ok(executable, "Expected the compiled path oracle");
const samples = [
  "", ".", "..", "...", "/", "//", "///", "a", "a/", "a//", "/a/b/", "//a/b",
  "one/../two/", "../../a", "a/.hidden", "a/.hidden.txt", "a/file.", "a/..",
  "C:", "C:.", "C:..", "C:article.txt", "C:/", "C:\\", "C:\\work\\..\\data\\",
  "C:\\..\\data", "C:one\\..\\two", "\\one\\two", "\\\\host\\share", "\\\\host\\share\\",
  "\\\\host\\share\\..\\file", "\\\\host\\\\share\\file", "\\\\host", "\\\\?\\C:\\work\\..\\file",
  "\\\\?\\UNC\\host\\share\\file", "\\\\.\\PHYSICALDRIVE0", "COM1:", "LPT¹:", "NUL:part",
  ":", "one/../C:/file", "./x:/a", "space here/😀/café.txt", "C:\\😀\\café.txt", "trailing\nline",
];
const pairs = [
  ["/a/b", "/a/c/d"], ["C:\\one", "D:\\two"], ["C:\\work\\posts", "c:\\WORK\\Assets"],
  ["\\\\host\\share\\one", "\\\\HOST\\share\\two"], ["", "."], ["one", "two"],
  ["/a", "\\root"], ["C:one", "C:two"], ["C:\\café", "C:\\CAFÉ\\😀"],
];
const joins = [
  [""], ["", ""], ["/a", "", "b"], ["C:\\a", "b", "..", "c"],
  ["//", "host", "share"], ["//host", "share"], ["C:one", "\\two"],
  ["D:one", "C:\\two"], ["C:\\one", "D:two"], [".", "..", ""],
];
const failures = [];
let count = 0;
function compare(dialect, operation, arguments_, expected) {
  count += 1;
  const actual = spawnSync(executable, [dialect, operation, ...arguments_], { encoding: "utf8", timeout: 5000, maxBuffer: 1024 * 1024 });
  if (actual.error || actual.status !== 0 || actual.stdout !== expected || actual.stderr !== "") {
    failures.push({ dialect, operation, arguments_, expected, stdout: actual.stdout, stderr: actual.stderr, status: actual.status, error: actual.error?.message });
  }
}
for (const name of ["posix", "win32"]) {
  const dialect = path[name];
  for (const sample of samples) {
    for (const operation of ["normalize", "dirname", "basename", "extname", "isAbsolute", "toNamespacedPath"]) {
      compare(name, operation, [sample], `${dialect[operation](sample)}\n`);
    }
    const parsed = dialect.parse(sample);
    compare(name, "parse", [sample], [parsed.root, parsed.dir, parsed.base, parsed.name, parsed.ext, ""].join("\n"));
    for (const suffix of ["", ".txt", sample, "file", "longer-than-file/"]) {
      compare(name, "basename", [sample, suffix], `${dialect.basename(sample, suffix)}\n`);
    }
  }
  for (const pair of pairs) compare(name, "relative", pair, `${dialect.relative(...pair)}\n`);
  for (const parts of joins) {
    for (const operation of ["join", "resolve"]) compare(name, operation, parts, `${dialect[operation](...parts)}\n`);
  }
  for (const fields of [
    ["", "", "", "", ""], ["/", "", "", "file", "txt"], ["C:\\", "", "", "file", ".txt"],
    ["/root", "/dir", "base", "ignored", "ignored"], ["", "C:/mixed", "", "name", "ext"],
  ]) {
    const [root, dir, base, name_, ext] = fields;
    compare(name, "format", fields, `${dialect.format({ root, dir, base, name: name_, ext })}\n`);
  }
}
for (const failure of failures) console.error(JSON.stringify(failure));
assert.equal(failures.length, 0, `${failures.length}/${count} native path oracle cases differ`);
console.log(`Path native/oracle parity: ${count}/${count}`);
