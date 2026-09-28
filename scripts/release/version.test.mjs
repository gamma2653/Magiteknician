import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { isVersion, versionOfPackage, versionOfProject, withVersion } from "./version.mjs";

const PROJECT = `; Engine configuration file.

config_version=5

[application]

config/name="Magiteknician"
run/main_scene="uid://rmxsvma5j3wr"
config/features=PackedStringArray("4.7", "Forward Plus")

[autoload]

Loader="*res://magiteknician/loader.gd"
`;

test("a version is three numbers, with nothing in front", () => {
  for (const good of ["0.0.0", "0.1.0", "1.4.2", "10.20.30", "1.0.0-next.1"]) {
    assert.ok(isVersion(good), good);
  }
  for (const bad of ["", "1", "1.2", "v1.2.3", "1.2.3.4", "01.2.3", "1.2.x", null, undefined, 3]) {
    assert.ok(!isVersion(bad), String(bad));
  }
});

test("the version is read from package.json", () => {
  assert.equal(versionOfPackage('{"name": "magiteknician", "version": "1.4.2"}'), "1.4.2");
});

test("a package.json without a proper version is refused", () => {
  assert.throws(() => versionOfPackage('{"name": "magiteknician"}'));
  assert.throws(() => versionOfPackage('{"version": "soon"}'));
});

test("a project that has never had a version has none", () => {
  assert.equal(versionOfProject(PROJECT), null);
});

test("a version is added after the name, where Godot would put it", () => {
  const lines = withVersion(PROJECT, "0.1.0").split("\n");
  const name = lines.indexOf('config/name="Magiteknician"');
  assert.equal(lines[name + 1], 'config/version="0.1.0"');
  assert.equal(lines[name + 2], 'run/main_scene="uid://rmxsvma5j3wr"');
});

test("a version that is there already is replaced, not added to", () => {
  const once = withVersion(PROJECT, "0.1.0");
  const twice = withVersion(once, "0.2.0");
  assert.equal(versionOfProject(twice), "0.2.0");
  assert.equal(twice.match(/config\/version=/g).length, 1);
  assert.equal(twice.split("\n").length, once.split("\n").length);
});

test("setting the version it already has changes nothing", () => {
  const once = withVersion(PROJECT, "0.1.0");
  assert.equal(withVersion(once, "0.1.0"), once);
});

test("nothing but the version is touched", () => {
  const changed = withVersion(PROJECT, "0.1.0");
  const without = changed.split("\n").filter((line) => !line.startsWith("config/version="));
  assert.deepEqual(without, PROJECT.split("\n"));
});

test("a file with Windows line endings keeps them", () => {
  const windows = PROJECT.replace(/\n/g, "\r\n");
  const changed = withVersion(windows, "0.1.0");
  assert.equal(versionOfProject(changed), "0.1.0");
  assert.ok(!/[^\r]\n/.test(changed), "every line still ends \\r\\n");
});

test("a version in another section is not mistaken for the game's", () => {
  const project = PROJECT + '\n[addon]\n\nconfig/version="9.9.9"\n';
  assert.equal(versionOfProject(project), null);
  const changed = withVersion(project, "0.1.0");
  assert.equal(versionOfProject(changed), "0.1.0");
  assert.ok(changed.includes('config/version="9.9.9"'), "the other is left alone");
});

test("a project with no name still gets its version", () => {
  const project = "[application]\n\nrun/main_scene=\"x\"\n\n[autoload]\n";
  const changed = withVersion(project, "0.1.0");
  assert.equal(versionOfProject(changed), "0.1.0");
  assert.ok(changed.indexOf("config/version") < changed.indexOf("[autoload]"));
});

test("what is not a version is not written", () => {
  assert.throws(() => withVersion(PROJECT, "v0.1.0"));
  assert.throws(() => withVersion(PROJECT, ""));
});

test("a file that is not a Godot project is refused", () => {
  assert.throws(() => versionOfProject("[autoload]\n"));
  assert.throws(() => withVersion("", "0.1.0"));
});

test("the game's own files agree on the version", () => {
  const inPackage = versionOfPackage(readFileSync(new URL("../../package.json", import.meta.url), "utf8"));
  const inProject = versionOfProject(readFileSync(new URL("../../project.godot", import.meta.url), "utf8"));
  assert.equal(inProject, inPackage);
});
