extends Node
#class_name Level  # <- autoload singleton name

# Premature optimization is the root of all evil. ;)
# Lazy loading, if necessary:
#func level_loader(level_name):
	#return func():
		#return load("res://magitechnician/levels/%s.tscn" % [level_name])

var ALL_LEVELS = {
	"section1": {
		"level1": load("res://magiteknician/levels/level1.tscn"),
	},
	"menu": {
		"main_menu": load("res://magiteknician/menus/main_menu.tscn"),
		"options": load("res://magiteknician/menus/options.tscn")
	}
}

var ASSETS = {
	"ui": {
		"title": load("res://magiteknician/assets/title.png") as Texture2D
	}
}
