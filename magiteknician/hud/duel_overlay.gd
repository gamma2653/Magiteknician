class_name DuelOverlay
extends Control
## The card shown over the arena before a duel and after it.

## The player pressed the first button.
signal confirmed
## The player pressed the second button.
signal declined

const WON_COLOR := Color(1.0, 0.87, 0.35)
const LOST_COLOR := Color(1.0, 0.45, 0.45)

@onready var heading: Label = %Heading
@onready var subheading: Label = %Subheading
@onready var body: Label = %Body
@onready var confirm: Button = %Confirm
@onready var decline: Button = %Decline


func _ready() -> void:
	confirm.pressed.connect(func (): confirmed.emit())
	decline.pressed.connect(func (): declined.emit())


## Introduces `opponent` and waits for the player to begin.
func show_introduction(opponent: Opponent) -> void:
	heading.text = opponent.display_name
	heading.modulate = Color.WHITE
	subheading.text = opponent.title
	body.text = opponent.introduction
	confirm.text = "Begin"
	decline.text = "Leave"
	show()


## Says how the duel went. `remarks` are put above the figures.
func show_verdict(duel: Duel, confirm_text: String = "Duel again", remarks: PackedStringArray = []) -> void:
	var won := duel.player_won()
	heading.text = "Victory" if won else "Defeat"
	heading.modulate = WON_COLOR if won else LOST_COLOR
	subheading.text = "against %s" % [duel.opponent.display_name]
	var lines := remarks.duplicate()
	lines.append(verdict_text(duel))
	body.text = "\n".join(lines)
	confirm.text = confirm_text
	decline.text = "Leave"
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
