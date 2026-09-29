class_name DuelOverlay
extends Control
## The card shown over the arena before a duel and after it.

## The player pressed the first button.
signal confirmed
## The player pressed the second button.
signal declined

const WON_COLOR := Color(1.0, 0.87, 0.35)
const LOST_COLOR := Color(1.0, 0.45, 0.45)
const CARD_COLOUR := Color(0.09, 0.09, 0.13)
const CARD_EDGE := Color(0.75, 0.9, 1.0, 0.25)
const SCREEN_HEIGHT := 648.0

@onready var heading: Label = %Heading
@onready var subheading: Label = %Subheading
@onready var body: Label = %Body
@onready var confirm: Button = %Confirm
@onready var decline: Button = %Decline
@onready var card: PanelContainer = $Card


func _ready() -> void:
	confirm.pressed.connect(func (): confirmed.emit())
	decline.pressed.connect(func (): declined.emit())
	# A panel lets what is under it show through, and what is under this
	# one is a spell circle with runes on it.
	var face := StyleBoxFlat.new()
	face.bg_color = CARD_COLOUR
	face.border_color = CARD_EDGE
	face.set_border_width_all(1)
	face.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", face)
	card.resized.connect(_centre)
	body.item_rect_changed.connect(_centre)


# Keeps the card in the middle of the screen however much is on it.
func _centre() -> void:
	card.size.y = 0.0
	card.position.y = maxf((SCREEN_HEIGHT - card.get_combined_minimum_size().y) / 2.0, 8.0)


## Introduces `opponent` and waits for the player to begin. `prologue`
## is what happens first, and is told above the rest.
func show_introduction(opponent: Opponent, prologue: String = "") -> void:
	heading.text = opponent.display_name
	heading.modulate = Color.WHITE
	subheading.text = opponent.title
	var parts: PackedStringArray = []
	for part in [prologue, opponent.introduction, opponent.quoted(opponent.greeting)]:
		if not part.strip_edges().is_empty():
			parts.append(part.strip_edges())
	body.text = "\n\n".join(parts)
	confirm.text = "Begin"
	confirm.show()
	decline.text = "Leave"
	decline.show()
	show()


## Says how the duel went. `remarks` are put above the figures.
func show_verdict(duel: Duel, confirm_text: String = "Duel again", remarks: PackedStringArray = []) -> void:
	var parts := remarks.duplicate()
	parts.append(verdict_text(duel))
	# A line between one thing and the next: what was said, what
	# happened, what was learned, and the figures.
	show_result(duel.player_won(), duel.opponent.display_name, "\n\n".join(parts), confirm_text)


## Says who won, against whom, and whatever else there is to say. With no
## `confirm_text` there is only the one button, to leave.
func show_result(won: bool, opponent_name: String, text: String, confirm_text: String = "") -> void:
	heading.text = "Victory" if won else "Defeat"
	heading.modulate = WON_COLOR if won else LOST_COLOR
	subheading.text = "against %s" % [opponent_name]
	body.text = text
	confirm.text = confirm_text
	confirm.visible = not confirm_text.is_empty()
	decline.text = "Leave"
	decline.show()
	show()


## Puts up a notice with no buttons under it, or with one to leave by.
func show_notice(title: String, subtitle: String, text: String, can_leave: bool = false) -> void:
	heading.text = title
	heading.modulate = Color.WHITE
	subheading.text = subtitle
	body.text = text
	confirm.hide()
	decline.text = "Leave"
	decline.visible = can_leave
	show()


static func verdict_text(duel: Duel) -> String:
	var lines: PackedStringArray = []
	lines.append("The duel lasted %d seconds." % [roundi(duel.elapsed_seconds)])
	var casts := duel.player_casts.size()
	if casts == 0:
		lines.append("You did not finish a single cast.")
	else:
		var fizzles := 0
		for cast in duel.player_casts:
			if cast.fizzled:
				fizzles += 1
		var line := "You finished %d %s at a mean quality of %d%%" % [
			casts,
			"cast" if casts == 1 else "casts",
			roundi(duel.player_mean_quality() * 100.0),
		]
		if fizzles > 0:
			line += ", of which %d fizzled" % [fizzles]
		lines.append(line + ".")
	lines.append("You ended with %d health of %d." % [ceili(duel.player.health), roundi(duel.player.max_health)])
	return "\n".join(lines)
