@tool
@abstract
class_name Rune
extends Area2D

signal config_changed

enum RuneType {
	DEVELOPMENT, # δ
	EQUIVELANCE, # φ
	PERSISTENCE, # κ
	DECAY, # λ
	FLOW, # ρ
	VARIABILITY, # σ
	REFRACTION, # θ
}

var rune_type: RuneType
@export var unscaled_ticks: int = -1:
	set(val):
		unscaled_ticks = val
		update_configuration_warnings()
		config_changed.emit()

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

func is_bound():
	return unscaled_ticks >= 0

# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#if not Engine.is_editor_hint():
		### Initialize textures
		#add_child(init_texture())
		
func _in_excused_ctx():
	var parent = get_parent()
	return parent == null or parent is SubViewport

func in_train():
	var parent = get_parent()
	return parent is Train

func _ready():
	var parent = get_parent()
	if in_train():
		var train = parent as Train
		self.config_changed.connect(train._mark_runes_dirty)
		

func _get_configuration_warnings() -> PackedStringArray:
	var errors = []
	if rune_type == null:
		errors.append("Rune type must be set for any and all runes.")
	# check for parent
	#var parent = get_parent()
	if not in_train() and not _in_excused_ctx():
		errors.append("Parent node of a rune should be a `Train`.")
	return errors
