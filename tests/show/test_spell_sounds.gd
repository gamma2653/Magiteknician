extends TestCase
## SpellSounds and SpellVoice: what a spell sounds like when it lands.
##
## Nobody can listen to a test. What can be checked is what makes a sound
## bad whatever it is a sound of: that it is too loud, that it clicks as
## it starts or stops, that it goes on too long. And that it is the note
## it is meant to be.

const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const NOW := 5_000_000
const TRAVEL_USEC := int(SpellShow.TRAVEL_SECONDS * 1_000_000)

var show_: SpellShow
var me: Duelist
var foe: Duelist


func before_each() -> void:
	forget_progress()
	me = Duelist.new("You")
	foe = Duelist.new("Femble")
	var my_circle := SpellCircle.new()
	my_circle.accepts_input = false
	my_circle.position = Vector2(390, 336)
	add_managed(my_circle)
	var foe_circle := SpellCircle.new()
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


func _verdict(quality: float) -> CastResult:
	var tuning := CastScorer.default_tuning()
	var result := CastResult.new()
	result.quality = quality
	result.grade = tuning.grade(quality)
	result.potency = tuning.potency(quality) if result.grade != CastResult.Grade.FIZZLE else 0.0
	return result


func _cast(id: StringName, caster: Duelist, quality: float = 1.0) -> void:
	var target := foe if caster == me else me
	show_.show_outcome(SpellResolver.resolve(SpellLibrary.find(id), _verdict(quality), caster, target), NOW)


func _heard() -> Array:
	return show_.voice.sounded.map(func (played): return played["sound"])


## The pitch of `made`, in hertz, by the lag at which it best matches
## itself, looking between `lowest` and `highest`.
func _pitch_of(made: PackedFloat32Array, lowest: float, highest: float) -> float:
	var skip := int(0.05 * SpellSounds.RATE)
	var count := 4096
	var shortest := int(SpellSounds.RATE / highest)
	var longest := int(SpellSounds.RATE / lowest)
	var span := count - longest - 2
	var matches := PackedFloat32Array()
	matches.resize(longest + 2)
	for lag in range(shortest - 1, longest + 2):
		var sum := 0.0
		for i in span:
			sum += made[skip + i] * made[skip + i + lag]
		matches[lag] = sum
	var best := shortest
	for lag in range(shortest, longest + 1):
		if matches[lag] > matches[best]:
			best = lag
	# The true lag is between samples. Fit a curve through the best and
	# its neighbours, and take the top of the curve.
	var before := matches[best - 1]
	var after := matches[best + 1]
	var bend := before - 2.0 * matches[best] + after
	var exact := float(best)
	if not is_zero_approx(bend):
		exact += 0.5 * (before - after) / bend
	return float(SpellSounds.RATE) / exact


## How much of `made` is at `hertz`.
func _amount_at(made: PackedFloat32Array, hertz: float) -> float:
	var count := mini(made.size(), 8192)
	var with_sine := 0.0
	var with_cosine := 0.0
	for i in count:
		var turned := TAU * hertz * i / SpellSounds.RATE
		with_sine += made[i] * sin(turned)
		with_cosine += made[i] * cos(turned)
	return sqrt(with_sine * with_sine + with_cosine * with_cosine) / count


# The sounds

func test_there_is_a_sound_for_everything_that_makes_one() -> void:
	assert_eq(SpellSounds.NAMES.size(), 8)
	for sound in SpellSounds.NAMES:
		assert_gt(SpellSounds.samples(sound).size(), 0, sound)
		assert_not_null(SpellSounds.stream(sound), sound)
	assert_eq(SpellSounds.samples(&"trumpet").size(), 0)
	assert_null(SpellSounds.stream(&"trumpet"))


func test_no_sound_is_louder_than_the_runes_chime() -> void:
	for sound in SpellSounds.NAMES:
		var loudest := 0.0
		for value in SpellSounds.samples(sound):
			loudest = maxf(loudest, absf(value))
		assert_lt(loudest, SpellSounds.PEAK + 0.0001, sound)
		assert_gt(loudest, SpellSounds.PEAK * 0.8, "%s is not lost among the others" % [sound])
	assert_lt(SpellSounds.PEAK, 0.25)


func test_no_sound_clicks_as_it_starts_or_stops() -> void:
	for sound in SpellSounds.NAMES:
		var made := SpellSounds.samples(sound)
		assert_almost_eq(made[0], 0.0, 0.001, "%s starts from nothing" % [sound])
		assert_almost_eq(made[-1], 0.0, 0.001, "%s ends at nothing" % [sound])
		assert_lt(absf(made[1]), 0.02, "%s comes in, and does not jump in" % [sound])
		assert_lt(absf(made[-2]), 0.02, sound)


func test_no_sound_leans_to_one_side() -> void:
	# A sound that does pushes the speaker out and holds it there.
	for sound in SpellSounds.NAMES:
		var made := SpellSounds.samples(sound)
		var sum := 0.0
		for value in made:
			sum += value
		assert_almost_eq(sum / made.size(), 0.0, 0.002, sound)


func test_no_sound_outstays_what_it_is_the_sound_of() -> void:
	for sound in SpellSounds.NAMES:
		var seconds := float(SpellSounds.samples(sound).size()) / SpellSounds.RATE
		assert_between(seconds, 0.3, 1.0, sound)


func test_a_sound_has_died_away_by_its_end() -> void:
	for sound in SpellSounds.NAMES:
		var made := SpellSounds.samples(sound)
		var tail := int(0.03 * SpellSounds.RATE)
		var loudest := 0.0
		for i in tail:
			loudest = maxf(loudest, absf(made[made.size() - 1 - i]))
		assert_lt(loudest, SpellSounds.PEAK * 0.12, "%s is not cut off" % [sound])


func test_a_sound_is_the_same_every_time() -> void:
	for sound in SpellSounds.NAMES:
		assert_eq(SpellSounds.samples(sound), SpellSounds.samples(sound), sound)


func test_a_blow_is_a_low_c() -> void:
	var hertz := _pitch_of(SpellSounds.samples(SpellSounds.BLOW), 80.0, 400.0)
	assert_almost_eq(hertz, SpellSounds.C3, 4.0)
	assert_gt(hertz, 100.0, "and not so low that a small speaker cannot sound it")


func test_a_ward_rings_three_octaves_above_a_blow() -> void:
	# It is more than one note, so it is asked how much of it is at each.
	var ward := SpellSounds.samples(SpellSounds.WARD_BLOW)
	var at_c := _amount_at(ward, SpellSounds.C6)
	assert_gt(at_c, 0.005)
	assert_gt(at_c, 4.0 * _amount_at(ward, SpellSounds.B5), "and not the note below")
	assert_gt(at_c, 4.0 * _amount_at(ward, SpellSounds.C6 * SpellSounds.C6 / SpellSounds.B5), "nor the note above")
	assert_almost_eq(SpellSounds.C6 / SpellSounds.C3, 8.0, 0.001, "so the two are in tune")


func test_mending_is_a_chord() -> void:
	var mend := SpellSounds.samples(SpellSounds.MEND)
	var late := mend.slice(int(0.3 * SpellSounds.RATE))
	for hertz in [SpellSounds.C5, SpellSounds.E5, SpellSounds.G5, SpellSounds.C6]:
		assert_gt(_amount_at(late, hertz), 4.0 * _amount_at(late, hertz * 1.04), "%d Hz" % [hertz])


func test_a_broken_cast_is_two_notes_that_do_not_go_together() -> void:
	var broken := SpellSounds.samples(SpellSounds.BREAK)
	assert_gt(_amount_at(broken, SpellSounds.F4), 0.005)
	assert_gt(_amount_at(broken, SpellSounds.B4), 0.005)
	# Three whole tones apart, which is as far from agreeing as two notes get.
	assert_almost_eq(12.0 * log(SpellSounds.B4 / SpellSounds.F4) / log(2.0), 6.0, 0.01)


func test_a_sound_is_made_into_something_that_can_be_played() -> void:
	var made := SpellSounds.samples(SpellSounds.BLOW)
	var wav := SpellSounds.as_stream(made)
	assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(wav.mix_rate, SpellSounds.RATE)
	assert_false(wav.stereo)
	assert_eq(wav.data.size(), made.size() * 2)
	assert_almost_eq(wav.get_length(), float(made.size()) / SpellSounds.RATE, 0.001)
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED)


func test_a_sound_is_worked_out_once() -> void:
	assert_eq(SpellSounds.stream(SpellSounds.MEND), SpellSounds.stream(SpellSounds.MEND))
	SpellSounds.forget()
	assert_not_null(SpellSounds.stream(SpellSounds.MEND))


func test_the_sounds_are_worked_out_until_there_are_recordings() -> void:
	for sound in SpellSounds.NAMES:
		assert_null(SpellSounds.recording(sound), "%s has no recording yet" % [sound])
		assert_true(SpellSounds.stream(sound) is AudioStreamWAV)


# The marks are announced

func test_a_mark_is_announced_when_it_is_born() -> void:
	var born: Array[SpellMark] = []
	show_.mark_born.connect(func (mark): born.append(mark))
	_cast(&"fire_bolt", me)
	assert_eq(born.size(), 0, "nobody has looked yet")
	show_.announce(NOW)
	var kinds := born.map(func (mark): return mark.kind)
	assert_true(SpellMark.Kind.STREAK in kinds)
	assert_true(SpellMark.Kind.GRADE in kinds)
	assert_false(SpellMark.Kind.BURST in kinds, "the spell has not got there")
	show_.announce(NOW + TRAVEL_USEC)
	kinds = born.map(func (mark): return mark.kind)
	assert_true(SpellMark.Kind.BURST in kinds)


func test_a_mark_is_announced_once() -> void:
	var born: Array[SpellMark] = []
	show_.mark_born.connect(func (mark): born.append(mark))
	_cast(&"fire_bolt", me)
	show_.announce(NOW + TRAVEL_USEC)
	var count := born.size()
	assert_eq(count, show_.marks.size())
	show_.announce(NOW + TRAVEL_USEC + 1000)
	show_.announce(NOW + TRAVEL_USEC + 2000)
	assert_eq(born.size(), count)


# What is heard

func test_a_blow_is_heard_when_the_spell_gets_there() -> void:
	_cast(&"fire_bolt", me)
	show_.announce(NOW + TRAVEL_USEC - 1000)
	assert_eq(_heard(), [], "a streak makes no sound, and nor does a letter")
	show_.announce(NOW + TRAVEL_USEC)
	assert_eq(_heard(), [SpellSounds.BLOW])


func test_a_harder_blow_is_louder_and_lower() -> void:
	_cast(&"spark", me)
	_cast(&"cataclysm", me)
	show_.announce(NOW + TRAVEL_USEC)
	var light: Dictionary = show_.voice.sounded[0]
	var heavy: Dictionary = show_.voice.sounded[1]
	assert_gt(heavy["volume_db"], light["volume_db"])
	assert_lt(heavy["pitch"], light["pitch"])
	assert_almost_eq(heavy["volume_db"], 0.0, 0.001, "the hardest blow there is, is as loud as a blow gets")
	assert_almost_eq(heavy["pitch"], SpellVoice.HEAVIEST_PITCH)
	assert_gt(light["volume_db"], SpellVoice.QUIETEST_DB - 0.001)


func test_the_same_spell_cast_worse_lands_more_quietly() -> void:
	_cast(&"lightning", me, 1.0)
	_cast(&"lightning", me, 0.55)
	show_.announce(NOW + TRAVEL_USEC)
	assert_gt(show_.voice.sounded[0]["volume_db"], show_.voice.sounded[1]["volume_db"])


func test_how_hard_a_blow_is_goes_by_the_hardest_there_is() -> void:
	var hardest := 0.0
	for spell in SpellLibrary.all():
		for effect in spell.effects:
			if effect.kind == SpellEffect.Kind.DAMAGE:
				hardest = maxf(hardest, effect.amount)
	assert_almost_eq(SpellShow.HARDEST_BLOW, hardest)
	assert_almost_eq(SpellShow.blow_strength(hardest), 1.0)
	assert_almost_eq(SpellShow.blow_strength(hardest * 3.0), 1.0)
	assert_almost_eq(SpellShow.blow_strength(0.0), 0.0)


func test_a_ward_is_heard_going_up_taking_a_blow_and_breaking() -> void:
	_cast(&"ward", foe)
	show_.announce(NOW)
	assert_eq(_heard(), [SpellSounds.WARD_UP])
	_cast(&"spark", me)
	show_.announce(NOW + TRAVEL_USEC)
	assert_eq(_heard(), [SpellSounds.WARD_UP, SpellSounds.WARD_BLOW])
	_cast(&"lightning", me)
	show_.announce(NOW + TRAVEL_USEC)
	var heard := _heard().slice(2)
	assert_true(SpellSounds.WARD_BLOW in heard)
	assert_true(SpellSounds.WARD_BREAK in heard)
	assert_true(SpellSounds.BLOW in heard, "what was left over got through")


func test_the_second_ring_of_a_ward_is_heard_under_the_first() -> void:
	_cast(&"bulwark", me)
	show_.announce(NOW)
	assert_eq(_heard(), [SpellSounds.WARD_UP, SpellSounds.WARD_UP])
	var first: Dictionary = show_.voice.sounded[0]
	var second: Dictionary = show_.voice.sounded[1]
	assert_lt(second["volume_db"], first["volume_db"])
	assert_gt(second["pitch"], first["pitch"])


func test_what_is_turned_back_lands_after_and_more_quietly() -> void:
	foe.raise_ward(50.0, 10.0)
	foe.make_ward_reflect(0.5)
	_cast(&"fire_bolt", me)
	show_.announce(NOW + TRAVEL_USEC)
	assert_eq(_heard(), [SpellSounds.WARD_BLOW])
	show_.announce(NOW + 2 * TRAVEL_USEC)
	assert_eq(_heard(), [SpellSounds.WARD_BLOW, SpellSounds.BLOW])
	assert_lt(show_.voice.sounded[1]["volume_db"], SpellVoice.ECHO_DB + 0.001)


func test_each_thing_that_happens_has_its_sound() -> void:
	me.health = 40.0
	_cast(&"mend", me)
	show_.announce(NOW)
	assert_eq(_heard(), [SpellSounds.MEND])

	show_.voice.sounded.clear()
	show_.marks.clear()
	_cast(&"frost_bolt", me)
	show_.announce(NOW + TRAVEL_USEC)
	assert_eq(_heard().size(), 2)
	assert_true(SpellSounds.BLOW in _heard())
	assert_true(SpellSounds.CHILL in _heard())

	show_.voice.sounded.clear()
	show_.marks.clear()
	foe.casting = SpellLibrary.find(&"lightning")
	_cast(&"flinch", me)
	show_.announce(NOW + TRAVEL_USEC)
	assert_eq(_heard(), [SpellSounds.BREAK])

	show_.voice.sounded.clear()
	show_.marks.clear()
	_cast(&"fire_bolt", me, 0.1)
	show_.announce(NOW)
	assert_eq(_heard(), [SpellSounds.FIZZLE])


func test_every_sound_is_used_and_every_mark_that_is_heard_has_one() -> void:
	var used := {}
	for kind in SpellVoice.SOUND_OF:
		var sound: StringName = SpellVoice.SOUND_OF[kind]
		assert_true(sound in SpellSounds.NAMES)
		used[sound] = true
	assert_eq(used.size(), SpellSounds.NAMES.size())
	for kind in [SpellMark.Kind.STREAK, SpellMark.Kind.NUMBER, SpellMark.Kind.GRADE]:
		assert_false(SpellVoice.SOUND_OF.has(kind), "what is only looked at is silent")
	assert_eq(SpellVoice.SOUND_OF.size() + 3, SpellMark.Kind.size())


func test_a_voice_can_be_told_to_say_nothing() -> void:
	show_.voice.is_on = false
	_cast(&"fire_bolt", me)
	show_.announce(NOW + TRAVEL_USEC)
	assert_eq(_heard(), [])
	assert_eq(show_.count_of(SpellMark.Kind.BURST), 1, "what is shown is shown as before")


func test_several_sounds_can_be_heard_at_once() -> void:
	var voice: SpellVoice = show_.voice
	assert_eq(voice.get_child_count(), SpellVoice.VOICES)
	for i in SpellVoice.VOICES + 2:
		voice.play(SpellSounds.BLOW)
	assert_eq(voice.sounded.size(), SpellVoice.VOICES + 2)
	var busy := 0
	for player: AudioStreamPlayer in voice.get_children():
		if player.stream != null:
			busy += 1
	assert_eq(busy, SpellVoice.VOICES)


func test_a_sound_there_is_none_of_is_not_played() -> void:
	show_.voice.play(&"trumpet")
	assert_eq(_heard(), [])


# In the arena

func test_the_arena_sounds_what_it_shows() -> void:
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	arena.spell_bar.choose_spell(fire_bolt)
	for stroke in fire_bolt.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, NOW + stroke.tick * 250_000)
	var voice: SpellVoice = arena.spell_show.voice
	assert_not_null(voice)
	assert_eq(voice.sounded.size(), 0, "the spell is on its way")
	await get_tree().create_timer(SpellShow.TRAVEL_SECONDS + 0.12).timeout
	assert_eq(voice.sounded.size(), 1)
	assert_eq(voice.sounded[0]["sound"], SpellSounds.BLOW)
