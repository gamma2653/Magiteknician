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
		"title": load("res://magiteknician/assets/title.png") as Texture2D,
		"runes": {
			"δ": load("res://magiteknician/assets/δ.png") as Texture2D,
			"θ": load("res://magiteknician/assets/θ.png") as Texture2D,
			"κ": load("res://magiteknician/assets/κ.png") as Texture2D,
			"λ": load("res://magiteknician/assets/λ.png") as Texture2D,
			"ρ": load("res://magiteknician/assets/ρ.png") as Texture2D,
			"σ": load("res://magiteknician/assets/σ.png") as Texture2D,
			"φ": load("res://magiteknician/assets/φ.png") as Texture2D
		}
	},
	"sound": {
		"common_menu_map": {
			"opt1": load("res://magiteknician/assets/audio/menu/opt1.ogg") as AudioStream,
			"opt1_sel": load("res://magiteknician/assets/audio/menu/opt1_sel.ogg") as AudioStream,
			"opt2": load("res://magiteknician/assets/audio/menu/opt2.ogg") as AudioStream,
			"opt2_sel": load("res://magiteknician/assets/audio/menu/opt2_sel.ogg") as AudioStream,
			"opt3": load("res://magiteknician/assets/audio/menu/opt3.ogg") as AudioStream,
			"opt3_sel": load("res://magiteknician/assets/audio/menu/opt3_sel.ogg") as AudioStream,
			"opt4": load("res://magiteknician/assets/audio/menu/opt4.ogg") as AudioStream,
			"opt4_sel": load("res://magiteknician/assets/audio/menu/opt4_sel.ogg") as AudioStream
		}
	}
}
