extends Transitionable
## Where a spell is made.
##
## A spell is made on the circle it will be cast on. A rune is put down
## where it is wanted, by clicking there or by pressing the rune's key
## with the cursor there, and the spell is its runes in the order they
## were put down. What the spell does follows from its runes, by the
## RuneGrammar, and is told as it changes.
##
## The spell can be heard, and tried, before it is kept.

## The id a spell has while it is being made and has not been kept.
const DRAFT_ID := &"made_draft"
const NOTHING_YET := "Click on the circle to put down a rune, or press a rune's key with the cursor where it is to go."
const KEPT := "Kept. It is in the practice range, and can be brought to a duel."
const NO_ROOM := "%d spells can be kept, and there are %d. Throw one away to keep another."
const TRYING := "Cast it. Give up with %s."
const SELECTED_COLOUR := Color(0.55, 0.85, 1.0, 0.95)
const NUMBER_COLOUR := Color(1.0, 1.0, 1.0, 0.85)

@onready var circle: SpellCircle = $SpellCircle
@onready var marks: Node2D = $Marks
@onready var name_box: LineEdit = %Name
@onready var rune_row: HBoxContainer = %Runes
@onready var purpose: Label = %Purpose
@onready var chosen_stroke: Label = %ChosenStroke
@onready var sooner: Button = %Sooner
@onready var later: Button = %Later
@onready var take_out: Button = %TakeOut
@onready var formula: Label = %Formula
@onready var does: Label = %Does
@onready var cost: Label = %Cost
@onready var notes: Label = %Notes
@onready var hear_button: Button = %Hear
@onready var try_button: Button = %Try
@onready var keep_button: Button = %Keep
@onready var discard_button: Button = %Discard
@onready var shelf: HBoxContainer = %Shelf
@onready var fade: ColorRect = %FadeTransition

## The runes of the spell that is being made, in the order they are struck.
var strokes: Array[RuneStroke] = []
## The id of the spell that is being changed, or "" for one that is new.
var editing_id: StringName = &""
## The rune that a click puts down.
var chosen_rune: Rune.Type = Rune.Type.FLOW
## Which stroke is chosen, to be moved in time or taken out. -1 for none.
var chosen: int = -1
## True while the spell is being tried and not made.
var is_trying: bool = false
var grammar: RuneGrammar = RuneGrammar.usual()

var _dragging: int = -1
var _rune_buttons: Dictionary[Rune.Type, Button] = {}
var _said: String = ""
var _destination: String = ""


func _ready() -> void:
	circle.accepts_input = false
	circle.cast_finished.connect(_on_cast_finished)
	marks.draw.connect(_draw_marks)
	var runes := ButtonGroup.new()
	for type in Rune.Type.values():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = runes
		button.custom_minimum_size = Vector2(52, 52)
		button.icon = RunePalette.texture_of(type, Settings.palette)
		button.expand_icon = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "%s  %s\n%s" % [Rune.RuneToID[type], Rune.RuneToName[type], RuneGrammar.what_it_is_for(type)]
		button.pressed.connect(choose_rune.bind(type))
		rune_row.add_child(button)
		_rune_buttons[type] = button
	name_box.max_length = SpellForge.MAX_NAME_LENGTH
	name_box.text_changed.connect(func (_text): _show())
	name_box.text_submitted.connect(func (_text): name_box.release_focus())
	choose_rune(chosen_rune)
	_fill_shelf()
	if SpellForge.is_made(Session.spell_to_practise):
		open(SpellLibrary.find(Session.spell_to_practise.id))
	Session.spell_to_practise = null
	_show()
	fade.end_transition()


## The spell as it stands, with what it does worked out.
func spell() -> Spell:
	return SpellForge.make(name_box.text, strokes, editing_id if not editing_id.is_empty() else DRAFT_ID, grammar)


## Everything that stops the spell being kept. Empty when it can be.
func problems() -> PackedStringArray:
	return grammar.problems(strokes)


## Chooses the rune that a click puts down.
func choose_rune(type: Rune.Type) -> void:
	chosen_rune = type
	_rune_buttons[type].set_pressed_no_signal(true)
	purpose.text = "%s  %s. %s" % [Rune.RuneToID[type], Rune.RuneToName[type], RuneGrammar.what_it_is_for(type)]


## Puts down a rune of `type` at `where` on the circle, to be struck a
## tick after the last. Returns false, and changes nothing, if it cannot
## go there.
func place(type: Rune.Type, where: Vector2) -> bool:
	if is_trying or strokes.size() >= RuneGrammar.MAX_STROKES or not has_room_at(where):
		return false
	var tick := 0 if strokes.is_empty() else strokes[-1].tick + 1
	strokes.append(RuneStroke.make(type, tick, where.round()))
	chosen = strokes.size() - 1
	_said = ""
	_show()
	return true


## True if a rune can be at `where`: it is on the circle, and on no other
## rune but the one at `but_for`.
func has_room_at(where: Vector2, but_for: int = -1) -> bool:
	if where.length() > Spell.CIRCLE_RADIUS:
		return false
	for i in strokes.size():
		if i != but_for and strokes[i].position.distance_to(where) < RuneGrammar.MIN_APART:
			return false
	return true


## The stroke whose rune is at `where`, or -1.
func stroke_at(where: Vector2) -> int:
	for i in range(strokes.size() - 1, -1, -1):
		if strokes[i].position.distance_to(where) <= Rune.RADIUS:
			return i
	return -1


## Moves the rune of the stroke at `index` to `where`. Returns false, and
## changes nothing, if it cannot go there.
func move(index: int, where: Vector2) -> bool:
	if is_trying or index < 0 or index >= strokes.size() or not has_room_at(where, index):
		return false
	strokes[index].position = where.round()
	_show()
	return true


## Takes out the stroke at `index`. Those after it are struck as long
## after those before it as they were.
func remove(index: int) -> void:
	if is_trying or index < 0 or index >= strokes.size():
		return
	var gaps := _gaps()
	strokes.remove_at(index)
	gaps.remove_at(index)
	_set_gaps(gaps)
	chosen = mini(index, strokes.size() - 1)
	_said = ""
	_show()


## How many ticks the stroke at `index` is after the one before it.
func gap_before(index: int) -> int:
	if index <= 0 or index >= strokes.size():
		return 0
	return strokes[index].tick - strokes[index - 1].tick


## Has the stroke at `index` be struck `ticks` after the one before it.
## Those after it follow it, as long after as they were.
func set_gap(index: int, ticks: int) -> void:
	if is_trying or index <= 0 or index >= strokes.size():
		return
	var gaps := _gaps()
	gaps[index] = clampi(ticks, 1, RuneGrammar.MAX_GAP)
	_set_gaps(gaps)
	_said = ""
	_show()


## Begins a new spell, with nothing on the circle.
func clear() -> void:
	stop_trying()
	strokes = []
	editing_id = &""
	chosen = -1
	name_box.text = ""
	_said = ""
	_show()


## Takes `made`, a spell that was kept, to be changed.
func open(made: Spell) -> void:
	if not SpellForge.is_made(made):
		return
	stop_trying()
	strokes = []
	for stroke in made.strokes:
		strokes.append(RuneStroke.make(stroke.rune, stroke.tick, stroke.position))
	editing_id = made.id
	name_box.text = made.display_name
	chosen = -1
	_said = ""
	_show()


## Keeps the spell. Returns false, and says why, if it cannot be kept.
func keep() -> bool:
	if not problems().is_empty():
		return false
	var made := SpellForge.make(name_box.text, strokes, editing_id, grammar)
	if editing_id.is_empty() and SpellLibrary.made().size() >= SpellForge.MOST:
		_said = NO_ROOM % [SpellForge.MOST, SpellLibrary.made().size()]
		_show()
		return false
	if SpellForge.keep(made, SpellLibrary.made_dir) != OK:
		_said = "It could not be kept."
		_show()
		return false
	editing_id = made.id
	name_box.text = made.display_name
	_said = KEPT
	_fill_shelf()
	_show()
	return true


## Throws away the spell that is being changed, and begins a new one.
func discard() -> void:
	if not editing_id.is_empty():
		SpellForge.discard(editing_id, SpellLibrary.made_dir)
	clear()
	_fill_shelf()


## Plays the spell through, a rune on each of its ticks.
func hear() -> bool:
	if strokes.is_empty():
		return false
	return circle.demonstrate()


## Lets the spell be cast, as it would be in a duel.
func try_it() -> bool:
	if is_trying or not problems().is_empty():
		return false
	is_trying = true
	chosen = -1
	_dragging = -1
	name_box.release_focus()
	_said = TRYING % [KeyBindings.name_of(KeyBindings.key_of(SpellCircle.ABANDON_ACTION))]
	_show()
	circle.accepts_input = true
	return true


## Goes back to making the spell.
func stop_trying() -> void:
	if not is_trying:
		return
	is_trying = false
	circle.accepts_input = false
	circle.abandon()
	circle.cadence.drop()
	_said = ""
	_show()


func _gaps() -> Array[int]:
	var gaps: Array[int] = []
	for i in strokes.size():
		gaps.append(gap_before(i))
	return gaps


# Has the strokes be struck `gaps` apart, the first of which is of no
# account: the first stroke is on tick 0.
func _set_gaps(gaps: Array[int]) -> void:
	var tick := 0
	for i in strokes.size():
		if i > 0:
			tick += maxi(gaps[i], 1)
		strokes[i].tick = tick


func _show() -> void:
	if not is_node_ready():
		return
	var made := spell()
	if strokes.is_empty():
		circle.prepare(null)
	elif not is_trying or circle.spell == null or circle.spell.strokes.size() != strokes.size():
		circle.prepare(made)

	formula.text = NOTHING_YET if strokes.is_empty() else SpellInfo.formula_text(made)
	does.text = made.describe_effects()
	cost.text = "" if made.effects.is_empty() else "%s · %s · %s to cast" % [
		SpellInfo.cost_text(made), Spell.RANK_NAMES[made.rank], RuneGrammar.difficulty_name(grammar.difficulty_of(strokes)),
	]
	var lines: PackedStringArray = []
	if not _said.is_empty():
		lines.append(_said)
	if not strokes.is_empty():
		lines.append_array(problems())
		lines.append_array(grammar.idle_runes(strokes))
	notes.text = "\n".join(lines)

	var has_one := chosen >= 0 and chosen < strokes.size()
	if has_one:
		var stroke := strokes[chosen]
		chosen_stroke.text = "%d  %s" % [chosen + 1, Rune.RuneToID[stroke.rune]]
		if chosen > 0:
			chosen_stroke.text += "   %d %s after %d" % [gap_before(chosen), "tick" if gap_before(chosen) == 1 else "ticks", chosen]
		else:
			chosen_stroke.text += "   the first stroke"
	else:
		chosen_stroke.text = "No rune is chosen"
	sooner.disabled = is_trying or not has_one or chosen == 0 or gap_before(chosen) <= 1
	later.disabled = is_trying or not has_one or chosen == 0 or gap_before(chosen) >= RuneGrammar.MAX_GAP
	take_out.disabled = is_trying or not has_one
	hear_button.disabled = strokes.is_empty() or is_trying
	try_button.disabled = not problems().is_empty()
	try_button.text = "Go back to making it" if is_trying else "Try it"
	keep_button.disabled = is_trying or not problems().is_empty()
	discard_button.disabled = is_trying or (editing_id.is_empty() and strokes.is_empty())
	discard_button.text = "Throw away" if not editing_id.is_empty() else "Start again"
	name_box.editable = not is_trying
	for button: Button in _rune_buttons.values():
		button.disabled = is_trying
	for button: Button in shelf.get_children():
		button.disabled = is_trying
		if button.has_meta("id"):
			button.set_pressed_no_signal(button.get_meta("id") == editing_id)
	marks.queue_redraw()


# The spells that have been made, to be taken up and changed.
func _fill_shelf() -> void:
	for child in shelf.get_children():
		shelf.remove_child(child)
		child.queue_free()
	for made in SpellLibrary.made():
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(116, 64)
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.text = "%s\n%s" % [made.display_name, SpellInfo.cost_text(made)]
		button.tooltip_text = "%s\n%s" % [made.formula(), made.describe_effects()]
		button.set_meta("id", made.id)
		button.pressed.connect(open.bind(made))
		shelf.add_child(button)
	var fresh := Button.new()
	fresh.custom_minimum_size = Vector2(116, 64)
	fresh.focus_mode = Control.FOCUS_NONE
	fresh.text = "A new spell"
	fresh.pressed.connect(clear)
	shelf.add_child(fresh)


# The number of each stroke beside its rune, and a ring round the one
# that is chosen.
func _draw_marks() -> void:
	if strokes.is_empty():
		# The circle draws nothing until it has a spell. This is where
		# the first rune can go.
		marks.draw_arc(circle.position, Spell.CIRCLE_RADIUS + Rune.RADIUS, 0.0, TAU, 96, SpellCircle.BOUNDARY_COLOR, 2.0, true)
	if is_trying:
		return
	var font := ThemeDB.fallback_font
	for i in strokes.size():
		var at := circle.position + strokes[i].position
		if i == chosen:
			marks.draw_arc(at, Rune.RADIUS + 10.0, 0.0, TAU, 48, SELECTED_COLOUR, 3.0, true)
		var where := at + Vector2(Rune.RADIUS * 0.75, -Rune.RADIUS * 0.75)
		marks.draw_string_outline(font, where, str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, 4, Color(0.03, 0.03, 0.06, 0.9))
		marks.draw_string(font, where, str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, NUMBER_COLOUR)


func _unhandled_input(event: InputEvent) -> void:
	if is_trying or not _destination.is_empty():
		if is_trying and event.is_action_pressed(SpellCircle.ABANDON_ACTION) and circle.state != SpellCircle.State.CASTING:
			stop_trying()
		return
	if event is InputEventMouseButton:
		var where: Vector2 = circle.make_input_local(event).position
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			name_box.release_focus()
			var index := stroke_at(where)
			if index >= 0:
				chosen = index
				_dragging = index
				_show()
			else:
				place(chosen_rune, where)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = -1
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			remove(stroke_at(where))
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _dragging >= 0:
		move(_dragging, circle.make_input_local(event).position)
		return
	if event.is_echo():
		return
	for type in Rune.Type.values():
		if event.is_action_pressed(Rune.RuneToActionID[type]):
			choose_rune(type)
			place(type, circle.get_local_mouse_position())
			get_viewport().set_input_as_handled()
			return


func _on_cast_finished(_spell: Spell, result: CastResult) -> void:
	_said = "%s %s" % [ResultPanel.summary_text(result).replace("\n", " "), ResultPanel.judgements_text(result)]
	_show()


func _on_sooner_pressed() -> void:
	set_gap(chosen, gap_before(chosen) - 1)


func _on_later_pressed() -> void:
	set_gap(chosen, gap_before(chosen) + 1)


func _on_take_out_pressed() -> void:
	remove(chosen)


func _on_hear_pressed() -> void:
	hear()


func _on_try_pressed() -> void:
	if is_trying:
		stop_trying()
	else:
		try_it()


func _on_keep_pressed() -> void:
	keep()


func _on_discard_pressed() -> void:
	discard()


func _on_back_pressed() -> void:
	# The practice range opens on the spell that was being made, if it
	# was kept.
	Session.spell_to_practise = SpellLibrary.find(editing_id) if not editing_id.is_empty() else null
	_go_to(Session.PRACTICE_SCENE)


func _go_to(scene_path: String) -> void:
	if not _destination.is_empty():
		return
	stop_trying()
	_destination = scene_path
	fade.start_transition()


func _on_fade_transition_timeout() -> void:
	# The same signal fires when the fade that opens the scene ends.
	if not _destination.is_empty():
		get_tree().change_scene_to_file(_destination)
