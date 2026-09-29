extends Transitionable
## A place to cast with nothing at stake: pick a spell, cast it, read the
## verdict, cast it again.

@onready var circle: SpellCircle = $SpellCircle
@onready var spell_bar: SpellBar = %SpellBar
@onready var spell_info: SpellInfo = %SpellInfo
@onready var result_panel: ResultPanel = %ResultPanel

## The spells on offer. Left empty, the range offers every spell there
## is, and those the player has made after them.
@export var spellbook: Spellbook

var _leaving: bool = false
var _destination: String = Session.MAIN_MENU_SCENE


func _ready() -> void:
	$HUD/FadeTransition.end_transition()
	spell_bar.spell_chosen.connect(_on_spell_chosen)
	circle.cast_finished.connect(_on_cast_finished)
	if spellbook == null:
		spellbook = Spellbook.with_what_was_made()
	spell_bar.spellbook = spellbook
	# Come back from the workshop, the range opens on what was made there.
	if Session.spell_to_practise != null and spell_bar.choose_spell(SpellLibrary.find(Session.spell_to_practise.id)):
		pass
	else:
		spell_bar.choose(0)
	Session.spell_to_practise = null


func _on_spell_chosen(spell: Spell) -> void:
	circle.prepare(spell)
	spell_info.show_spell(spell)
	result_panel.clear()


func _on_cast_finished(spell: Spell, result: CastResult) -> void:
	result_panel.show_result(spell, result)


func _on_back_pressed() -> void:
	_go_to(Session.MAIN_MENU_SCENE)


func _on_workshop_pressed() -> void:
	# The workshop opens on the spell that is on the circle, if it is one
	# that was made.
	Session.spell_to_practise = circle.spell if SpellForge.is_made(circle.spell) else null
	_go_to(Session.WORKSHOP_SCENE)


func _go_to(scene_path: String) -> void:
	if _leaving:
		return
	_leaving = true
	_destination = scene_path
	circle.accepts_input = false
	$HUD/FadeTransition.start_transition()


func _on_fade_transition_timeout() -> void:
	# The same signal fires when the fade that opens the scene ends.
	if _leaving:
		get_tree().change_scene_to_file(_destination)
