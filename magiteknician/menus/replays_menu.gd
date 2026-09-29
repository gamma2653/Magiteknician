extends Transitionable
## The duels that have been recorded, the newest first. Choose one to
## watch it.

const NONE_YET := "No duel has been recorded yet. Every duel you finish is, against an NPC or as the host of a duel against another player."

@onready var explanation: Label = %Explanation
@onready var list: VBoxContainer = %List
@onready var heading: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var brought: Label = %Brought
@onready var watch_button: Button = %Watch
@onready var fade: ColorRect = $FadeTransition

var recordings: Array[DuelRecording] = []
var selected: int = -1
var _group := ButtonGroup.new()
var _destination: String = ""


func _ready() -> void:
	recordings = DuelRecording.all_in(Session.replay_dir)
	explanation.text = NONE_YET if recordings.is_empty() else "The last %d duels are kept." % [DuelRecording.KEEP]
	for i in recordings.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 40)
		button.clip_text = true
		button.text = "%s   —   %d s" % [recordings[i].title(), roundi(recordings[i].seconds)]
		button.pressed.connect(select.bind(i))
		list.add_child(button)
	watch_button.disabled = true
	heading.text = ""
	subtitle.text = ""
	brought.text = ""
	if not recordings.is_empty():
		select(0)
	fade.end_transition()


## Shows the recording at `index` in the panel on the right.
func select(index: int) -> void:
	if index < 0 or index >= recordings.size():
		return
	selected = index
	(list.get_child(index) as Button).set_pressed_no_signal(true)
	var recording := recordings[index]
	heading.text = recording.title()
	subtitle.text = recording.subtitle()
	brought.text = "%s brought %s.\n%s brought %s." % [
		recording.name_of(DuelRecording.PLAYER), _spell_names(recording, DuelRecording.PLAYER),
		recording.name_of(DuelRecording.OPPONENT), _spell_names(recording, DuelRecording.OPPONENT),
	]
	watch_button.disabled = not recording.problems().is_empty()


func _spell_names(recording: DuelRecording, side: int) -> String:
	var names: PackedStringArray = []
	for spell in recording.duelist(side).spellbook.spells:
		names.append(spell.display_name)
	return ", ".join(names) if not names.is_empty() else "nothing"


func _on_watch_pressed() -> void:
	if selected < 0:
		return
	Session.replay = recordings[selected]
	_go_to(Session.REPLAY_ARENA_SCENE)


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
