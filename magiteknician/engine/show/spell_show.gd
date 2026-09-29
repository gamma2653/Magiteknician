class_name SpellShow
extends Node2D
## What a spell looks like when it lands.
##
## The rules say what a cast did, and this shows it: the spell crossing
## from one circle to the other, what it did when it got there, and how
## well it was cast. It also keeps up what lasts, which is a ward round a
## duelist and the frost on one who is chilled.
##
## It changes nothing. It is told what happened and has no say in it, so a
## duel comes out the same with it as without it.
##
## How much a spell did is how big it is drawn. A cast's potency sets the
## width of its streak, and what got through sets the size of its burst.
##
## The streak is the spell's runes. It is banded in their colours, in the
## order they were struck, and it sets out from the last of them.
##
## What is shown is also heard. Each mark is announced as it is born, and
## a SpellVoice plays the sound that goes with it.

## `mark` has been born: it is on the screen from now.
signal mark_born(mark: SpellMark)

## Seconds a streak takes to cross. It is short, because the rules have
## already applied the spell by the time it sets out: a duelist's health
## drops as the last stroke lands, and the streak must not be long after.
const TRAVEL_SECONDS := 0.14
## Seconds a streak takes to fade once it has arrived.
const STREAK_FADE_SECONDS := 0.3
const STREAK_MIN_WIDTH := 3.0
const STREAK_MAX_WIDTH := 11.0

const BURST_SECONDS := 0.45
const BURST_MIN_SIZE := 22.0
const BURST_PER_DAMAGE := 2.4
const BURST_MAX_SIZE := 105.0

const FLARE_SECONDS := 0.4
const RAISE_SECONDS := 0.5
const SHATTER_SECONDS := 0.6
const MOTES_SECONDS := 0.9
const FROST_SECONDS := 0.7
const CRACK_SECONDS := 0.6
const SPUTTER_SECONDS := 0.5
const NUMBER_SECONDS := 1.0
const NUMBER_RISE := 34.0
const NUMBER_MIN_HEIGHT := 20.0
const NUMBER_MAX_HEIGHT := 34.0
## Damage that is written as large as a number gets.
const NUMBER_FULL_AT := 30.0
const NUMBER_SPACING := 26.0
const GRADE_SECONDS := 0.9
const GRADE_HEIGHT := 40.0
## A cast that fizzled is written out, and smaller.
const FIZZLE_HEIGHT := 24.0
## How far from a spell circle what is written beside it is written.
const WRITING_GAP := 40.0
## How far above the path of the spell its grade is written, and how far
## below it the first of the numbers.
const GRADE_LIFT := 34.0
const NUMBER_DROP := 26.0

## How far outside a spell circle its ward is drawn.
const WARD_GAP := 9.0
const WARD_MIN_WIDTH := 2.5
const WARD_MAX_WIDTH := 7.0
## A ward that soaks up this much is drawn as thick as a ward gets.
const WARD_FULL_AT := 30.0
const FROST_TEETH := 36

const KIND_COLOURS: Dictionary[SpellEffect.Kind, Color] = {
	SpellEffect.Kind.DAMAGE: Color(1.0, 0.66, 0.34),
	SpellEffect.Kind.WARD: Color(0.56, 0.84, 1.0),
	SpellEffect.Kind.HEAL: Color(0.55, 1.0, 0.62),
	SpellEffect.Kind.BATTER: Color(0.88, 0.84, 0.74),
	SpellEffect.Kind.INTERRUPT: Color(1.0, 0.45, 0.8),
	SpellEffect.Kind.CHILL: Color(0.74, 0.93, 1.0),
	SpellEffect.Kind.REFLECT: Color(0.84, 0.76, 1.0),
}
const GRADE_COLOURS: Dictionary[CastResult.Grade, Color] = {
	CastResult.Grade.S: Color(1.0, 0.87, 0.35),
	CastResult.Grade.A: Color(0.5, 1.0, 0.55),
	CastResult.Grade.B: Color(0.5, 0.8, 1.0),
	CastResult.Grade.C: Color(0.85, 0.85, 0.85),
	CastResult.Grade.D: Color(1.0, 0.62, 0.3),
	CastResult.Grade.FIZZLE: Color(1.0, 0.35, 0.35),
}
const SPUTTER_COLOUR := Color(0.7, 0.7, 0.75)
## A blow of this much is as hard as a blow is taken to get, for how it
## sounds. It is the most that any spell does.
const HARDEST_BLOW := 32.0
const OUTLINE_COLOUR := Color(0.03, 0.03, 0.06, 0.85)


## Where a duelist stands, and what is kept up round them.
class Stand:
	var duelist: Duelist
	var circle: SpellCircle
	var centre: Vector2
	## The radius of their spell circle, as it is on the screen.
	var radius: float
	## How much smaller than life their side of the duel is drawn.
	var scale: float = 1.0
	## How long the ward was to last when it was raised, in seconds.
	var ward_span: float = 0.0
	var ward_seconds_left: float = 0.0
	## How long the chill was to last when it took hold.
	var chill_span: float = 0.0
	var chill_seconds_left: float = 0.0

	## Where a point on the duelist's spell circle is on the screen.
	func on_screen(on_circle: Vector2) -> Vector2:
		return centre + on_circle * scale

	## The point on the rim of the circle that is nearest to `other`.
	func rim_towards(other: Vector2, beyond: float = 0.0) -> Vector2:
		return centre + centre.direction_to(other) * (radius + beyond)

	## What is drawn for this duelist is drawn this much smaller than life.
	## Less than their circle is, so that it can still be seen.
	func drawn_scale() -> float:
		return lerpf(1.0, scale, 0.6)

	## And what is written for them, which has to be read.
	func written_scale() -> float:
		return lerpf(1.0, scale, 0.3)

	## Where the line from `inside`, which is in the circle, to `outside`
	## is `beyond` past the rim.
	func crossing(inside: Vector2, outside: Vector2, beyond: float = 0.0) -> Vector2:
		var reach := radius + beyond
		var along := outside - inside
		var out := inside - centre
		var a := along.length_squared()
		var b := 2.0 * out.dot(along)
		var c := out.length_squared() - reach * reach
		var under := b * b - 4.0 * a * c
		if a <= 0.0 or c > 0.0 or under < 0.0:
			return rim_towards(outside, beyond)
		return inside + along * ((-b + sqrt(under)) / (2.0 * a))


## The marks that are showing or are about to, oldest first.
var marks: Array[SpellMark] = []
## What sounds the marks. Set `is_on` false on it for a show with no sound.
var voice: SpellVoice

var _stands: Dictionary[Duelist, Stand] = {}
var _scattered: int = 0
# Where what is written beside each duelist is written, for the spell
# that is being shown.
var _beside: Dictionary[Duelist, Vector2] = {}


func _ready() -> void:
	voice = SpellVoice.new()
	voice.name = "Voice"
	add_child(voice)
	mark_born.connect(voice.sound)


## Says that `duelist` casts on `circle`, which is where what happens to
## them is shown.
func place(duelist: Duelist, circle: SpellCircle) -> void:
	var stand := Stand.new()
	stand.duelist = duelist
	stand.circle = circle
	stand.scale = circle.global_scale.x
	stand.centre = to_local(circle.global_position)
	stand.radius = (Spell.CIRCLE_RADIUS + Rune.RADIUS) * stand.scale
	_stands[duelist] = stand
	observe()


func stand_of(duelist: Duelist) -> Stand:
	return _stands.get(duelist)


## Shows what `outcome` says happened.
func show_outcome(outcome: SpellOutcome, now_usec: int = Time.get_ticks_usec()) -> void:
	if outcome == null or outcome.spell == null:
		return
	var caster := stand_of(outcome.caster)
	var target := stand_of(outcome.target)
	if caster == null or target == null:
		return

	# The spell sets out from the last rune that was struck, and what is
	# written is written beside the path it takes.
	var last_rune := caster.centre
	if not outcome.spell.strokes.is_empty():
		last_rune = caster.on_screen(outcome.spell.strokes[-1].position)
	var landing := target.centre if outcome.fizzled else _landing(outcome, caster, target)
	var origin := last_rune + last_rune.direction_to(landing) * Rune.RADIUS * caster.scale
	var gap := WRITING_GAP * caster.written_scale()
	_beside[outcome.caster] = caster.crossing(last_rune, landing, gap)
	_beside[outcome.target] = target.crossing(landing, last_rune, gap)

	var grade_of := outcome.result.grade if outcome.result != null else CastResult.Grade.FIZZLE
	var grade := _add(SpellMark.Kind.GRADE, _beside[outcome.caster] + Vector2(0.0, -GRADE_LIFT * caster.written_scale()), now_usec, GRADE_SECONDS)
	grade.text = CastResult.GRADE_NAMES[grade_of]
	grade.colour = GRADE_COLOURS[grade_of]
	grade.size = (FIZZLE_HEIGHT if outcome.fizzled else GRADE_HEIGHT) * caster.written_scale()

	if outcome.fizzled:
		var sputter := _add(SpellMark.Kind.SPUTTER, origin, now_usec, SPUTTER_SECONDS)
		sputter.colour = SPUTTER_COLOUR
		sputter.size = 26.0 * caster.drawn_scale()
		sputter.strength = 0.6
		queue_redraw()
		return

	var strength := clampf(outcome.result.potency, 0.0, 1.0)
	var flawless := outcome.result.grade == CastResult.Grade.S
	var arrives_usec := now_usec
	if _reaches(outcome, outcome.target):
		arrives_usec = now_usec + int(TRAVEL_SECONDS * 1_000_000)
		var streak := _add(SpellMark.Kind.STREAK, landing, now_usec, TRAVEL_SECONDS + STREAK_FADE_SECONDS)
		streak.from = origin
		streak.bands = bands_of(outcome.spell)
		streak.colour = streak.bands[0] if not streak.bands.is_empty() else Color.WHITE
		streak.size = lerpf(STREAK_MIN_WIDTH, STREAK_MAX_WIDTH, strength) * target.drawn_scale()
		streak.is_flawless = flawless

	# How many numbers have been written beside each duelist, so that the
	# next is written under them.
	var written: Dictionary[Duelist, int] = {}
	for entry in outcome.entries:
		var on: Stand = stand_of(entry.get("on"))
		if on == null:
			continue
		var kind: SpellEffect.Kind = entry["kind"]
		var colour := KIND_COLOURS[kind]
		var other := target if on == caster else caster
		var amount := float(entry.get("amount", 0.0))
		match kind:
			SpellEffect.Kind.DAMAGE:
				var absorbed := float(entry.get("absorbed", 0.0))
				var through := float(entry.get("through", 0.0))
				var reflected := float(entry.get("reflected", 0.0))
				if absorbed > 0.0:
					_flare(on, other, arrives_usec, KIND_COLOURS[SpellEffect.Kind.WARD], absorbed)
					_number(on, other, written, "%d warded" % [roundi(absorbed)], KIND_COLOURS[SpellEffect.Kind.WARD], 0.0, arrives_usec)
				if through > 0.0:
					var burst := _add(SpellMark.Kind.BURST, on.centre, arrives_usec, BURST_SECONDS)
					burst.colour = colour
					burst.size = burst_size(through) * on.drawn_scale()
					burst.is_flawless = flawless
					burst.strength = blow_strength(through)
					_number(on, other, written, "%d" % [maxi(roundi(through), 1)], colour, through, arrives_usec)
				if reflected > 0.0:
					_turn_back(on, other, landing, last_rune, reflected, arrives_usec, written)
			SpellEffect.Kind.BATTER:
				if entry.get("landed", false):
					_flare(on, other, arrives_usec, colour, amount)
					_number(on, other, written, "%d off the ward" % [roundi(amount)], colour, 0.0, arrives_usec)
			SpellEffect.Kind.INTERRUPT:
				if entry.get("broke") != null:
					var crack := _add(SpellMark.Kind.CRACK, on.centre, arrives_usec, CRACK_SECONDS)
					crack.colour = colour
					crack.radius = on.radius
					crack.size = 3.0 * on.drawn_scale()
					crack.strength = strength
					_number(on, other, written, "broken", colour, 0.0, arrives_usec)
			SpellEffect.Kind.CHILL:
				var frost := _add(SpellMark.Kind.FROST, on.centre, arrives_usec, FROST_SECONDS)
				frost.colour = colour
				frost.radius = on.radius
				frost.size = on.radius * 0.45
				frost.strength = strength
			SpellEffect.Kind.WARD, SpellEffect.Kind.REFLECT:
				if entry.get("landed", false):
					var raise := _add(SpellMark.Kind.RAISE, on.centre, now_usec, RAISE_SECONDS)
					raise.colour = colour
					raise.radius = on.radius + WARD_GAP * on.scale
					raise.size = lerpf(WARD_MAX_WIDTH, WARD_MAX_WIDTH * 2.0, strength) * on.drawn_scale()
					raise.strength = strength
					raise.is_echo = kind == SpellEffect.Kind.REFLECT
			SpellEffect.Kind.HEAL:
				if amount > 0.0:
					var motes := _add(SpellMark.Kind.MOTES, on.centre, now_usec, MOTES_SECONDS)
					motes.colour = colour
					motes.radius = on.radius
					motes.size = clampf(amount, 4.0, 24.0)
					motes.strength = strength
					_number(on, other, written, "+%d" % [maxi(roundi(amount), 1)], colour, amount, now_usec)
		if entry.get("broke_ward", false):
			var shatter := _add(SpellMark.Kind.SHATTER, on.centre, arrives_usec, SHATTER_SECONDS)
			shatter.colour = KIND_COLOURS[SpellEffect.Kind.WARD]
			shatter.radius = on.radius + WARD_GAP * on.scale
			shatter.size = 46.0 * on.drawn_scale()
	queue_redraw()


## Tells whoever is listening of the marks that have been born by
## `now_usec` and have not been told of yet.
func announce(now_usec: int = Time.get_ticks_usec()) -> void:
	for mark in marks:
		if not mark.is_announced and mark.is_born(now_usec):
			mark.is_announced = true
			mark_born.emit(mark)


## How hard a blow of `amount` is, from 0 to 1.
static func blow_strength(amount: float) -> float:
	return clampf(amount / HARDEST_BLOW, 0.0, 1.0)


## The colours of a spell's streak from its tail to its head: those of its
## runes, from the last struck to the first. The streak sets out from the
## last rune, and the first rune is the first to arrive.
static func bands_of(spell: Spell) -> PackedColorArray:
	var bands: PackedColorArray = []
	for i in range(spell.strokes.size() - 1, -1, -1):
		bands.append(GameCursor.ink_of(spell.strokes[i].rune))
	return bands


## How big the burst of `through` damage is.
static func burst_size(through: float) -> float:
	return clampf(BURST_MIN_SIZE + through * BURST_PER_DAMAGE, BURST_MIN_SIZE, BURST_MAX_SIZE)


## How tall the figures of `amount` are written.
static func number_height(amount: float) -> float:
	return lerpf(NUMBER_MIN_HEIGHT, NUMBER_MAX_HEIGHT, clampf(amount / NUMBER_FULL_AT, 0.0, 1.0))


func count_of(kind: SpellMark.Kind) -> int:
	return marks_of(kind).size()


func marks_of(kind: SpellMark.Kind) -> Array[SpellMark]:
	var found: Array[SpellMark] = []
	for mark in marks:
		if mark.kind == kind:
			found.append(mark)
	return found


## Forgets the marks that are over by `now_usec`.
func age(now_usec: int = Time.get_ticks_usec()) -> void:
	var kept: Array[SpellMark] = []
	for mark in marks:
		if not mark.is_over(now_usec):
			kept.append(mark)
	marks = kept


## Looks at how the duelists are, for what is kept up round them.
func observe() -> void:
	for stand: Stand in _stands.values():
		var duelist := stand.duelist
		var ward_left := duelist.ward_seconds_left if duelist.is_warded() else 0.0
		# More time left than there was means the ward has been raised
		# again, and that is what it now has to run down from.
		if ward_left > stand.ward_seconds_left + 0.01 or ward_left > stand.ward_span:
			stand.ward_span = ward_left
		if ward_left <= 0.0:
			stand.ward_span = 0.0
		stand.ward_seconds_left = ward_left

		var chill_left := duelist.chill_seconds_left if duelist.is_chilled() else 0.0
		if chill_left > stand.chill_seconds_left + 0.01 or chill_left > stand.chill_span:
			stand.chill_span = chill_left
		if chill_left <= 0.0:
			stand.chill_span = 0.0
		stand.chill_seconds_left = chill_left


## How much of `duelist`'s ward has yet to run down, from 1 to 0. It is 0
## when they have none.
func ward_left(duelist: Duelist) -> float:
	var stand := stand_of(duelist)
	if stand == null or stand.ward_span <= 0.0:
		return 0.0
	return clampf(stand.ward_seconds_left / stand.ward_span, 0.0, 1.0)


## How much of `duelist`'s chill has yet to wear off, from 1 to 0.
func chill_left(duelist: Duelist) -> float:
	var stand := stand_of(duelist)
	if stand == null or stand.chill_span <= 0.0:
		return 0.0
	return clampf(stand.chill_seconds_left / stand.chill_span, 0.0, 1.0)


## How thick a ward that soaks up `ward` is drawn.
static func ward_width(ward: float) -> float:
	return lerpf(WARD_MIN_WIDTH, WARD_MAX_WIDTH, clampf(ward / WARD_FULL_AT, 0.0, 1.0))


## True while there is anything to draw.
func is_showing() -> bool:
	if not marks.is_empty():
		return true
	for stand: Stand in _stands.values():
		if stand.duelist.is_warded() or stand.duelist.is_chilled():
			return true
	return false


func _process(_delta: float) -> void:
	var was_showing := is_showing()
	# Before the marks that are over are forgotten: one that was born and
	# was over between two frames is still heard.
	announce()
	age()
	observe()
	if was_showing or is_showing():
		queue_redraw()


func _add(kind: SpellMark.Kind, at: Vector2, born_usec: int, seconds: float) -> SpellMark:
	var mark := SpellMark.new(kind, at, born_usec, seconds)
	_scattered += 1
	mark.scatter = _scattered
	marks.append(mark)
	return mark


## True if `outcome` did anything that was aimed at `whom`.
func _reaches(outcome: SpellOutcome, whom: Duelist) -> bool:
	for entry in outcome.entries:
		if entry.get("on") == whom:
			return true
	return false


## Where the streak of `outcome` ends: at the middle of the target's
## circle, or at their ward if nothing got past it.
func _landing(outcome: SpellOutcome, caster: Stand, target: Stand) -> Vector2:
	var stopped := false
	for entry in outcome.entries:
		if entry.get("on") != outcome.target:
			continue
		match entry["kind"]:
			SpellEffect.Kind.DAMAGE:
				if float(entry.get("through", 0.0)) > 0.0:
					return target.centre
				stopped = stopped or float(entry.get("absorbed", 0.0)) > 0.0
			SpellEffect.Kind.BATTER:
				stopped = stopped or entry.get("landed", false)
			SpellEffect.Kind.INTERRUPT:
				if entry.get("broke") != null:
					return target.centre
				stopped = stopped or outcome.target.is_warded()
			_:
				return target.centre
	if stopped:
		return target.rim_towards(caster.centre, WARD_GAP * target.scale)
	return target.centre


func _flare(on: Stand, other: Stand, born_usec: int, colour: Color, amount: float) -> void:
	var flare := _add(SpellMark.Kind.FLARE, on.centre, born_usec, FLARE_SECONDS)
	flare.colour = colour
	flare.strength = blow_strength(amount)
	flare.radius = on.radius + WARD_GAP * on.scale
	flare.facing = on.centre.direction_to(other.centre)
	flare.size = WARD_MAX_WIDTH * 2.2 * on.drawn_scale()


## What `ward_of`'s ward turned back, on its way to `onto`. It goes back
## the way the spell came, from `from` to `to`.
func _turn_back(ward_of: Stand, onto: Stand, from: Vector2, to: Vector2, amount: float, born_usec: int, written: Dictionary[Duelist, int]) -> void:
	var colour := KIND_COLOURS[SpellEffect.Kind.REFLECT]
	var streak := _add(SpellMark.Kind.STREAK, to, born_usec, TRAVEL_SECONDS + STREAK_FADE_SECONDS)
	streak.from = from
	streak.bands = PackedColorArray([colour])
	streak.colour = colour
	streak.size = STREAK_MIN_WIDTH * onto.drawn_scale()
	var lands_usec := born_usec + int(TRAVEL_SECONDS * 1_000_000)
	var burst := _add(SpellMark.Kind.BURST, to, lands_usec, BURST_SECONDS)
	burst.colour = colour
	burst.size = burst_size(amount) * onto.drawn_scale()
	burst.strength = blow_strength(amount)
	burst.is_echo = true
	_number(onto, ward_of, written, "%d turned back" % [maxi(roundi(amount), 1)], colour, amount, lands_usec)


## Writes `text` beside `on`, on the side that faces `other` and under
## whatever has been written there already.
func _number(on: Stand, other: Stand, written: Dictionary[Duelist, int], text: String, colour: Color, amount: float, born_usec: int) -> void:
	var line: int = written.get(on.duelist, 0)
	written[on.duelist] = line + 1
	var beside: Vector2 = _beside.get(on.duelist, on.rim_towards(other.centre, WRITING_GAP * on.written_scale()))
	var drop := (NUMBER_DROP + line * NUMBER_SPACING) * on.written_scale()
	var number := _add(SpellMark.Kind.NUMBER, beside + Vector2(0.0, drop), born_usec, NUMBER_SECONDS)
	number.text = text
	number.colour = colour
	number.size = number_height(amount) * on.written_scale()


# Drawing

func _draw() -> void:
	var now := Time.get_ticks_usec()
	for stand: Stand in _stands.values():
		_draw_what_lasts(stand, now)
	for mark in marks:
		if not mark.is_born(now) or mark.is_over(now):
			continue
		match mark.kind:
			SpellMark.Kind.STREAK:
				_draw_streak(mark, now)
			SpellMark.Kind.BURST:
				_draw_burst(mark, now)
			SpellMark.Kind.FLARE:
				_draw_flare(mark, now)
			SpellMark.Kind.RAISE:
				_draw_raise(mark, now)
			SpellMark.Kind.SHATTER:
				_draw_shatter(mark, now)
			SpellMark.Kind.MOTES:
				_draw_motes(mark, now)
			SpellMark.Kind.FROST:
				_draw_frost(mark, now)
			SpellMark.Kind.CRACK:
				_draw_crack(mark, now)
			SpellMark.Kind.SPUTTER:
				_draw_sputter(mark, now)
	# What is written goes over what is drawn.
	for mark in marks:
		if mark.is_born(now) and not mark.is_over(now) \
				and (mark.kind == SpellMark.Kind.NUMBER or mark.kind == SpellMark.Kind.GRADE):
			_draw_writing(mark, now)


## Quick at first and then slowing.
static func _slowing(progress: float) -> float:
	return 1.0 - (1.0 - progress) * (1.0 - progress)


static func _faded(colour: Color, alpha: float) -> Color:
	return Color(colour.r, colour.g, colour.b, colour.a * clampf(alpha, 0.0, 1.0))


static func _scatterer(mark: SpellMark) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = mark.scatter * 7919 + 17
	return rng


## The ward round a duelist, and the frost on one who is chilled.
func _draw_what_lasts(stand: Stand, now_usec: int) -> void:
	var duelist := stand.duelist
	var seconds := now_usec / 1_000_000.0
	if duelist.is_warded():
		var left := ward_left(duelist)
		var radius := stand.radius + WARD_GAP * stand.scale
		var width := ward_width(duelist.ward) * stand.drawn_scale()
		var colour := KIND_COLOURS[SpellEffect.Kind.WARD]
		# The whole ring, faintly, and over it what is left of the ward's
		# time, which runs down clockwise from the top.
		draw_arc(stand.centre, radius, 0.0, TAU, 96, _faded(colour, 0.16), width, true)
		var breath := 0.78 + 0.12 * sin(seconds * 3.0)
		if left > 0.0:
			draw_arc(stand.centre, radius, -PI / 2.0, -PI / 2.0 + TAU * left, 96, _faded(colour, breath), width, true)
		if duelist.ward_reflect > 0.0:
			var edge := KIND_COLOURS[SpellEffect.Kind.REFLECT]
			draw_arc(stand.centre, radius + width / 2.0 + 3.0 * stand.drawn_scale(), 0.0, TAU, 96, _faded(edge, breath), 1.6, true)
	if duelist.is_chilled():
		var left := chill_left(duelist)
		var colour := KIND_COLOURS[SpellEffect.Kind.CHILL]
		var radius := stand.radius - 5.0 * stand.scale
		var depth := lerpf(5.0, 16.0, clampf(duelist.chill * 2.0, 0.0, 1.0)) * stand.drawn_scale()
		var alpha := lerpf(0.25, 0.8, left)
		draw_arc(stand.centre, radius, 0.0, TAU, 96, _faded(colour, alpha * 0.5), 1.5, true)
		# Icicles, pointing in from the rim.
		for tooth in FROST_TEETH:
			var angle := TAU * tooth / FROST_TEETH
			var length := depth * (1.0 if tooth % 3 == 0 else 0.55)
			var out := Vector2.from_angle(angle)
			draw_line(stand.centre + out * radius, stand.centre + out * (radius - length), _faded(colour, alpha), 1.6, true)


func _draw_streak(mark: SpellMark, now_usec: int) -> void:
	var age_ := mark.age(now_usec)
	var head := clampf(age_ / TRAVEL_SECONDS, 0.0, 1.0)
	var fading := clampf((age_ - TRAVEL_SECONDS) / STREAK_FADE_SECONDS, 0.0, 1.0)
	# Once the head is there the tail comes after it, slowly and then not.
	var tail := fading * fading
	if head <= tail:
		return
	var alpha := 1.0 - 0.5 * fading
	var from := mark.from.lerp(mark.at, tail)
	var to := mark.from.lerp(mark.at, head)
	draw_line(from, to, _faded(mark.colour, 0.16 * alpha), mark.size * 3.0, true)
	var count := maxi(mark.bands.size(), 1)
	for i in count:
		var low := maxf(float(i) / count, tail)
		var high := minf(float(i + 1) / count, head)
		if high <= low:
			continue
		var colour := mark.bands[i] if i < mark.bands.size() else mark.colour
		draw_line(mark.from.lerp(mark.at, low), mark.from.lerp(mark.at, high), _faded(colour, alpha), mark.size, true)
	draw_line(from, to, _faded(Color.WHITE, 0.6 * alpha), maxf(mark.size * 0.28, 1.0), true)
	if fading < 0.35:
		var glare := 1.0 - fading / 0.35
		draw_circle(to, mark.size * (1.3 if mark.is_flawless else 0.95), _faded(Color.WHITE, glare), true, -1.0, true)


func _draw_burst(mark: SpellMark, now_usec: int) -> void:
	var progress := mark.progress(now_usec)
	var opened := _slowing(progress)
	var fade := (1.0 - progress) * (1.0 - progress)
	if progress < 0.4:
		var flash := 1.0 - progress / 0.4
		draw_circle(mark.at, mark.size * 0.5 * (0.6 + 0.4 * opened), _faded(Color.WHITE, 0.55 * flash), true, -1.0, true)
		draw_circle(mark.at, mark.size * 0.75 * (0.6 + 0.4 * opened), _faded(mark.colour, 0.3 * flash), true, -1.0, true)
	draw_arc(mark.at, mark.size * lerpf(0.3, 1.0, opened), 0.0, TAU, 64, _faded(mark.colour, fade), lerpf(mark.size * 0.2, 1.5, progress), true)
	if mark.is_flawless:
		draw_arc(mark.at, mark.size * lerpf(0.3, 1.35, opened), 0.0, TAU, 64, _faded(GRADE_COLOURS[CastResult.Grade.S], fade * 0.9), 2.0, true)
	var rng := _scatterer(mark)
	var sparks := clampi(int(mark.size / 6.0), 5, 18)
	for spark in sparks:
		var angle := TAU * (spark + rng.randf()) / sparks
		var reach := mark.size * rng.randf_range(0.85, 1.5)
		var out := Vector2.from_angle(angle)
		var near := reach * lerpf(0.25, 1.0, opened)
		var far := near + mark.size * 0.3 * (1.0 - progress)
		draw_line(mark.at + out * near, mark.at + out * far, _faded(mark.colour.lerp(Color.WHITE, 0.4), fade), 2.0, true)


func _draw_flare(mark: SpellMark, now_usec: int) -> void:
	var progress := mark.progress(now_usec)
	var facing := mark.facing.angle()
	var half := lerpf(PI * 0.2, PI * 0.5, _slowing(progress))
	var width := lerpf(mark.size, 2.0, progress)
	draw_arc(mark.at, mark.radius, facing - half, facing + half, 48, _faded(mark.colour, 1.0 - progress), width, true)
	draw_arc(mark.at, mark.radius, facing - half * 0.5, facing + half * 0.5, 32, _faded(Color.WHITE, 0.7 * (1.0 - progress)), maxf(width * 0.35, 1.0), true)


func _draw_raise(mark: SpellMark, now_usec: int) -> void:
	var progress := mark.progress(now_usec)
	var settled := _slowing(progress)
	draw_arc(mark.at, mark.radius * lerpf(1.3, 1.0, settled), 0.0, TAU, 96, _faded(mark.colour, 0.9 * (1.0 - progress)), lerpf(mark.size, 2.0, progress), true)
	draw_arc(mark.at, mark.radius * lerpf(0.6, 1.0, settled), 0.0, TAU, 96, _faded(mark.colour, 0.45 * (1.0 - progress)), 2.0, true)


func _draw_shatter(mark: SpellMark, now_usec: int) -> void:
	var progress := mark.progress(now_usec)
	var rng := _scatterer(mark)
	var pieces := 14
	for piece in pieces:
		var angle := TAU * piece / pieces + rng.randf_range(-0.08, 0.08)
		var span := TAU / pieces * rng.randf_range(0.45, 0.8)
		var flown := mark.size * rng.randf_range(0.4, 1.0) * _slowing(progress)
		# Each piece keeps the curve it had and is carried straight out.
		var carried := mark.at + Vector2.from_angle(angle + span / 2.0) * flown
		var turned := rng.randf_range(-0.5, 0.5) * progress
		draw_arc(carried, mark.radius, angle + turned, angle + span + turned, 8, _faded(mark.colour, 1.0 - progress), 3.0, true)


func _draw_motes(mark: SpellMark, now_usec: int) -> void:
	var progress := mark.progress(now_usec)
	var rng := _scatterer(mark)
	var count := clampi(int(mark.size * 0.8), 6, 18)
	for mote in count:
		var across := rng.randf_range(-0.7, 0.7) * mark.radius
		var starts := rng.randf_range(-0.1, 0.5) * mark.radius
		var rises := rng.randf_range(0.35, 0.9) * mark.radius
		var late := rng.randf_range(0.0, 0.3)
		var own := clampf((progress - late) / (1.0 - late), 0.0, 1.0)
		if own <= 0.0:
			continue
		var where := mark.at + Vector2(across, starts - rises * _slowing(own))
		draw_circle(where, rng.randf_range(2.0, 4.5), _faded(mark.colour, sin(PI * own)), true, -1.0, true)


func _draw_frost(mark: SpellMark, now_usec: int) -> void:
	var progress := mark.progress(now_usec)
	var grown := _slowing(progress)
	var fade := 0.8 * (1.0 - progress * progress)
	for arm in 6:
		var out := Vector2.from_angle(TAU * arm / 6.0 + PI / 6.0)
		var tip := mark.at + out * mark.size * grown
		draw_line(mark.at, tip, _faded(mark.colour, fade), 2.5, true)
		for barb_at in [0.45, 0.7]:
			var root: Vector2 = mark.at + out * mark.size * grown * barb_at
			var length: float = mark.size * 0.2 * grown * (1.0 - barb_at + 0.4)
			draw_line(root, root + out.rotated(PI / 3.0) * length, _faded(mark.colour, fade), 1.8, true)
			draw_line(root, root + out.rotated(-PI / 3.0) * length, _faded(mark.colour, fade), 1.8, true)
	draw_arc(mark.at, mark.radius * lerpf(0.5, 1.0, grown), 0.0, TAU, 72, _faded(mark.colour, 0.6 * fade), 2.0, true)


func _draw_crack(mark: SpellMark, now_usec: int) -> void:
	var progress := mark.progress(now_usec)
	var rng := _scatterer(mark)
	# It is there at once and then goes. A break is sudden.
	var fade := 1.0 - progress * progress
	for crack in 3:
		var angle := TAU * crack / 3.0 + rng.randf_range(-0.4, 0.4)
		var out := Vector2.from_angle(angle)
		var side := out.orthogonal()
		var points := PackedVector2Array()
		var joints := 7
		for joint in joints + 1:
			var along := lerpf(-1.0, 1.0, float(joint) / joints)
			var off := 0.0 if joint == 0 or joint == joints else rng.randf_range(-0.14, 0.14)
			points.append(mark.at + (out * along + side * off) * mark.radius)
		draw_polyline(points, _faded(mark.colour, fade), mark.size, true)
		draw_polyline(points, _faded(Color.WHITE, 0.6 * fade), maxf(mark.size * 0.35, 1.0), true)
	draw_arc(mark.at, mark.radius, 0.0, TAU, 72, _faded(mark.colour, 0.7 * fade), mark.size, true)


func _draw_sputter(mark: SpellMark, now_usec: int) -> void:
	var progress := mark.progress(now_usec)
	var rng := _scatterer(mark)
	draw_arc(mark.at, mark.size * lerpf(0.8, 0.35, progress), 0.0, TAU, 32, _faded(mark.colour, 0.7 * (1.0 - progress)), 2.0, true)
	for ember in 6:
		var out := Vector2.from_angle(rng.randf_range(0.0, TAU)) * mark.size * rng.randf_range(0.3, 0.9)
		# They go out a little way and then fall.
		var where := mark.at + out * _slowing(progress) + Vector2(0.0, mark.size * 1.2 * progress * progress)
		draw_circle(where, rng.randf_range(1.5, 3.0), _faded(mark.colour, 1.0 - progress), true, -1.0, true)


func _draw_writing(mark: SpellMark, now_usec: int) -> void:
	var progress := mark.progress(now_usec)
	var font := ThemeDB.fallback_font
	var height := mark.size
	if mark.kind == SpellMark.Kind.GRADE:
		# It lands large and settles.
		height *= lerpf(1.5, 1.0, _slowing(clampf(progress / 0.25, 0.0, 1.0)))
	var size := maxi(roundi(height), 1)
	var alpha := 1.0 - clampf((progress - 0.55) / 0.45, 0.0, 1.0)
	var rise := NUMBER_RISE * _slowing(progress) if mark.kind == SpellMark.Kind.NUMBER else 0.0
	var width := font.get_string_size(mark.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var where := mark.at + Vector2(-width / 2.0, height * 0.35 - rise)
	draw_string_outline(font, where, mark.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, maxi(size / 5, 3), _faded(OUTLINE_COLOUR, alpha))
	draw_string(font, where, mark.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, _faded(mark.colour, alpha))
