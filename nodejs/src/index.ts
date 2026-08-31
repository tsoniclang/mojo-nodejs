export { createMojoNodejsCapability } from "./capability.js";
export type { MojoNodejsCapabilityPlugin } from "./capability.js";
import { createMojoNodejsCapability } from "./capability.js";
import type { MojoNodejsCapabilityPlugin } from "./capability.js";

export function createTsonicPlugin(): MojoNodejsCapabilityPlugin {
  return createMojoNodejsCapability();
}
