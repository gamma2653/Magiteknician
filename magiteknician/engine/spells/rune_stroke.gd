@tool
class_name RuneStroke
extends Resource
## One rune of a spell: which rune, when, and where.

## The rune to strike.
@export var rune: Rune.Type = Rune.Type.FLOW
## When to strike it, in unscaled ticks from the spell's first stroke.
## Only the ratios between ticks matter; the caster sets the tempo.
@export_range(0, 64, 1, "or_greater") var tick: int = 0
## Where the rune sits, in pixels from the centre of the spell circle.
@export var position: Vector2 = Vector2.ZERO


static func make(rune_: Rune.Type, tick_: int, position_: Vector2) -> RuneStroke:
	var stroke := RuneStroke.new()
	stroke.rune = rune_
	stroke.tick = tick_
	stroke.position = position_
	return stroke


func to_dict() -> Dictionary:
	return {"rune": rune, "tick": tick, "x": position.x, "y": position.y}


static func from_dict(data: Dictionary) -> RuneStroke:
	return make(
		int(data.get("rune", Rune.Type.FLOW)) as Rune.Type,
		int(data.get("tick", 0)),
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	)


func _to_string() -> String:
	return "[%s:%d]" % [Rune.RuneToID[rune], tick]
