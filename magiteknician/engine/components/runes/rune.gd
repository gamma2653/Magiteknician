@tool
@abstract
class_name Rune
extends Area2D

## Emitted when the rune is struck.
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
				
## How a rune on a train is drawn.
enum Look {
	## Part of the spell, waiting its turn.
	GHOST,
	## The rune to strike next.
	NEXT,
	## A ghost that has been struck; its mark has taken its place.
	STRUCK,
	## Where a stroke landed.
	MARK,
}

const LOOK_ALPHA: Dictionary[Look, float] = {
	Look.GHOST: 0.28,
	Look.NEXT: 0.75,
	Look.STRUCK: 0.0,
	Look.MARK: 1.0,
}
const JUDGEMENT_COLORS: Dictionary[CastResult.Judgement, Color] = {
	CastResult.Judgement.PERFECT: Color(1.0, 0.87, 0.35),
	CastResult.Judgement.GREAT: Color(0.5, 1.0, 0.55),
	CastResult.Judgement.GOOD: Color(0.5, 0.8, 1.0),
	CastResult.Judgement.POOR: Color(1.0, 0.62, 0.3),
	CastResult.Judgement.MISS: Color(1.0, 0.35, 0.35),
}
const RING_COLOR = Color(1.0, 0.95, 0.75)
## How far out the approach ring starts for each tick still to go.
const APPROACH_PX_PER_TICK = 46.0
## The approach ring is not drawn further out than this many ticks.
const APPROACH_MAX_TICKS = 2.0
const FLASH_SCALE = 1.3
const FLASH_SECONDS = 0.25

var action_id: StringName
## True when mouse is hovering
var selected: bool = false
## True when it is the current rune on a train
var active: bool = false
var clickable: bool:
	get:
		return active and selected
var look: Look = Look.GHOST:
	set(val):
		look = val
		_apply_look()
## How well the stroke that left this mark was timed. Null until the cast
## it belongs to has been judged.
var judgement = null
## Ticks until this rune falls due at the caster's own tempo, negative once
## it is overdue. NAN while the caster has no tempo yet.
var ticks_until_due: float = NAN:
	set(val):
		ticks_until_due = val
		queue_redraw()
@onready var primary_texture: TextureRect = $PrimaryTexture
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

const SIZE = Vector2(60, 60)
const RADIUS = SIZE.x / 2
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

const RuneToName: Dictionary[Type, String] = {
	Type.DEVELOPMENT: "Development",
	Type.EQUIVELANCE: "Equivalence",
	Type.PERSISTENCE: "Persistence",
	Type.DECAY: "Decay",
	Type.FLOW: "Flow",
	Type.VARIABILITY: "Variability",
	Type.REFRACTION: "Refraction"
}
const RuneToScene: Dictionary[Type, String] = {
	Type.DEVELOPMENT: "res://magiteknician/engine/components/runes/Dev.tscn",
	Type.EQUIVELANCE: "res://magiteknician/engine/components/runes/Equiv.tscn",
	Type.PERSISTENCE: "res://magiteknician/engine/components/runes/Persist.tscn",
	Type.DECAY: "res://magiteknician/engine/components/runes/Decay.tscn",
	Type.FLOW: "res://magiteknician/engine/components/runes/Flow.tscn",
	Type.VARIABILITY: "res://magiteknician/engine/components/runes/Var.tscn",
	Type.REFRACTION: "res://magiteknician/engine/components/runes/Refrac.tscn"
}

static var IDToRune: Dictionary[StringName, Type] = {}
static var ActionIDToRune: Dictionary[StringName, Type] = {}

# Filled when the script loads rather than when the first rune is created,
# so the lookups work in scenes that have no runes in them.
static func _static_init():
	for rune in RuneToActionID.keys():
		ActionIDToRune[RuneToActionID[rune]] = rune
		IDToRune[RuneToID[rune]] = rune

## Makes a rune of the given type, ready to be added to a train.
## The scenes are loaded by path, not preloaded, because each of them uses a
## script that extends this one.
static func create(type: Type) -> Rune:
	var scene = load(RuneToScene[type]) as PackedScene
	var rune = scene.instantiate() as Rune
	# Each rune scene sets its own type in _ready; set it now as well so the
	# rune can be asked what it is before it enters the tree.
	rune.rune_type = type
	return rune

func _ready():
	#var parent = get_parent()
	#if in_train():
		#var train = parent as Train
		#self._config_changed.connect(train._mark_runes_dirty)
	action_id = RuneToActionID[rune_type]
	if is_bound():
		_apply_look()

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

func _apply_look():
	if not is_node_ready():
		return
	if look != Look.NEXT:
		ticks_until_due = NAN
	set_transparency(LOOK_ALPHA[look])
	set_process(look == Look.NEXT)
	queue_redraw()

## Rings the rune in the colour of how well its stroke was timed. The rune
## itself is left alone: each rune has a colour of its own to be known by.
func show_judgement(new_judgement: CastResult.Judgement):
	judgement = new_judgement
	queue_redraw()

## True when `point`, in the coordinates of this rune's parent, is on the rune.
func contains(point: Vector2) -> bool:
	return point.distance_to(position) <= RADIUS

## How far `point` is from the rune's centre: 0 at the centre, 1 at the edge.
func aim_error(point: Vector2) -> float:
	return point.distance_to(position) / RADIUS

## Strikes the rune: sounds its chime and tells whoever is listening.
func strike(timestamp_us: int, location: Vector2):
	chime()
	pressed.emit(self, timestamp_us, location)

## Sounds the rune's note without striking it.
func chime():
	audio_player.play()

## Swells the rune for a moment, to draw the eye to it.
func flash():
	var settle = create_tween().set_parallel()
	scale = Vector2.ONE * FLASH_SCALE
	set_transparency(1.0)
	settle.tween_property(self, "scale", Vector2.ONE, FLASH_SECONDS)
	settle.tween_property(primary_texture, "modulate:a", LOOK_ALPHA[look], FLASH_SECONDS)

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

# Only the next rune to strike is processed; it redraws its ring each frame.
func _process(_delta: float):
	queue_redraw()

func _draw():
	if judgement != null:
		draw_arc(Vector2.ZERO, RADIUS + 4.0, 0.0, TAU, 48, JUDGEMENT_COLORS[judgement], 4.0, true)
	if look != Look.NEXT or not is_bound():
		return
	if not is_nan(ticks_until_due):
		_draw_approach_ring()
		return
	var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU)
	var color = RING_COLOR
	color.a = lerpf(0.35, 0.9, pulse)
	draw_arc(Vector2.ZERO, RADIUS + lerpf(4.0, 9.0, pulse), 0.0, TAU, 48, color, 2.0, true)

# A ring that closes on the rune and meets its edge as the rune falls due.
func _draw_approach_ring():
	var remaining = clampf(ticks_until_due, 0.0, APPROACH_MAX_TICKS)
	var color = RING_COLOR
	if ticks_until_due < 0.0:
		# Overdue: the ring has arrived and fades the longer it waits.
		color.a = clampf(1.0 + ticks_until_due, 0.25, 1.0)
	else:
		color.a = lerpf(1.0, 0.3, remaining / APPROACH_MAX_TICKS)
	draw_arc(Vector2.ZERO, approach_radius(), 0.0, TAU, 64, color, 3.0, true)

## Radius of the approach ring for the current `ticks_until_due`.
func approach_radius() -> float:
	if is_nan(ticks_until_due):
		return RADIUS
	return RADIUS + 2.0 + clampf(ticks_until_due, 0.0, APPROACH_MAX_TICKS) * APPROACH_PX_PER_TICK

func _to_string():
	if is_bound():
		return "[%s:%d]" % [Type.keys()[rune_type], unscaled_ticks]
	return "[%s]" % [Type.keys()[rune_type]]
