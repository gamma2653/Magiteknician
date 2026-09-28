// Copies the version from package.json into project.godot.
//
//   node scripts/release/sync_version.mjs          write it
//   node scripts/release/sync_version.mjs --check  say whether the two agree
//
// It runs straight after `changeset version`, so that the pull request
// which raises the version raises it in both places at once.

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { versionOfPackage, versionOfProject, withVersion } from "./version.mjs";

const root = new URL("../../", import.meta.url);
const packagePath = fileURLToPath(new URL("package.json", root));
const projectPath = fileURLToPath(new URL("project.godot", root));

const version = versionOfPackage(readFileSync(packagePath, "utf8"));
const project = readFileSync(projectPath, "utf8");
const current = versionOfProject(project);

if (process.argv.includes("--check")) {
  if (current !== version) {
    console.error(`package.json is at ${version} and project.godot is at ${current ?? "no version"}.`);
    console.error("Run `node scripts/release/sync_version.mjs` to bring project.godot into line.");
    process.exit(1);
  }
  console.log(`Both are at ${version}.`);
} else if (current === version) {
  console.log(`project.godot is already at ${version}.`);
} else {
  writeFileSync(projectPath, withVersion(project, version));
  console.log(`project.godot: ${current ?? "no version"} -> ${version}`);
}
