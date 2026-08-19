import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

describe("Functions deploy packaging", () => {
  it("builds TypeScript from RESOURCE_DIR before every deploy", () => {
    const root = resolve(import.meta.dirname, "../..");
    const firebase = JSON.parse(readFileSync(resolve(root, "firebase.json"), "utf8")) as {
      functions?: { predeploy?: string[] };
    };
    const packageJSON = JSON.parse(readFileSync(resolve(root, "functions/package.json"), "utf8")) as {
      main?: string;
      scripts?: { build?: string };
    };

    expect(packageJSON.main).toBe("lib/index.js");
    expect(packageJSON.scripts?.build).toBe("tsc");
    expect(firebase.functions?.predeploy).toContain('npm --prefix "$RESOURCE_DIR" run build');
  });
});
