extends Transitionable
## The campaign's list of duels: which are won, which is next, and who
## each is against.

const CLEARED_MARK := "✓"
const LOCKED_TEXT := "locked"
const NEXT_TEXT := "next"

@onready var heading: Label = %Heading
@onready var introduction: Label = %Introduction
@onready var stage_list: VBoxContainer = %StageList
@onready var opponent_name: Label = %OpponentName
@onready var opponent_title: Label = %OpponentTitle
@onready var opponent_introduction: Label = %OpponentIntroduction
@onready var knows: Label = %Knows
@onready var teaches: Label = %Teaches
@onready var best: Label = %Best
@onready var duel_button: Button = %Duel
@onready var spells_button: Button = %Spells
@onready var loadout: LoadoutPanel = $Loadout
@onready var fade: ColorRect = $FadeTransition

var selected: int = -1
var _group := ButtonGroup.new()
var _destination: String = ""


func _ready() -> void:
	if Session.save == null and not Session.continue_game():
		# Opened on its own, from the editor. Start a game to have one.
		Session.new_game()
	var campaign := Session.campaign
	heading.text = campaign.title
	introduction.text = campaign.introduction
	if Session.is_campaign_complete():
		introduction.text = "The delegation has won, for the first time. Any duel can be fought again."

	for i in campaign.stage_count():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 40)
		button.text = stage_label(i)
		button.disabled = not Session.is_unlocked(i)
		button.pressed.connect(select.bind(i))
		stage_list.add_child(button)

	spells_button.text = LoadoutPanel.summary(Session.save.bring())
	loadout.changed.connect(_on_spells_chosen)

	# Open on the duel that is next, or the last one if all are won.
	select(mini(Session.save.stages_cleared, campaign.stage_count() - 1))
	fade.end_transition()


## What the list says about the stage at `index`.
func stage_label(index: int) -> String:
	var stage := Session.campaign.stage(index)
	var status := LOCKED_TEXT
	if Session.is_cleared(index):
		status = "%s %s" % [CLEARED_MARK, best_text(stage.opponent.id)]
	elif Session.is_unlocked(index):
		status = NEXT_TEXT
	return "%d   %s   —   %s" % [index + 1, stage.opponent.display_name, status]


## The best win against an opponent, e.g. "A in 42 s", or "" if none.
func best_text(opponent_id: StringName) -> String:
	var record := Session.save.best_against(opponent_id)
	if record.is_empty():
		return ""
	var grade := CastScorer.default_tuning().grade(float(record["quality"]))
	return "%s in %d s" % [CastResult.GRADE_NAMES[grade], roundi(float(record["seconds"]))]


## Shows the stage at `index` in the panel on the right.
func select(index: int) -> void:
	var stage := Session.campaign.stage(index)
	if stage == null:
		return
	selected = index
	(stage_list.get_child(index) as Button).set_pressed_no_signal(true)
	var opponent := stage.opponent
	opponent_name.text = opponent.display_name
	opponent_title.text = opponent.title
	opponent_introduction.text = opponent.introduction
	knows.text = "Knows: %s" % [_spell_names(opponent.spell_ids)]
	teaches.text = "" if stage.reward_spell_ids.is_empty() else "Teaches: %s" % [_spell_names(stage.reward_spell_ids)]
	var record := best_text(opponent.id)
	best.text = "" if record.is_empty() else "Your best: %s" % [record]
	duel_button.disabled = not Session.is_unlocked(index)
	duel_button.text = "Duel again" if Session.is_cleared(index) else "Duel"


func _spell_names(ids: Array[StringName]) -> String:
	var names: PackedStringArray = []
	for id in ids:
		var spell := SpellLibrary.find(id)
		names.append(spell.display_name if spell != null else String(id))
	return ", ".join(names)


func _on_spells_pressed() -> void:
	loadout.open(Session.known_spells(), Session.save.bring())


func _on_spells_chosen(chosen: Array[StringName]) -> void:
	spells_button.text = LoadoutPanel.summary(Session.choose_loadout(chosen))


func _on_duel_pressed() -> void:
	if Session.enter_stage(selected):
		_go_to(Session.ARENA_SCENE)


func _on_back_pressed() -> void:
	_go_to(Session.MAIN_MENU_SCENE)


func _go_to(scene_path: String) -> void:
	if not _destination.is_empty():
		return
	_destination = scene_path
	fade.start_transition()


func _on_fade_transition_timeout() -> void:
	# The same signal fires when the fade that opens the scene ends.
	if not _destination.is_empty():
		get_tree().change_scene_to_file(_destination)
