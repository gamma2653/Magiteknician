@tool
extends Train
class_name ActualTrain
## The train a caster actually produced: a mark wherever a stroke landed,
## stamped with the moment it landed.
##
## On this train a rune's `unscaled_ticks` holds a timestamp in
## microseconds, where on an ExpectedTrain it holds a tick. They are the
## same thing in different units, and RhythmFit finds the scale between them.

## How long the marks of a finished cast stay up before they start to fade.
const LINGER_SECONDS = 0.7
const FADE_SECONDS = 0.8

## Leaves a mark for a stroke that struck `rune` at `timestamp_us` with the
## cursor at `location`, and returns it.
func record(rune: Rune, timestamp_us: int, location: Vector2) -> Rune:
	var mark = Rune.create(rune.rune_type)
	mark.position = location
	mark.unscaled_ticks = timestamp_us
	mark.look = Rune.Look.MARK
	add_child(mark)
	return mark

## Shows on each mark how well its stroke was timed.
func show_judgements(result: CastResult):
	var marks = runes
	for i in min(marks.size(), result.judgements.size()):
		marks[i].show_judgement(result.judgements[i])

## Lets the marks linger for a moment, then fades them away.
func fade_out():
	for mark in runes:
		var tween = mark.create_tween()
		tween.tween_interval(LINGER_SECONDS)
		tween.tween_property(mark, "modulate:a", 0.0, FADE_SECONDS)
		tween.tween_callback(mark.queue_free)
