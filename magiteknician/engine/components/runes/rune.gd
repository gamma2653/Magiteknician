@tool
@abstract
class_name Rune
extends Area2D

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
		if Engine.is_editor_hint():
			update_configuration_warnings()
			if train != null:
				train.update_configuration_warnings()
				
var action_id: String
var selected: bool = false
@onready var primary_texture: TextureRect = $PrimaryTexture

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
const RuneToActionID: Dictionary[RuneType, String] = {
	RuneType.DEVELOPMENT: "Rune-Dev",
	RuneType.EQUIVELANCE: "Rune-Equiv",
	RuneType.PERSISTENCE: "Rune-Persist",
	RuneType.DECAY: "Rune-Decay",
	RuneType.FLOW: "Rune-Flow",
	RuneType.VARIABILITY: "Rune-Var",
	RuneType.REFRACTION: "Rune-Refrac"
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

var train: Train:
	get:
		var parent = get_parent()
		if parent is Train:
			return parent
		else:
			return null

func set_transparency(a: float):
	primary_texture.modulate.a = a

func _ready():
	#var parent = get_parent()
	#if in_train():
		#var train = parent as Train
		#self._config_changed.connect(train._mark_runes_dirty)
	action_id = RuneToActionID[rune_type]
	if is_bound():
		set_transparency(0.0)

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
	

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed(action_id):
		print("%s clicked" % [RuneToID[rune_type]])
	# check others
	for rt in RuneType.keys():
		#print("Checking %s" % [rt])
		var rtv = RuneType.get(rt)
		if rtv == rune_type:
			continue
		if event.is_action_pressed(RuneToActionID[rtv]):
			print("potentially: %s clicked!" % [RuneToID[rtv]])

func _process(delta: float):
	if Engine.is_editor_hint():
		return
	if Input.is_action_just_pressed(action_id) and selected:
		print("%s clicked! (%d, %s)" % [RuneToID[rune_type], delta, action_id])
		Input.set_custom_mouse_cursor(preload("res://magiteknician/assets/turd_brush_down.png"), Input.CursorShape.CURSOR_ARROW, Vector2(0, 60))
	if Input.is_action_just_released(action_id):
		Input.set_custom_mouse_cursor(preload("res://magiteknician/assets/turd_brush.png"), Input.CursorShape.CURSOR_ARROW, Vector2(0, 60))
	
func _to_string():
	if is_bound():
		return "[%s:%d]" % [RuneType.keys()[rune_type], unscaled_ticks]
	return "[%s]" % [RuneType.keys()[rune_type]]
