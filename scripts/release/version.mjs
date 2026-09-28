// Reading and writing the game's version.
//
// The version is kept in two places. package.json is where Changesets
// keeps it, and project.godot is where the game reads it. Changesets
// decides what the version is; everything here copies that decision
// across and never makes one of its own.

const SECTION = "[application]";
const KEY = "config/version";

// Major.minor.patch, with an optional prerelease such as -next.1.
const SEMVER = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z.-]+)?$/;

/** A version that has never been released. */
export const UNRELEASED = "0.0.0";

export function isVersion(text) {
  return typeof text === "string" && SEMVER.test(text);
}

/** The version in the text of a package.json. */
export function versionOfPackage(packageJson) {
  const version = JSON.parse(packageJson).version;
  if (!isVersion(version)) {
    throw new Error(`package.json has "${version}" for its version, which is not a version.`);
  }
  return version;
}

/** The version in the text of a project.godot, or null if it has none. */
export function versionOfProject(project) {
  const { lines, start, end } = section(project);
  for (let i = start; i < end; i++) {
    const match = /^config\/version="(.*)"\s*$/.exec(lines[i]);
    if (match) {
      return match[1];
    }
  }
  return null;
}

/**
 * The text of a project.godot with its version set to `version`.
 * Nothing else in the file is touched, line endings included.
 */
export function withVersion(project, version) {
  if (!isVersion(version)) {
    throw new Error(`"${version}" is not a version.`);
  }
  const newline = project.includes("\r\n") ? "\r\n" : "\n";
  const { lines, start, end } = section(project);
  const entry = `${KEY}="${version}"`;

  for (let i = start; i < end; i++) {
    if (lines[i].startsWith(`${KEY}=`)) {
      lines[i] = entry;
      return lines.join(newline);
    }
  }
  // Godot writes the version after the name and the description, so put
  // it there and the editor will leave it where it is.
  let after = start;
  for (let i = start; i < end; i++) {
    if (lines[i].startsWith("config/name=") || lines[i].startsWith("config/description=")) {
      after = i + 1;
    }
  }
  if (after === start) {
    // No name to follow. Go first, after the blank line under the heading.
    after = lines[start] === "" ? start + 1 : start;
  }
  lines.splice(after, 0, entry);
  return lines.join(newline);
}

// The lines of the file, and where the [application] section's entries
// begin and end among them.
function section(project) {
  const lines = project.replace(/\r\n/g, "\n").split("\n");
  const heading = lines.findIndex((line) => line.trim() === SECTION);
  if (heading === -1) {
    throw new Error(`project.godot has no ${SECTION} section.`);
  }
  let end = lines.findIndex((line, i) => i > heading && /^\[.+\]\s*$/.test(line));
  if (end === -1) {
    end = lines.length;
  }
  return { lines, start: heading + 1, end };
}
