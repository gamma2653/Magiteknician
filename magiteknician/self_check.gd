extends Node
## Lets a build of the game be asked whether it is whole.
##
##   Magiteknician.exe --headless -- --self-check
##
## It looks for what the game needs, says what it could not find, and
## exits with 0 if nothing was missing and 1 if something was. Without the
## flag it does nothing at all.
##
## The tests cannot answer this question, because they run in the editor
## and are left out of a build. A build finds its files differently: they
## are packed, renamed and listed from an index, and a scene that loads in
## the editor can be missing from the pack. This runs inside the build.

const FLAG := "--self-check"
const VERSION_SETTING := "application/config/version"


func _ready() -> void:
	if FLAG not in OS.get_cmdline_user_args():
		return
	var found := problems()
	print("Magiteknician %s" % [version()])
	print("%d spells, %d opponents, %d scenes" % [
		SpellLibrary.all().size(),
		Session.campaign.stage_count(),
		scene_paths().size(),
	])
	for problem in found:
		print("  missing  %s" % [problem])
	print("self-check: %s" % ["passed" if found.is_empty() else "%d failed" % [found.size()]])
	get_tree().quit(0 if found.is_empty() else 1)


## The game's version, or "" if it has none.
static func version() -> String:
	return str(ProjectSettings.get_setting(VERSION_SETTING, ""))


## Every scene the game can be sent to.
func scene_paths() -> Array[String]:
	var paths: Array[String] = [
		Session.MAIN_MENU_SCENE,
		Session.CAMPAIGN_SCENE,
		Session.ARENA_SCENE,
		Session.VERSUS_MENU_SCENE,
		Session.VERSUS_ARENA_SCENE,
	]
	for group in Loader.LEVELS.values():
		for loader in group.values():
			var scene: PackedScene = loader.call()
			if scene != null and not paths.has(scene.resource_path):
				paths.append(scene.resource_path)
	return paths


## Everything the game needs and cannot find. Empty when it is whole.
func problems() -> PackedStringArray:
	var found: PackedStringArray = []

	if version().is_empty():
		found.append("a version")

	if SpellLibrary.all().is_empty():
		found.append("any spells at all")
	for type in Rune.Type.values():
		if not ResourceLoader.exists(Rune.RuneToScene[type]):
			found.append("the rune of %s (%s)" % [Rune.RuneToName[type], Rune.RuneToScene[type]])

	# The campaign names its opponents and every spell it teaches or they
	# cast, so this finds a spell or an opponent that was not packed.
	for problem in Session.campaign.problems():
		found.append("a sound campaign: %s" % [problem])

	for group_name in Loader.LEVELS:
		for scene_name in Loader.LEVELS[group_name]:
			if Loader.LEVELS[group_name][scene_name].call() == null:
				found.append("the scene %s/%s" % [group_name, scene_name])
	for path in scene_paths():
		if not ResourceLoader.exists(path):
			found.append("the scene %s" % [path])

	return found
