extends TestCase
## Every scene in the game loads, instantiates and survives a frame in the
## tree without raising an engine error. This is the cheapest way to notice
## a scene that points at a moved script, a renamed node or a missing asset.

const SCENE_ROOT := "res://magiteknician"


func test_every_scene_instantiates() -> void:
	var scenes := _find_scenes(SCENE_ROOT)
	assert_gt(scenes.size(), 0, "found scenes to check")
	for path in scenes:
		var packed := load(path) as PackedScene
		if packed == null or not packed.can_instantiate():
			fail("%s could not be loaded" % [path])
			continue
		var instance := packed.instantiate()
		assert_not_null(instance, path)
		add_managed(instance)
		await get_tree().process_frame
		remove_child(instance)
		instance.free()


func _find_scenes(directory: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return found
	for subdirectory in dir.get_directories():
		found.append_array(_find_scenes(directory.path_join(subdirectory)))
	for file in dir.get_files():
		if file.ends_with(".tscn"):
			found.append(directory.path_join(file))
	found.sort()
	return found
