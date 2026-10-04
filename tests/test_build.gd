extends TestCase
## What a build of the game is made from, and what it says of itself.

const MAIN_MENU := preload("res://magiteknician/menus/main_menu.tscn")
const VERSION_LABEL := preload("res://magiteknician/menus/components/VersionLabel.tscn")
const VersionLabel := preload("res://magiteknician/menus/components/version_label.gd")
const PRESETS := "res://export_presets.cfg"
const SETTING := "application/config/version"


func _presets() -> ConfigFile:
	var presets := ConfigFile.new()
	presets.load(PRESETS)
	return presets


func _preset_sections(presets: ConfigFile) -> Array:
	return Array(presets.get_sections()).filter(func (section: String):
		return section.begins_with("preset.") and not section.ends_with(".options")
	)


# The version on the main menu

func test_a_released_version_is_shown_with_a_v() -> void:
	assert_eq(VersionLabel.describe("0.1.0"), "v0.1.0")
	assert_eq(VersionLabel.describe("12.4.0"), "v12.4.0")
	assert_eq(VersionLabel.describe("1.0.0-next.2"), "v1.0.0-next.2")


func test_a_game_never_released_says_so() -> void:
	assert_eq(VersionLabel.describe("0.0.0"), "unreleased")
	assert_eq(VersionLabel.describe(""), "unreleased")


func test_the_label_shows_the_games_own_version() -> void:
	var label: Label = add_managed(VERSION_LABEL.instantiate())
	assert_eq(label.text, VersionLabel.describe(str(ProjectSettings.get_setting(SETTING, ""))))


func test_the_main_menu_shows_the_version() -> void:
	var menu: Node = add_managed(MAIN_MENU.instantiate())
	var label := menu.get_node_or_null("Version") as Label
	assert_not_null(label)
	assert_eq(label.text, VersionLabel.describe(str(ProjectSettings.get_setting(SETTING, ""))))
	var rect := label.get_global_rect()
	assert_true(rect.end.x <= 1152.0 and rect.end.y <= 648.0, "and it is on the screen")
	# It must not sit on top of a button.
	for button in menu.get_node("ButtonManager").get_children():
		assert_false(rect.intersects((button as Control).get_global_rect()), "clear of %s" % [button.name])


# The self-check

func test_the_game_is_whole() -> void:
	assert_eq(SelfCheck.problems(), PackedStringArray())


func test_the_self_check_knows_every_scene_the_game_can_be_sent_to() -> void:
	var paths := SelfCheck.scene_paths()
	for path in [
		Session.MAIN_MENU_SCENE, Session.CAMPAIGN_SCENE, Session.ARENA_SCENE,
		Session.VERSUS_MENU_SCENE, Session.VERSUS_ARENA_SCENE,
		"res://magiteknician/levels/practice_range.tscn",
		"res://magiteknician/menus/options.tscn",
	]:
		assert_true(paths.has(path), path)
	for path in paths:
		assert_true(ResourceLoader.exists(path), path)


func test_the_self_check_does_nothing_unless_asked() -> void:
	assert_false(SelfCheck.FLAG in OS.get_cmdline_user_args(), "the tests are not run with the flag")
	# It is an autoload, so it has been ready since the game started. Had
	# it acted, the tests would not be running.
	assert_true(SelfCheck.is_inside_tree())


# The export presets

func test_there_is_a_preset_for_each_platform_that_is_released() -> void:
	var presets := _presets()
	var platforms := {}
	for section in _preset_sections(presets):
		platforms[presets.get_value(section, "name")] = presets.get_value(section, "platform")
	assert_eq(platforms, {"Windows": "Windows Desktop", "Linux": "Linux", "macOS": "macOS"})


func test_a_build_is_one_file() -> void:
	var presets := _presets()
	for section in _preset_sections(presets):
		if presets.get_value(section, "platform") == "macOS":
			# A Mac app is a folder, which Godot packs into one zip.
			assert_true(str(presets.get_value(section, "export_path", "")).ends_with(".zip"))
			continue
		var options: String = section + ".options"
		assert_true(
			presets.get_value(options, "binary_format/embed_pck", false),
			"%s packs the game into the executable" % [presets.get_value(section, "name")]
		)


func test_a_build_leaves_out_what_is_not_the_game() -> void:
	var presets := _presets()
	for section in _preset_sections(presets):
		var excluded: String = presets.get_value(section, "exclude_filter", "")
		for folder in ["tests/*", "scripts/*", "docs/*", "node_modules/*"]:
			assert_true(folder in excluded, "%s leaves out %s" % [presets.get_value(section, "name"), folder])
		assert_eq(presets.get_value(section, "export_filter"), "all_resources")


func test_builds_are_made_outside_the_game() -> void:
	var presets := _presets()
	for section in _preset_sections(presets):
		var path: String = presets.get_value(section, "export_path", "")
		assert_true(path.begins_with("build/"), path)


# The Mac build

func _mac_options(presets: ConfigFile) -> String:
	for section in _preset_sections(presets):
		if presets.get_value(section, "platform") == "macOS":
			return section + ".options"
	return ""


func test_the_mac_build_runs_on_apple_silicon() -> void:
	var presets := _presets()
	var options := _mac_options(presets)
	# Universal holds arm64 and x86_64. Godot's own templates hold no
	# build for arm64 alone.
	assert_eq(presets.get_value(options, "binary_format/architecture", ""), "universal")
	assert_true(
		ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false),
		"Godot will not build for arm64 without it"
	)


func test_the_mac_build_is_signed_and_named() -> void:
	var presets := _presets()
	var options := _mac_options(presets)
	# 1 is the signing built into Godot, which is ad hoc. A Mac with Apple
	# silicon will not run a program that is not signed at all.
	assert_eq(presets.get_value(options, "codesign/codesign", 0), 1)
	assert_true(str(presets.get_value(options, "application/bundle_identifier", "")).contains("."))
