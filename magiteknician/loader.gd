extends Node
#class_name Level  # <- autoload singleton name

# Premature optimization is the root of all evil. ;)
# Lazy loading, if necessary:
func level_loader(level_name, type_ = "levels"):
	return func():
		return load("res://magiteknician/%s/%s.tscn" % [type_, level_name]) as PackedScene


## Maps to callables to PackedScene
var LEVELS = {
	"section1": {
		"level1": level_loader("level1"),
	},
	"menu": {
		"main_menu": level_loader("main_menu", "menus"),
		"options": level_loader("options", "menus"),
	}
}

## Preloaded assets
var RESOURCES = {
	"img": {
		"title": preload("res://magiteknician/assets/title.png") as Texture2D,
		"runes": {
			"δ": preload("res://magiteknician/assets/δ.png") as Texture2D,
			"θ": preload("res://magiteknician/assets/θ.png") as Texture2D,
			"κ": preload("res://magiteknician/assets/κ.png") as Texture2D,
			"λ": preload("res://magiteknician/assets/λ.png") as Texture2D,
			"ρ": preload("res://magiteknician/assets/ρ.png") as Texture2D,
			"σ": preload("res://magiteknician/assets/σ.png") as Texture2D,
			"φ": preload("res://magiteknician/assets/φ.png") as Texture2D
		},
		"mouse": {
			"brush": preload("res://magiteknician/assets/turd_brush.png") as Texture2D,
			"brush_down": preload("res://magiteknician/assets/turd_brush_down.png") as Texture2D
		}
	},
	"sound": {
		"common_menu_map": {
			"opt1": preload("res://magiteknician/assets/audio/menu/opt1.ogg") as AudioStream,
			"opt1_sel": preload("res://magiteknician/assets/audio/menu/opt1_sel.ogg") as AudioStream,
			"opt2": preload("res://magiteknician/assets/audio/menu/opt2.ogg") as AudioStream,
			"opt2_sel": preload("res://magiteknician/assets/audio/menu/opt2_sel.ogg") as AudioStream,
			"opt3": preload("res://magiteknician/assets/audio/menu/opt3.ogg") as AudioStream,
			"opt3_sel": preload("res://magiteknician/assets/audio/menu/opt3_sel.ogg") as AudioStream,
			"opt4": preload("res://magiteknician/assets/audio/menu/opt4.ogg") as AudioStream,
			"opt4_sel": preload("res://magiteknician/assets/audio/menu/opt4_sel.ogg") as AudioStream
		}
	}
}
