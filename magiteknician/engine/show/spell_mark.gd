class_name SpellMark
extends RefCounted
## One thing a spell shows as it lands: a streak, a burst, a number.
##
## A mark is born, lasts a while, and is gone. It can be born a moment
## from now, which is how what happens where a spell lands waits for the
## spell to get there.

enum Kind {
	## The spell on its way from one duelist to the other.
	STREAK,
	## What got through, where it landed.
	BURST,
	## A ward taking a blow, on the side the blow came from.
	FLARE,
	## A ward going up.
	RAISE,
	## A ward breaking.
	SHATTER,
	## Health coming back.
	MOTES,
	## A chill taking hold.
	FROST,
	## A cast being broken.
	CRACK,
	## A cast coming to nothing.
	SPUTTER,
	## How much, in figures.
	NUMBER,
	## How well the spell was cast, as a letter.
	GRADE,
}

var kind: Kind
## Where it is. For a streak, where it arrives.
var at: Vector2
## Where a streak sets out from.
var from: Vector2
var colour: Color = Color.WHITE
## The colours of a streak along its length, from its tail to its head.
var bands: PackedColorArray = []
## How big it is: a radius, a width, or the height of its letters.
var size: float = 1.0
## For a mark that is drawn round a spell circle, the radius of the circle.
var radius: float = 0.0
## For a flare, the way the blow came from.
var facing: Vector2 = Vector2.RIGHT
var text: String = ""
## True for the mark of a cast that earned the best grade.
var is_flawless: bool = false
## How much the mark is of what it could be, from 0 to 1: how hard a
## blow, how well cast a ward. It is how loud the mark sounds.
var strength: float = 1.0
## True for a mark that comes of another: what a ward turned back, and
## the second ring of a ward that turns blows back.
var is_echo: bool = false
## True once whoever sounds the marks has been told of this one.
var is_announced: bool = false
var born_usec: int = 0
var seconds: float = 1.0
## Settles where whatever the mark scatters goes, so that it goes the same
## way in every frame.
var scatter: int = 0


func _init(kind_: Kind, at_: Vector2, born_usec_: int, seconds_: float) -> void:
	kind = kind_
	at = at_
	born_usec = born_usec_
	seconds = seconds_


## Seconds since the mark was born. Negative before it is.
func age(now_usec: int) -> float:
	return (now_usec - born_usec) / 1_000_000.0


## How far through its life the mark is, from 0 to 1.
func progress(now_usec: int) -> float:
	if seconds <= 0.0:
		return 1.0
	return clampf(age(now_usec) / seconds, 0.0, 1.0)


func is_born(now_usec: int) -> bool:
	return now_usec >= born_usec


func is_over(now_usec: int) -> bool:
	return age(now_usec) >= seconds
