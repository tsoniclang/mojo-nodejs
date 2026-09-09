import { legacyUrlModule, legacyUrlOperations, legacyUrlTypes } from "./legacy.js";
import { webUrlExports, webUrlOperations, webUrlTypes } from "./web.js";

export function urlModule(): ReturnType<typeof legacyUrlModule> {
  const legacy = legacyUrlModule();
  return Object.freeze({ ...legacy,
    imports: Object.freeze([{ moduleSpecifier: "node:buffer", namedImports: Object.freeze([{ exportedName: "Buffer" }]) }]),
    exports: Object.freeze([...legacy.exports, ...webUrlExports()]) });
}

export function urlTypes(): ReturnType<typeof legacyUrlTypes> {
  return Object.freeze([...legacyUrlTypes(), ...webUrlTypes()]);
}

export function urlOperations(): ReturnType<typeof legacyUrlOperations> {
  return Object.freeze([...legacyUrlOperations(), ...webUrlOperations()]);
}
