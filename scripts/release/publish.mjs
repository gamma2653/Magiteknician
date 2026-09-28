// Tags the version that is on main, if it has not been tagged already.
//
// The release workflow runs this whenever main has no changesets waiting,
// which is the case just after the release pull request is merged and
// also after any push that did not need a release. `changeset publish`
// tells the two apart: it tags a version that has no tag and does nothing
// for one that has. The game is a private package, so nothing goes to npm.
//
// The workflow then pushes the tag and writes the GitHub release from the
// version's entry in CHANGELOG.md.

import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { UNRELEASED, versionOfPackage, versionOfProject } from "./version.mjs";

const root = new URL("../../", import.meta.url);
const version = versionOfPackage(readFileSync(new URL("package.json", root), "utf8"));
const inProject = versionOfProject(readFileSync(new URL("project.godot", root), "utf8"));

if (version === UNRELEASED) {
  // Nothing has been released yet, and 0.0.0 is not a release.
  console.log(`The version is ${UNRELEASED}: there is nothing to publish until a release has been made.`);
  process.exit(0);
}

if (inProject !== version) {
  // A tag says "this is the game at this version". Refuse to say so
  // while the game itself says otherwise.
  console.error(`package.json is at ${version} and project.godot is at ${inProject ?? "no version"}.`);
  console.error("Nothing has been tagged. Bring the two into line and push again.");
  process.exit(1);
}

const cli = fileURLToPath(new URL("node_modules/@changesets/cli/bin.js", root));
const result = spawnSync(process.execPath, [cli, "publish"], {
  cwd: fileURLToPath(root),
  stdio: "inherit",
});
process.exit(result.status ?? 1);
