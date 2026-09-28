extends TestCase
## The game's version: what it is, and that everything agrees on it.
##
## Changesets keeps the version in package.json. The release tooling copies
## it into project.godot, which is where the game reads it from. If the two
## ever part company, a release would be tagged as one version and
## announce itself as another.

const PACKAGE := "res://package.json"
const CHANGELOG := "res://CHANGELOG.md"
const SETTING := "application/config/version"
## What the version is before anything has been released.
const UNRELEASED := "0.0.0"


func _version_in_package() -> String:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
	if data is Dictionary:
		return str(data.get("version", ""))
	return ""


func test_the_game_has_a_version() -> void:
	var version := str(ProjectSettings.get_setting(SETTING, ""))
	assert_false(version.is_empty(), "project.godot has a version")
	var pattern := RegEx.create_from_string("^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(-[0-9A-Za-z.-]+)?$")
	assert_not_null(pattern.search(version), "'%s' is major.minor.patch" % [version])


func test_the_game_and_the_release_tooling_agree_on_it() -> void:
	assert_true(FileAccess.file_exists(PACKAGE), "package.json is there")
	assert_eq(str(ProjectSettings.get_setting(SETTING, "")), _version_in_package())


func test_a_released_version_is_in_the_changelog() -> void:
	var version := _version_in_package()
	if version == UNRELEASED:
		assert_false(FileAccess.file_exists(CHANGELOG), "nothing has been released, so there is no changelog yet")
		return
	var changelog := FileAccess.get_file_as_string(CHANGELOG)
	assert_true(("## %s\n" % [version]) in changelog.replace("\r\n", "\n"), "CHANGELOG.md has an entry for %s" % [version])
