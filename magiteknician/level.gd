extends Node
#class_name Level  # <- autoload singleton name

# Premature optimization is the root of all evil. ;)
# Lazy loading, if necessary:
#func level_loader(level_name):
	#return func():
		#return load("res://magiteknician/levels/%s.tscn" % [level_name])

var LEVELS = {
	"section1": {
		"level1": load("res://magiteknician/levels/level1.tscn") as PackedScene,
	},
	"menu": {
		"main_menu": load("res://magiteknician/menus/main_menu.tscn") as PackedScene,
		"options": load("res://magiteknician/menus/options.tscn") as PackedScene,
	}
}

var RESOURCES = {
	"img": {
		"title": load("res://magiteknician/assets/title.png") as Texture2D
	},
	"sound": {
		"new_game": load("res://magiteknician/assets/audio/menu/new_game.ogg") as AudioStream,
	}
}
