extends Transitionable
## A place to cast with nothing at stake: pick a spell, cast it, read the
## verdict, cast it again.

@onready var circle: SpellCircle = $SpellCircle
@onready var spell_bar: SpellBar = %SpellBar
@onready var spell_info: SpellInfo = %SpellInfo
@onready var result_panel: ResultPanel = %ResultPanel

## The spells on offer. Left empty, the range offers every spell there is.
@export var spellbook: Spellbook

var _leaving: bool = false


func _ready() -> void:
	$HUD/FadeTransition.end_transition()
	spell_bar.spell_chosen.connect(_on_spell_chosen)
	circle.cast_finished.connect(_on_cast_finished)
	if spellbook == null:
		spellbook = Spellbook.complete()
	spell_bar.spellbook = spellbook
	spell_bar.choose(0)


func _on_spell_chosen(spell: Spell) -> void:
	circle.prepare(spell)
	spell_info.show_spell(spell)
	result_panel.clear()


func _on_cast_finished(spell: Spell, result: CastResult) -> void:
	result_panel.show_result(spell, result)


func _on_back_pressed() -> void:
	_leaving = true
	circle.accepts_input = false
	$HUD/FadeTransition.start_transition()


func _on_fade_transition_timeout() -> void:
	# The same signal fires when the fade that opens the scene ends.
	if _leaving:
		get_tree().change_scene_to_packed(Loader.LEVELS["menu"]["main_menu"].call())
