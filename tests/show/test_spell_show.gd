extends TestCase
## SpellShow: what a spell looks like when it lands.

const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const NOW := 5_000_000
const BEAT := 250_000

var show_: SpellShow
var me: Duelist
var foe: Duelist
var my_circle: SpellCircle
var foe_circle: SpellCircle


func before_each() -> void:
	forget_progress()
	me = Duelist.new("You")
	foe = Duelist.new("Femble")
	my_circle = SpellCircle.new()
	my_circle.accepts_input = false
	my_circle.position = Vector2(390, 336)
	add_managed(my_circle)
	foe_circle = SpellCircle.new()
	foe_circle.accepts_input = false
	foe_circle.position = Vector2(936, 264)
	foe_circle.scale = Vector2(0.5, 0.5)
	add_managed(foe_circle)
	show_ = SpellShow.new()
	show_.set_process(false)
	add_managed(show_)
	show_.place(me, my_circle)
	show_.place(foe, foe_circle)


func after_each() -> void:
	forget_progress()


func _spell(id: StringName) -> Spell:
	return SpellLibrary.find(id)


## A verdict on a cast of the given quality.
func _verdict(quality: float) -> CastResult:
	var tuning := CastScorer.default_tuning()
	var result := CastResult.new()
	result.quality = quality
	result.grade = tuning.grade(quality)
	result.potency = tuning.potency(quality) if result.grade != CastResult.Grade.FIZZLE else 0.0
	return result


## Resolves a cast of `id` by `caster` and shows it.
func _cast(id: StringName, caster: Duelist, quality: float = 1.0) -> SpellOutcome:
	var target := foe if caster == me else me
	var outcome := SpellResolver.resolve(_spell(id), _verdict(quality), caster, target)
	show_.show_outcome(outcome, NOW)
	return outcome


func _only(kind: SpellMark.Kind) -> SpellMark:
	var found := show_.marks_of(kind)
	assert_eq(found.size(), 1, "one %s" % [SpellMark.Kind.find_key(kind)])
	return found[0] if not found.is_empty() else SpellMark.new(kind, Vector2.ZERO, 0, 1.0)


# Where the duelists stand

func test_a_duelist_stands_where_their_circle_is() -> void:
	var mine := show_.stand_of(me)
	assert_eq(mine.centre, Vector2(390, 336))
	assert_almost_eq(mine.radius, Spell.CIRCLE_RADIUS + Rune.RADIUS)
	assert_almost_eq(mine.scale, 1.0)
	var theirs := show_.stand_of(foe)
	assert_eq(theirs.centre, Vector2(936, 264))
	assert_almost_eq(theirs.radius, (Spell.CIRCLE_RADIUS + Rune.RADIUS) / 2.0, 1e-4, "their circle is drawn at half the size")
	assert_null(show_.stand_of(Duelist.new("Nobody")))


func test_a_point_on_a_circle_is_found_on_the_screen() -> void:
	assert_eq(show_.stand_of(me).on_screen(Vector2(100, -50)), Vector2(490, 286))
	assert_eq(show_.stand_of(foe).on_screen(Vector2(100, -50)), Vector2(986, 239))


func test_a_line_out_of_a_circle_crosses_its_rim() -> void:
	var mine := show_.stand_of(me)
	var crossing := mine.crossing(mine.centre + Vector2(50, 0), mine.centre + Vector2(900, 0))
	assert_almost_eq(crossing.x, mine.centre.x + mine.radius, 0.01)
	assert_almost_eq(crossing.y, mine.centre.y, 0.01)
	var further := mine.crossing(mine.centre + Vector2(0, 100), mine.centre + Vector2(900, 100), 20.0)
	assert_almost_eq(further.distance_to(mine.centre), mine.radius + 20.0, 0.01)
	assert_almost_eq(further.y, mine.centre.y + 100.0, 0.01)


func test_what_is_shown_for_the_smaller_circle_is_smaller_and_can_still_be_read() -> void:
	var theirs := show_.stand_of(foe)
	assert_lt(theirs.drawn_scale(), 1.0)
	assert_gt(theirs.drawn_scale(), theirs.scale)
	assert_gt(theirs.written_scale(), theirs.drawn_scale(), "what is written shrinks least")
	assert_almost_eq(show_.stand_of(me).drawn_scale(), 1.0)


# A spell that harms

func test_a_bolt_crosses_from_the_last_rune_to_the_foe() -> void:
	var fire_bolt := _spell(&"fire_bolt")
	_cast(&"fire_bolt", me)
	var streak := _only(SpellMark.Kind.STREAK)
	var last_rune := show_.stand_of(me).on_screen(fire_bolt.strokes[-1].position)
	assert_almost_eq(streak.from.distance_to(last_rune), Rune.RADIUS, 0.01, "it sets out from the rim of the last rune struck")
	assert_eq(streak.at, Vector2(936, 264))
	assert_eq(streak.born_usec, NOW)
	assert_almost_eq(streak.seconds, SpellShow.TRAVEL_SECONDS + SpellShow.STREAK_FADE_SECONDS)


func test_the_streak_is_banded_in_the_colours_of_the_runes() -> void:
	var fire_bolt := _spell(&"fire_bolt")
	_cast(&"fire_bolt", me)
	var streak := _only(SpellMark.Kind.STREAK)
	assert_eq(streak.bands.size(), fire_bolt.strokes.size())
	# The first rune struck is at the head, and arrives first.
	assert_eq(streak.bands[-1], GameCursor.ink_of(fire_bolt.strokes[0].rune))
	assert_eq(streak.bands[0], GameCursor.ink_of(fire_bolt.strokes[-1].rune))
	assert_eq(SpellShow.bands_of(fire_bolt), streak.bands)


func test_what_happens_to_the_foe_waits_for_the_bolt_to_get_there() -> void:
	_cast(&"fire_bolt", me)
	var burst := _only(SpellMark.Kind.BURST)
	assert_eq(burst.at, Vector2(936, 264))
	assert_eq(burst.born_usec, NOW + int(SpellShow.TRAVEL_SECONDS * 1_000_000))
	assert_false(burst.is_born(NOW + 100_000))
	assert_true(burst.is_born(NOW + 150_000))


func test_the_bolt_is_not_long_after_the_blow() -> void:
	# The rules apply a spell as its last stroke lands. The show has to
	# be close behind, or the health bar is seen to fall first.
	assert_lt(SpellShow.TRAVEL_SECONDS, 0.2)


func test_a_better_cast_is_a_wider_streak() -> void:
	_cast(&"fire_bolt", me, 1.0)
	var best := _only(SpellMark.Kind.STREAK).size
	show_.marks.clear()
	_cast(&"fire_bolt", me, 0.75)
	var middling := _only(SpellMark.Kind.STREAK).size
	show_.marks.clear()
	_cast(&"fire_bolt", me, 0.52)
	var poor := _only(SpellMark.Kind.STREAK).size
	assert_gt(best, middling)
	assert_gt(middling, poor)
	assert_gt(poor, 0.0)


func test_more_damage_is_a_bigger_burst_and_a_bigger_number() -> void:
	_cast(&"spark", me)
	var small := _only(SpellMark.Kind.BURST).size
	var small_number := _only(SpellMark.Kind.NUMBER)
	assert_eq(small_number.text, "5")
	show_.marks.clear()
	_cast(&"lightning", me)
	var large := _only(SpellMark.Kind.BURST).size
	var large_number := _only(SpellMark.Kind.NUMBER)
	assert_eq(large_number.text, "32")
	assert_gt(large, small)
	assert_gt(large_number.size, small_number.size)
	assert_gt(SpellShow.burst_size(1000.0), SpellShow.burst_size(32.0) - 0.01, "and there is a largest")
	assert_almost_eq(SpellShow.burst_size(1000.0), SpellShow.BURST_MAX_SIZE)


func test_the_same_spell_cast_worse_is_a_smaller_burst() -> void:
	_cast(&"lightning", me, 1.0)
	var best := _only(SpellMark.Kind.BURST).size
	show_.marks.clear()
	_cast(&"lightning", me, 0.55)
	assert_lt(_only(SpellMark.Kind.BURST).size, best)


func test_a_flawless_cast_is_marked_as_one() -> void:
	_cast(&"fire_bolt", me, 1.0)
	assert_true(_only(SpellMark.Kind.STREAK).is_flawless)
	assert_true(_only(SpellMark.Kind.BURST).is_flawless)
	show_.marks.clear()
	_cast(&"fire_bolt", me, 0.9)
	assert_false(_only(SpellMark.Kind.STREAK).is_flawless)
	assert_false(_only(SpellMark.Kind.BURST).is_flawless)


func test_the_foes_bolt_comes_the_other_way() -> void:
	var fire_bolt := _spell(&"fire_bolt")
	_cast(&"fire_bolt", foe)
	var streak := _only(SpellMark.Kind.STREAK)
	var last_rune := show_.stand_of(foe).on_screen(fire_bolt.strokes[-1].position)
	assert_almost_eq(streak.from.distance_to(last_rune), Rune.RADIUS * 0.5, 0.01)
	assert_eq(streak.at, Vector2(390, 336))
	assert_eq(_only(SpellMark.Kind.BURST).at, Vector2(390, 336))


# The grade

func test_the_grade_is_written_beside_the_caster() -> void:
	_cast(&"fire_bolt", me, 1.0)
	var grade := _only(SpellMark.Kind.GRADE)
	assert_eq(grade.text, "S")
	assert_eq(grade.colour, SpellShow.GRADE_COLOURS[CastResult.Grade.S])
	assert_eq(grade.born_usec, NOW, "at once: it is the caster's own news")
	var mine := show_.stand_of(me)
	assert_gt(grade.at.distance_to(mine.centre), mine.radius, "outside the circle, clear of the runes")
	assert_gt(grade.at.x, mine.centre.x, "on the side the foe is on")


func test_each_grade_has_its_letter_and_colour() -> void:
	var seen := {}
	for quality in [1.0, 0.9, 0.75, 0.6]:
		show_.marks.clear()
		_cast(&"fire_bolt", me, quality)
		var grade := _only(SpellMark.Kind.GRADE)
		assert_false(seen.has(grade.text))
		seen[grade.text] = true
	assert_eq(seen.keys(), ["S", "A", "B", "C"])
	for grade in CastResult.Grade.values():
		assert_true(SpellShow.GRADE_COLOURS.has(grade))


func test_the_grade_and_the_numbers_do_not_run_into_each_other() -> void:
	me.health = 40.0
	_cast(&"mend", me)
	var grade := _only(SpellMark.Kind.GRADE)
	var number := _only(SpellMark.Kind.NUMBER)
	assert_gt(number.at.y - number.size / 2.0, grade.at.y + grade.size / 2.0)


func test_the_foes_grade_is_on_their_side() -> void:
	_cast(&"fire_bolt", foe, 0.9)
	var grade := _only(SpellMark.Kind.GRADE)
	var theirs := show_.stand_of(foe)
	assert_eq(grade.text, "A")
	assert_gt(grade.at.distance_to(theirs.centre), theirs.radius)
	assert_lt(grade.at.x, theirs.centre.x)
	assert_lt(grade.size, SpellShow.GRADE_HEIGHT, "and is smaller, as their circle is")


# A cast that fizzles

func test_a_fizzle_sputters_and_goes_nowhere() -> void:
	var outcome := _cast(&"fire_bolt", me, 0.1)
	assert_true(outcome.fizzled)
	assert_eq(show_.count_of(SpellMark.Kind.STREAK), 0)
	assert_eq(show_.count_of(SpellMark.Kind.BURST), 0)
	assert_eq(show_.count_of(SpellMark.Kind.NUMBER), 0)
	var sputter := _only(SpellMark.Kind.SPUTTER)
	var last_rune := show_.stand_of(me).on_screen(_spell(&"fire_bolt").strokes[-1].position)
	assert_lt(sputter.at.distance_to(last_rune), Rune.RADIUS + 0.01, "where the brush was")
	var grade := _only(SpellMark.Kind.GRADE)
	assert_eq(grade.text, "Fizzle")
	assert_lt(grade.size, SpellShow.GRADE_HEIGHT, "a word is written smaller than a letter")


# Wards

func test_a_ward_going_up_is_shown_round_the_caster() -> void:
	_cast(&"ward", me)
	assert_eq(show_.count_of(SpellMark.Kind.STREAK), 0, "nothing crosses: it is the caster's own")
	var raise := _only(SpellMark.Kind.RAISE)
	var mine := show_.stand_of(me)
	assert_eq(raise.at, mine.centre)
	assert_gt(raise.radius, mine.radius, "outside the circle")
	assert_eq(raise.colour, SpellShow.KIND_COLOURS[SpellEffect.Kind.WARD])
	assert_eq(raise.born_usec, NOW)


func test_a_ward_that_is_wasted_is_not_shown() -> void:
	me.raise_ward(50.0, 10.0)
	_cast(&"ward", me)
	assert_eq(show_.count_of(SpellMark.Kind.RAISE), 0)
	assert_eq(_only(SpellMark.Kind.GRADE).text, "S", "the cast was still made, and made well")


func test_a_ward_that_turns_blows_back_has_a_second_ring() -> void:
	_cast(&"bulwark", me)
	var raises := show_.marks_of(SpellMark.Kind.RAISE)
	assert_eq(raises.size(), 2)
	assert_eq(raises[0].colour, SpellShow.KIND_COLOURS[SpellEffect.Kind.WARD])
	assert_eq(raises[1].colour, SpellShow.KIND_COLOURS[SpellEffect.Kind.REFLECT])


func test_a_blow_on_a_ward_flares_on_the_side_it_came_from() -> void:
	foe.raise_ward(50.0, 10.0)
	_cast(&"fire_bolt", me)
	var flare := _only(SpellMark.Kind.FLARE)
	var theirs := show_.stand_of(foe)
	assert_eq(flare.at, theirs.centre)
	assert_lt(flare.facing.x, 0.0, "the blow came from the left")
	assert_almost_eq(flare.facing.length(), 1.0, 1e-4)
	assert_eq(show_.count_of(SpellMark.Kind.BURST), 0, "nothing got through")
	assert_eq(_only(SpellMark.Kind.NUMBER).text, "16 warded")


func test_a_bolt_that_is_stopped_stops_at_the_ward() -> void:
	foe.raise_ward(50.0, 10.0)
	_cast(&"fire_bolt", me)
	var streak := _only(SpellMark.Kind.STREAK)
	var theirs := show_.stand_of(foe)
	assert_gt(streak.at.distance_to(theirs.centre), theirs.radius, "outside their circle")
	assert_lt(streak.at.x, theirs.centre.x, "on the side it came from")


func test_a_blow_that_breaks_a_ward_shatters_it_and_lands() -> void:
	foe.raise_ward(10.0, 10.0)
	var outcome := _cast(&"fire_bolt", me)
	assert_true(outcome.entries[0]["broke_ward"])
	var shatter := _only(SpellMark.Kind.SHATTER)
	assert_eq(shatter.at, show_.stand_of(foe).centre)
	assert_eq(shatter.born_usec, NOW + int(SpellShow.TRAVEL_SECONDS * 1_000_000))
	assert_eq(show_.count_of(SpellMark.Kind.FLARE), 1)
	assert_eq(_only(SpellMark.Kind.BURST).at, show_.stand_of(foe).centre)
	assert_eq(_only(SpellMark.Kind.STREAK).at, show_.stand_of(foe).centre, "it went through")
	var numbers := show_.marks_of(SpellMark.Kind.NUMBER)
	assert_eq(numbers.size(), 2)
	assert_eq(numbers[0].text, "10 warded")
	assert_eq(numbers[1].text, "6")
	assert_gt(numbers[1].at.y, numbers[0].at.y, "one under the other")


func test_a_ward_that_holds_does_not_shatter() -> void:
	foe.raise_ward(50.0, 10.0)
	var outcome := _cast(&"fire_bolt", me)
	assert_false(outcome.entries[0]["broke_ward"])
	assert_eq(show_.count_of(SpellMark.Kind.SHATTER), 0)


func test_a_blow_with_no_ward_in_the_way_breaks_none() -> void:
	var outcome := _cast(&"fire_bolt", me)
	assert_false(outcome.entries[0]["broke_ward"])
	assert_eq(show_.count_of(SpellMark.Kind.FLARE), 0)


func test_what_a_ward_turns_back_goes_back_the_way_it_came() -> void:
	foe.raise_ward(50.0, 10.0)
	foe.make_ward_reflect(0.5)
	_cast(&"fire_bolt", me)
	var streaks := show_.marks_of(SpellMark.Kind.STREAK)
	assert_eq(streaks.size(), 2)
	var out := streaks[0]
	var back := streaks[1]
	assert_eq(back.from, out.at, "from where the spell was stopped")
	assert_lt(back.at.distance_to(show_.stand_of(me).centre), show_.stand_of(me).radius, "to the caster")
	assert_eq(back.born_usec, NOW + int(SpellShow.TRAVEL_SECONDS * 1_000_000), "once the spell has got there")
	assert_eq(back.colour, SpellShow.KIND_COLOURS[SpellEffect.Kind.REFLECT])
	var burst := _only(SpellMark.Kind.BURST)
	assert_eq(burst.at, back.at)
	assert_eq(burst.born_usec, NOW + 2 * int(SpellShow.TRAVEL_SECONDS * 1_000_000))
	var numbers := show_.marks_of(SpellMark.Kind.NUMBER)
	assert_eq(numbers.size(), 2)
	assert_eq(numbers[0].text, "16 warded")
	assert_eq(numbers[1].text, "8 turned back")
	assert_lt(numbers[1].at.x, numbers[0].at.x, "the one by the caster, the other by the foe")


func test_a_gust_wears_a_ward_down() -> void:
	foe.raise_ward(50.0, 10.0)
	_cast(&"gust", me)
	var flares := show_.marks_of(SpellMark.Kind.FLARE)
	assert_gt(flares.size(), 0)
	assert_eq(flares[0].colour, SpellShow.KIND_COLOURS[SpellEffect.Kind.BATTER])
	assert_eq(show_.marks_of(SpellMark.Kind.NUMBER)[0].text, "16 off the ward")
	assert_eq(show_.count_of(SpellMark.Kind.SHATTER), 0)


func test_a_gust_that_uses_a_ward_up_shatters_it() -> void:
	foe.raise_ward(10.0, 10.0)
	var outcome := _cast(&"gust", me)
	assert_true(outcome.entries[0]["broke_ward"])
	assert_eq(show_.count_of(SpellMark.Kind.SHATTER), 1)


func test_a_gust_with_no_ward_to_wear_down_shows_only_its_blow() -> void:
	_cast(&"gust", me)
	assert_eq(show_.count_of(SpellMark.Kind.FLARE), 0)
	assert_eq(_only(SpellMark.Kind.NUMBER).text, "3")


# The ward that is kept up

func test_a_ward_runs_down_as_its_time_does() -> void:
	assert_almost_eq(show_.ward_left(me), 0.0)
	me.raise_ward(12.0, 8.0)
	show_.observe()
	assert_almost_eq(show_.ward_left(me), 1.0)
	me.advance(2.0)
	show_.observe()
	assert_almost_eq(show_.ward_left(me), 0.75)
	me.advance(4.0)
	show_.observe()
	assert_almost_eq(show_.ward_left(me), 0.25)
	me.advance(3.0)
	show_.observe()
	assert_almost_eq(show_.ward_left(me), 0.0)
	assert_false(me.is_warded())


func test_a_ward_raised_again_runs_down_from_the_top_again() -> void:
	me.raise_ward(12.0, 8.0)
	show_.observe()
	me.advance(6.0)
	show_.observe()
	assert_almost_eq(show_.ward_left(me), 0.25)
	me.raise_ward(12.0, 4.0)
	show_.observe()
	assert_almost_eq(show_.ward_left(me), 1.0, 1e-6, "four seconds of four, not four of eight")
	me.advance(1.0)
	show_.observe()
	assert_almost_eq(show_.ward_left(me), 0.75)


func test_a_stronger_ward_is_a_thicker_ring() -> void:
	assert_gt(SpellShow.ward_width(26.0), SpellShow.ward_width(12.0))
	assert_gt(SpellShow.ward_width(12.0), SpellShow.ward_width(1.0))
	assert_almost_eq(SpellShow.ward_width(500.0), SpellShow.WARD_MAX_WIDTH)


func test_a_ward_that_was_there_before_the_show_is_kept_up() -> void:
	var late := Duelist.new("Late")
	late.raise_ward(12.0, 8.0)
	late.advance(2.0)
	show_.place(late, foe_circle)
	assert_almost_eq(show_.ward_left(late), 1.0, 1e-6, "from however much time it has left")


# Health, frost, and a broken cast

func test_mending_shows_health_coming_back() -> void:
	me.health = 40.0
	_cast(&"mend", me)
	var motes := _only(SpellMark.Kind.MOTES)
	assert_eq(motes.at, show_.stand_of(me).centre)
	assert_eq(motes.colour, SpellShow.KIND_COLOURS[SpellEffect.Kind.HEAL])
	assert_eq(_only(SpellMark.Kind.NUMBER).text, "+12")
	assert_eq(show_.count_of(SpellMark.Kind.STREAK), 0)


func test_mending_what_is_whole_shows_nothing() -> void:
	_cast(&"mend", me)
	assert_eq(show_.count_of(SpellMark.Kind.MOTES), 0)
	assert_eq(show_.count_of(SpellMark.Kind.NUMBER), 0)


func test_a_chill_shows_frost_on_the_foe() -> void:
	_cast(&"frost_bolt", me)
	var frost := _only(SpellMark.Kind.FROST)
	assert_eq(frost.at, show_.stand_of(foe).centre)
	assert_eq(frost.born_usec, NOW + int(SpellShow.TRAVEL_SECONDS * 1_000_000))
	assert_lt(frost.size, show_.stand_of(foe).radius * 0.5, "and leaves most of their circle to be seen")
	assert_eq(show_.count_of(SpellMark.Kind.BURST), 1, "with the blow that carried it")


func test_a_chill_wears_off_as_its_time_does() -> void:
	assert_almost_eq(show_.chill_left(foe), 0.0)
	foe.apply_chill(0.35, 6.0)
	show_.observe()
	assert_almost_eq(show_.chill_left(foe), 1.0)
	foe.advance(3.0)
	show_.observe()
	assert_almost_eq(show_.chill_left(foe), 0.5)
	foe.advance(4.0)
	show_.observe()
	assert_almost_eq(show_.chill_left(foe), 0.0)


func test_a_broken_cast_cracks_the_circle_it_was_on() -> void:
	foe.casting = _spell(&"lightning")
	_cast(&"flinch", me)
	var crack := _only(SpellMark.Kind.CRACK)
	assert_eq(crack.at, show_.stand_of(foe).centre)
	assert_almost_eq(crack.radius, show_.stand_of(foe).radius)
	assert_eq(_only(SpellMark.Kind.NUMBER).text, "broken")
	assert_eq(_only(SpellMark.Kind.STREAK).at, show_.stand_of(foe).centre)


func test_a_flinch_with_nothing_to_break_crosses_and_does_nothing() -> void:
	_cast(&"flinch", me)
	assert_eq(show_.count_of(SpellMark.Kind.CRACK), 0)
	assert_eq(show_.count_of(SpellMark.Kind.NUMBER), 0)
	assert_eq(show_.count_of(SpellMark.Kind.STREAK), 1)


func test_a_flinch_is_kept_out_by_a_ward() -> void:
	foe.casting = _spell(&"lightning")
	foe.raise_ward(20.0, 10.0)
	_cast(&"flinch", me)
	assert_eq(show_.count_of(SpellMark.Kind.CRACK), 0)
	var theirs := show_.stand_of(foe)
	assert_gt(_only(SpellMark.Kind.STREAK).at.distance_to(theirs.centre), theirs.radius, "it stops at the ward")


# Marks, and time

func test_a_mark_is_born_lasts_and_is_over() -> void:
	var mark := SpellMark.new(SpellMark.Kind.BURST, Vector2.ZERO, NOW + 100_000, 0.5)
	assert_false(mark.is_born(NOW))
	assert_false(mark.is_over(NOW))
	assert_almost_eq(mark.progress(NOW), 0.0)
	assert_true(mark.is_born(NOW + 100_000))
	assert_almost_eq(mark.progress(NOW + 350_000), 0.5)
	assert_almost_eq(mark.age(NOW + 350_000), 0.25)
	assert_false(mark.is_over(NOW + 599_000))
	assert_true(mark.is_over(NOW + 600_000))
	assert_almost_eq(mark.progress(NOW + 900_000), 1.0)


func test_marks_are_forgotten_when_they_are_over() -> void:
	_cast(&"fire_bolt", me)
	assert_eq(show_.marks.size(), 4, "a grade, a streak, a burst and a number")
	show_.age(NOW + 400_000)
	assert_eq(show_.count_of(SpellMark.Kind.STREAK), 1)
	show_.age(NOW + 500_000)
	assert_eq(show_.count_of(SpellMark.Kind.STREAK), 0)
	assert_eq(show_.count_of(SpellMark.Kind.BURST), 1, "which began later")
	show_.age(NOW + 2_000_000)
	assert_eq(show_.marks.size(), 0)


func test_each_mark_scatters_its_own_way() -> void:
	_cast(&"fire_bolt", me)
	_cast(&"fire_bolt", me)
	var bursts := show_.marks_of(SpellMark.Kind.BURST)
	assert_eq(bursts.size(), 2)
	assert_ne(bursts[0].scatter, bursts[1].scatter)


func test_the_show_knows_when_it_has_nothing_to_draw() -> void:
	assert_false(show_.is_showing())
	_cast(&"fire_bolt", me)
	assert_true(show_.is_showing())
	show_.age(NOW + 5_000_000)
	assert_false(show_.is_showing())
	foe.raise_ward(12.0, 8.0)
	assert_true(show_.is_showing(), "a ward is kept up for as long as it lasts")
	foe.advance(9.0)
	assert_false(show_.is_showing())
	foe.apply_chill(0.3, 5.0)
	assert_true(show_.is_showing())


func test_the_show_cleans_up_after_itself() -> void:
	show_.set_process(true)
	show_.show_outcome(SpellResolver.resolve(_spell(&"fire_bolt"), _verdict(1.0), me, foe))
	assert_eq(show_.marks.size(), 4)
	await get_tree().create_timer(SpellShow.NUMBER_SECONDS + SpellShow.TRAVEL_SECONDS + 0.2).timeout
	assert_eq(show_.marks.size(), 0)


func test_every_kind_of_mark_can_be_drawn() -> void:
	# Nothing is looked at here. It is that nothing goes wrong.
	show_.set_process(true)
	foe.raise_ward(30.0, 10.0)
	foe.make_ward_reflect(0.3)
	foe.casting = _spell(&"lightning")
	me.health = 40.0
	for id in [&"fire_bolt", &"gust", &"lightning", &"frost_bolt", &"flinch"]:
		show_.show_outcome(SpellResolver.resolve(_spell(id), _verdict(1.0), me, foe))
	for id in [&"mend", &"bulwark"]:
		show_.show_outcome(SpellResolver.resolve(_spell(id), _verdict(0.9), me, foe))
	show_.show_outcome(SpellResolver.resolve(_spell(&"spark"), _verdict(0.1), foe, me))
	var kinds := {}
	for mark in show_.marks:
		kinds[mark.kind] = true
	assert_eq(kinds.size(), SpellMark.Kind.size(), "every kind there is")
	for frame in 12:
		await get_tree().process_frame
	assert_true(show_.is_showing())


func test_every_kind_of_effect_has_a_colour() -> void:
	var seen := {}
	for kind in SpellEffect.Kind.values():
		assert_true(SpellShow.KIND_COLOURS.has(kind), SpellEffect.KIND_NAMES[kind])
		var colour: Color = SpellShow.KIND_COLOURS[kind]
		assert_false(seen.has(colour.to_html()), "%s has a colour of its own" % [SpellEffect.KIND_NAMES[kind]])
		seen[colour.to_html()] = true


# What it is given that it cannot show

func test_an_outcome_with_nobody_to_show_it_on_is_let_go() -> void:
	var stranger := Duelist.new("Stranger")
	show_.show_outcome(SpellResolver.resolve(_spell(&"fire_bolt"), _verdict(1.0), stranger, foe), NOW)
	show_.show_outcome(SpellResolver.resolve(_spell(&"fire_bolt"), _verdict(1.0), me, stranger), NOW)
	show_.show_outcome(null, NOW)
	show_.show_outcome(SpellOutcome.new(), NOW)
	assert_eq(show_.marks.size(), 0)


# The show changes nothing

func test_a_duel_comes_out_the_same_with_the_show_as_without() -> void:
	var with := _play_out(true)
	var without := _play_out(false)
	assert_eq(with, without)
	assert_gt(with.size(), 0)


## Plays the same casts at two duelists and says how they ended up.
func _play_out(shown: bool) -> Array:
	var one := Duelist.new("One")
	var two := Duelist.new("Two")
	if shown:
		show_.place(one, my_circle)
		show_.place(two, foe_circle)
	var log := []
	var casts := [[&"ward", two], [&"fire_bolt", one], [&"bulwark", two], [&"lightning", one], [&"frost_bolt", two], [&"mend", one], [&"gust", one]]
	for cast in casts:
		var caster: Duelist = cast[1]
		var outcome := SpellResolver.resolve(_spell(cast[0]), _verdict(0.9), caster, two if caster == one else one)
		if shown:
			show_.show_outcome(outcome, NOW)
			show_.observe()
		log.append(outcome.describe())
		log.append([one.health, one.ward, two.health, two.ward, two.chill])
	return log


# In the arena

func test_the_arena_shows_the_players_spell_landing() -> void:
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	var fire_bolt := _spell(&"fire_bolt")
	arena.spell_bar.choose_spell(fire_bolt)
	for stroke in fire_bolt.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, NOW + stroke.tick * BEAT)
	var shown: SpellShow = arena.spell_show
	assert_eq(shown.count_of(SpellMark.Kind.STREAK), 1)
	assert_eq(shown.count_of(SpellMark.Kind.BURST), 1)
	assert_eq(shown.marks_of(SpellMark.Kind.GRADE)[0].text, "S")
	assert_eq(shown.marks_of(SpellMark.Kind.STREAK)[0].at, arena.opponent_circle.global_position)
	assert_eq(shown.stand_of(arena.duel.player).circle, arena.player_circle)
	assert_eq(shown.stand_of(arena.duel.opponent).circle, arena.opponent_circle)


func test_the_arena_shows_the_opponents_spell_landing() -> void:
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	var spark := _spell(&"spark")
	arena.opponent_circle.prepare(spark)
	for stroke in spark.strokes:
		arena.opponent_circle.strike(stroke.rune, stroke.position, NOW + stroke.tick * BEAT)
	var shown: SpellShow = arena.spell_show
	assert_eq(shown.count_of(SpellMark.Kind.STREAK), 1)
	assert_eq(shown.marks_of(SpellMark.Kind.STREAK)[0].at, arena.player_circle.global_position)


func test_the_show_is_under_the_hud_and_over_the_circles() -> void:
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	var shown: SpellShow = arena.spell_show
	assert_gt(shown.get_index(), arena.player_circle.get_index())
	assert_gt(shown.get_index(), arena.opponent_circle.get_index())
	assert_true(arena.hud is CanvasLayer, "which is drawn over everything that is not")
