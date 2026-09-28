// Keeps Godot out of node_modules.
//
// Godot looks through every folder of the project for things to import,
// and node_modules holds thousands of files, none of them the game's. A
// folder with a .gdignore in it is passed over. npm empties node_modules
// when it installs, so this runs after every install to put the file back.

import { existsSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const folder = new URL("../../node_modules/", import.meta.url);
if (existsSync(folder)) {
  writeFileSync(fileURLToPath(new URL(".gdignore", folder)), "");
}
