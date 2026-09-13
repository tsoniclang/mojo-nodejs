import { booleanType, numberType, stringType } from "../model.js";

export const processSignalSignatures = Object.freeze([
  Object.freeze({ parameters: [{ name: "pid", type: numberType }], returnType: booleanType, signatureSuffix: "pid", targetName: "kill_default" }),
  Object.freeze({ parameters: [{ name: "pid", type: numberType }, { name: "signal", type: stringType }], returnType: booleanType, signatureSuffix: "pid,name", targetName: "kill_named" }),
  Object.freeze({ parameters: [{ name: "pid", type: numberType }, { name: "signal", type: numberType }], returnType: booleanType, signatureSuffix: "pid,number", targetName: "kill_number" }),
]);
