@tool
class_name Rune
extends Node2D

enum RuneType {
	DEVELOPMENT, # δ
	EQUIVELANCE, # φ
	PERSISTENCE, # κ
	DECAY, # λ
	FLOW, # ρ
	VARIABILITY, # σ
	REFRACTION, # θ
}

@export var rune_type: RuneType
var texture: TextureRect = null

const SIZE = Vector2(60, 60)
const RuneToID: Dictionary[RuneType, String] = {
	RuneType.DEVELOPMENT: "δ",
	RuneType.EQUIVELANCE: "φ",
	RuneType.PERSISTENCE: "κ",
	RuneType.DECAY: "λ",
	RuneType.FLOW: "ρ",
	RuneType.VARIABILITY: "σ",
	RuneType.REFRACTION: "θ"
}

func init_texture():
	texture = TextureRect.new()
	texture.texture = Loader.RESOURCES["img"]["runes"][RuneToID[rune_type]]
	texture.set_size(SIZE)
	texture.set_anchors_preset(Control.PRESET_CENTER, true)
	return texture

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Engine.is_editor_hint():
		# Initialize textures
		add_child(init_texture())

func _get_configuration_warnings() -> PackedStringArray:
	var errors = []
	if rune_type == null:
		errors.append("Rune type must be set for any and all runes.")
	return errors
