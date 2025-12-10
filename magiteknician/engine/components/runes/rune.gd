@tool
@abstract
class_name Rune
extends Area2D

signal pressed

enum Type {
	DEVELOPMENT, # δ
	EQUIVELANCE, # φ
	PERSISTENCE, # κ
	DECAY, # λ
	FLOW, # ρ
	VARIABILITY, # σ
	REFRACTION, # θ
}

var rune_type: Type
@export var unscaled_ticks: int = -1:
	set(val):
		unscaled_ticks = val
		if Engine.is_editor_hint():
			update_configuration_warnings()
			if train != null:
				train.update_configuration_warnings()
				
var action_id: StringName
var selected: bool = false
var active: bool = false
var clickable: bool:
	get:
		return active and selected
@onready var primary_texture: TextureRect = $PrimaryTexture
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

const SIZE = Vector2(60, 60)
const RuneToID: Dictionary[Type, StringName] = {
	Type.DEVELOPMENT: "δ",
	Type.EQUIVELANCE: "φ",
	Type.PERSISTENCE: "κ",
	Type.DECAY: "λ",
	Type.FLOW: "ρ",
	Type.VARIABILITY: "σ",
	Type.REFRACTION: "θ"
}
const RuneToActionID: Dictionary[Type, StringName] = {
	Type.DEVELOPMENT: "Rune-Dev",
	Type.EQUIVELANCE: "Rune-Equiv",
	Type.PERSISTENCE: "Rune-Persist",
	Type.DECAY: "Rune-Decay",
	Type.FLOW: "Rune-Flow",
	Type.VARIABILITY: "Rune-Var",
	Type.REFRACTION: "Rune-Refrac"
}

static var IDToRune: Dictionary[StringName, Type] = {}
static var ActionIDToRune: Dictionary[StringName, Type] = {}

func _init():
	for rune in RuneToActionID.keys():
		ActionIDToRune[RuneToActionID[rune]] = rune
		IDToRune[RuneToID[rune]] = rune

func _ready():
	#var parent = get_parent()
	#if in_train():
		#var train = parent as Train
		#self._config_changed.connect(train._mark_runes_dirty)
	action_id = RuneToActionID[rune_type]
	if is_bound():
		set_transparency(0.0)

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

var train: Train:
	get:
		var parent = get_parent()
		if parent is Train:
			return parent
		else:
			return null

func set_transparency(a: float):
	primary_texture.modulate.a = a


func _get_configuration_warnings() -> PackedStringArray:
	var errors = []
	if rune_type == null:
		errors.append("Rune type must be set for any and all runes.")
	# check for parent
	#var parent = get_parent()
	if not _in_excused_ctx() and not train:
		errors.append("Parent node of a rune should be a `Train`.")
	if not _in_excused_ctx() and not primary_texture:
		errors.append("No primary texture found on this rune.")
	return errors

func _on_mouse_entered() -> void:
	selected = true
	
func _on_mouse_exited() -> void:
	selected = false
	

func on_rune_pressed(_delta):
	var timestamp_us = Time.get_ticks_usec()
	var location = get_viewport().get_mouse_position()
	Input.set_custom_mouse_cursor(Loader.RESOURCES["img"]["mouse"]["brush_down"], Input.CursorShape.CURSOR_ARROW, Vector2(0, 60))
	#print("%s clicked! (%d, %s)" % [RuneToID[rune_type], delta, action_id])
	pressed.emit(self, timestamp_us, location)
	# Play sound
	audio_player.play()
	

func on_rune_released(_delta):
	Input.set_custom_mouse_cursor(Loader.RESOURCES["img"]["mouse"]["brush"], Input.CursorShape.CURSOR_ARROW, Vector2(0, 60))

func _process(delta: float):
	if Engine.is_editor_hint():
		return
	if Input.is_action_just_pressed(action_id) and clickable:
		on_rune_pressed(delta)
	if Input.is_action_just_released(action_id):
		on_rune_released(delta)
	
func _to_string():
	if is_bound():
		return "[%s:%d]" % [Type.keys()[rune_type], unscaled_ticks]
	return "[%s]" % [Type.keys()[rune_type]]
