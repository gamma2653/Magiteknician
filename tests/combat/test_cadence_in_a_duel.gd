extends TestCase
## Cadence, where it counts: in a duel, in an NPC's hands, between two
## machines, and on the screen.

const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const BEAT := 250_000
const START := 5_000_000

var duel: Duel
var player: Duelist
var foe: Duelist
var player_circle: SpellCircle
var foe_circle: SpellCircle
var npc: NpcCaster


func before_each() -> void:
	forget_progress()
	forget_settings()
	player = Duelist.new("You")
	player.spellbook = Spellbook.complete()
	foe = Duelist.new("Femble", 400.0)
	foe.spellbook = Spellbook.complete()
	player_circle = add_managed(SpellCircle.new())
	foe_circle = add_managed(SpellCircle.new())
	npc = add_managed(NpcCaster.new())
	npc.profile = CasterProfile.make(300_000, 0.0, 0.0, 0.0)
	npc.profile.tempo_spread = 0.0
	npc.profile.think_seconds_min = 0.6
	npc.profile.think_seconds_max = 0.9
	npc.rng.seed = 7
	duel = add_managed(Duel.new())
	duel.set_process(false)
	duel.setup(player, foe, player_circle, foe_circle, npc)


func after_each() -> void:
	forget_progress()
	forget_settings()


func _spell(id: StringName) -> Spell:
	return SpellLibrary.find(id)


## The player casts `id` on the beat, beginning at `first_usec`.
func _cast(id: StringName, first_usec: int, beat: int = BEAT) -> CastResult:
	var spell := _spell(id)
	player.chi = player.max_chi
	player_circle.prepare(spell)
	for stroke in spell.strokes:
		player_circle.strike(stroke.rune, stroke.position, first_usec + stroke.tick * beat)
	return player_circle.last_result


func _after(id: StringName, first_usec: int, rest: float, beat: int = BEAT) -> int:
	return first_usec + roundi((_spell(id).strokes[-1].tick + rest) * beat)


func _begin_with_the_npc_stopped() -> void:
	duel.begin()
	npc.halt()
	player_circle.accepts_input = false


# In a duel

func test_a_blow_in_cadence_lands_harder() -> void:
	_begin_with_the_npc_stopped()
	_cast(&"fire_bolt", START)
	var first := foe.max_health - foe.health
	var before := foe.health
	_cast(&"fire_bolt", _after(&"fire_bolt", START, 2.0))
	var second := before - foe.health
	assert_almost_eq(first, 16.0)
	assert_almost_eq(second, 16.0 * 1.05, 0.0001)


func test_a_ward_and_a_mending_in_cadence_are_stronger_too() -> void:
	_begin_with_the_npc_stopped()
	player.health = 40.0
	_cast(&"fire_bolt", START)
	var second := _after(&"fire_bolt", START, 2.0)
	_cast(&"ward", second)
	assert_almost_eq(player.ward, 12.0 * 1.05, 0.0001)
	_cast(&"mend", _after(&"ward", second, 2.0))
	assert_almost_eq(player.health, 40.0 + 12.0 * 1.10, 0.0001)


func test_the_duelist_is_known_to_be_in_cadence() -> void:
	_begin_with_the_npc_stopped()
	_cast(&"fire_bolt", START)
	assert_eq(player.cadence_links, 0)
	assert_eq(player.status_text(), "")
	var second := _after(&"fire_bolt", START, 2.0)
	_cast(&"fire_bolt", second)
	assert_eq(player.cadence_links, 1)
	assert_eq(player.status_text(), "In cadence, 2 in a row")
	_cast(&"fire_bolt", _after(&"fire_bolt", second, 2.4))
	assert_eq(player.cadence_links, 0)
	assert_eq(player.status_text(), "")


func test_a_broken_cast_ends_the_cadence() -> void:
	_begin_with_the_npc_stopped()
	_cast(&"fire_bolt", START)
	var second := _after(&"fire_bolt", START, 2.0)
	_cast(&"fire_bolt", second)
	assert_eq(player.cadence_links, 1)
	# Part-way through the next, the foe breaks it.
	var third := _after(&"fire_bolt", second, 2.0)
	var lightning := _spell(&"lightning")
	player_circle.prepare(lightning)
	player_circle.strike(lightning.strokes[0].rune, lightning.strokes[0].position, third)
	assert_not_null(player.interrupt())
	assert_eq(player.cadence_links, 0)
	assert_false(player_circle.cadence.is_alive())
	_cast(&"fire_bolt", third + 4 * BEAT)
	assert_eq(player_circle.cadence.verdict, Cadence.Verdict.FIRST)


func test_the_combat_log_says_so() -> void:
	_begin_with_the_npc_stopped()
	_cast(&"fire_bolt", START)
	assert_eq(duel.outcomes[-1].describe(), "You cast Fire Bolt (S): 16 damage.")
	_cast(&"fire_bolt", _after(&"fire_bolt", START, 2.0))
	assert_eq(duel.outcomes[-1].describe(), "You cast Fire Bolt (S, 2 in cadence): 17 damage.")


func test_the_cadence_is_carried_to_the_other_machine() -> void:
	_begin_with_the_npc_stopped()
	_cast(&"fire_bolt", START)
	_cast(&"fire_bolt", _after(&"fire_bolt", START, 2.0))
	var arrived: Dictionary = DuelProtocol.through_json(DuelProtocol.resolved(duel.outcomes[-1], true))
	assert_eq(DuelProtocol.problems(arrived), PackedStringArray())
	var rebuilt := SpellOutcome.from_dict(arrived, Duelist.new("You"), Duelist.new("Femble"))
	assert_eq(rebuilt.result.cadence_links, 1)
	assert_almost_eq(rebuilt.result.potency, 1.05)
	assert_eq(rebuilt.describe(), duel.outcomes[-1].describe())

	var there := Duelist.new("You")
	there.apply_dict(DuelProtocol.through_json(player.to_dict()))
	assert_eq(there.cadence_links, 1)
	there.apply_dict({"health": 50.0})
	assert_eq(there.cadence_links, 1, "a snapshot from before there was cadence leaves it alone")


# In an NPC's hands

func _run(seconds: float) -> void:
	for step in roundi(seconds * 60.0):
		duel.advance(1.0 / 60.0)


func _links_of_the_foe() -> Array:
	var links := []
	for outcome in duel.outcomes:
		if outcome.caster == foe:
			links.append(outcome.result.cadence_links)
	return links


func test_an_npc_that_keeps_no_cadence_earns_none() -> void:
	npc.profile.cadence = 0.0
	npc.profile.tempo_spread = 0.3
	duel.begin()
	_run(60.0)
	var links := _links_of_the_foe()
	assert_gt(links.size(), 5)
	assert_gt(links.count(0), links.size() * 0.7, "it may fall on the beat by luck, and not often")


func test_an_npc_that_keeps_a_cadence_earns_one() -> void:
	npc.profile.cadence = 1.0
	duel.begin()
	_run(30.0)
	var links := _links_of_the_foe()
	assert_gt(links.size(), 5)
	assert_eq(links[0], 0, "the first cast has nothing to follow")
	for i in range(1, links.size()):
		assert_eq(links[i], i, "and each after it follows the one before")


func test_an_npc_with_unsteady_hands_loses_the_beat_sometimes() -> void:
	npc.profile.cadence = 1.0
	npc.profile.timing_error = 0.12
	duel.begin()
	_run(60.0)
	var links := _links_of_the_foe()
	assert_gt(links.size(), 5)
	assert_gt(links.count(0), 1, "more than the first")
	assert_lt(links.count(0), links.size(), "and not every time")


func test_an_npc_that_thinks_too_long_cannot_keep_a_cadence() -> void:
	npc.profile.cadence = 1.0
	npc.profile.think_seconds_min = 4.0
	npc.profile.think_seconds_max = 5.0
	duel.begin()
	_run(40.0)
	var links := _links_of_the_foe()
	assert_gt(links.size(), 3)
	assert_eq(links.count(0), links.size(), "thirteen beats go by, and eight is the most")


func test_an_npc_waits_for_the_beat() -> void:
	npc.profile.cadence = 1.0
	duel.begin()
	_run(12.0)
	for outcome in duel.outcomes:
		if outcome.caster == foe and outcome.result.cadence_links > 0:
			assert_almost_eq(outcome.result.usec_per_tick, 300_000.0, 1.0)
	assert_almost_eq(absf(foe_circle.cadence.entry), 0.0, 0.001)
	assert_between(float(foe_circle.cadence.rest), 2.0, 4.0, "its thinking, to the beat after")


func test_a_plan_can_be_drawn_at_a_tempo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var profile := CasterProfile.make(400_000, 0.05)
	var plan := CastPlan.draw(_spell(&"fire_bolt"), profile, rng, 275_000.0)
	assert_almost_eq(plan.usec_per_tick, 275_000.0)
	assert_almost_eq(plan.foreseen_result().usec_per_tick, 275_000.0, 15_000.0)


func test_an_npc_that_keeps_no_cadence_casts_as_it_always_did() -> void:
	# The same numbers are drawn in the same order, so a duel that was
	# seeded comes out as it did before there was cadence.
	var profile := CasterProfile.make(400_000, 0.05)
	var one := RandomNumberGenerator.new()
	var other := RandomNumberGenerator.new()
	one.seed = 11
	other.seed = 11
	var plan := CastPlan.draw(_spell(&"fire_bolt"), profile, one)
	var tempo_factor := maxf(0.4, 1.0 + other.randfn(0.0, profile.tempo_spread))
	assert_almost_eq(plan.usec_per_tick, profile.usec_per_tick * tempo_factor)
	assert_almost_eq(CasterProfile.new().cadence, 0.0)


func test_the_instructors_keep_a_cadence_and_the_students_do_not() -> void:
	var campaign := Session.campaign
	assert_almost_eq(campaign.stage(0).opponent.profile.cadence, 0.0, 1e-6, "the training sphere")
	assert_almost_eq(campaign.stage(1).opponent.profile.cadence, 0.0)
	var last := campaign.stage(campaign.stage_count() - 1).opponent
	assert_gt(last.profile.cadence, 0.5, last.display_name)
	var before := -1.0
	for index in campaign.stage_count():
		var opponent := campaign.stage(index).opponent
		if opponent.profile.think_seconds_min < 2.5:
			assert_gt(opponent.profile.cadence, before - 0.0001, "%s keeps it no worse than those before" % [opponent.display_name])
			before = opponent.profile.cadence


# Between two machines

func test_a_stroke_says_how_long_it_was_after_the_last_cast() -> void:
	var sender := add_managed(StrokeSender.new()) as StrokeSender
	var sent: Array = []
	sender.circle = player_circle
	sender.message.connect(func (contents): sent.append(contents))
	_cast(&"spark", START)
	var second := _after(&"spark", START, 2.0)
	_cast(&"spark", second)
	var strokes := sent.filter(func (contents): return contents[DuelProtocol.TYPE] == DuelProtocol.STROKE)
	assert_eq(strokes.size(), _spell(&"spark").strokes.size() * 2)
	assert_false(strokes[0].has("since"), "the first cast has none before it")
	var count := _spell(&"spark").strokes.size()
	assert_eq(strokes[count]["since"], second - START)
	assert_false(strokes[count + 1].has("since"), "only the first stroke of a cast says it")
	for stroke in strokes:
		assert_eq(DuelProtocol.problems(DuelProtocol.through_json(stroke)), PackedStringArray())


func test_a_stroke_has_to_say_it_properly() -> void:
	var good := DuelProtocol.stroke(Rune.Type.FLOW, Vector2.ZERO, 0, 500_000)
	assert_eq(DuelProtocol.problems(good), PackedStringArray())
	var backwards := good.duplicate()
	backwards["since"] = -5
	assert_gt(DuelProtocol.problems(backwards).size(), 0)
	var wordy := good.duplicate()
	wordy["since"] = "a while"
	assert_gt(DuelProtocol.problems(wordy).size(), 0)


## Sends a cast of `id` to `remote`, made on the beat beginning at
## `first_usec` by the sender's clock and arriving `delay_usec` later.
func _send(remote: RemoteCaster, id: StringName, first_usec: int, since: int, delay_usec: int) -> void:
	var spell := _spell(id)
	remote.receive(DuelProtocol.begin(spell), first_usec + delay_usec)
	for i in spell.strokes.size():
		var stroke := spell.strokes[i]
		var offset := stroke.tick * BEAT
		var message := DuelProtocol.stroke(stroke.rune, stroke.position, offset, since if i == 0 else -1)
		remote.receive(DuelProtocol.through_json(message), first_usec + offset + delay_usec)


func test_the_network_cannot_put_a_cast_off_the_beat() -> void:
	var remote := add_managed(RemoteCaster.new()) as RemoteCaster
	remote.circle = foe_circle
	remote.me = foe
	remote.begin()
	_send(remote, &"fire_bolt", START, -1, 30_000)
	var second := _after(&"fire_bolt", START, 2.0)
	# The second cast is held up by a third of a beat more than the first.
	_send(remote, &"fire_bolt", second, second - START, 30_000 + BEAT / 3)
	assert_eq(foe_circle.cadence.verdict, Cadence.Verdict.FOLLOWED)
	assert_almost_eq(foe_circle.cadence.entry, 0.0, 0.001)
	assert_eq(foe_circle.last_result.cadence_links, 1)


func test_without_the_senders_word_it_can() -> void:
	var remote := add_managed(RemoteCaster.new()) as RemoteCaster
	remote.circle = foe_circle
	remote.me = foe
	remote.begin()
	_send(remote, &"fire_bolt", START, -1, 30_000)
	var second := _after(&"fire_bolt", START, 2.0)
	_send(remote, &"fire_bolt", second, -1, 30_000 + BEAT / 3)
	assert_eq(foe_circle.cadence.verdict, Cadence.Verdict.OFF_THE_BEAT, "which is what a sender from before cadence gets")


func test_a_sender_is_not_believed_beyond_what_the_network_could_do() -> void:
	var remote := add_managed(RemoteCaster.new()) as RemoteCaster
	remote.circle = foe_circle
	remote.me = foe
	remote.begin()
	_send(remote, &"fire_bolt", START, -1, 30_000)
	# It arrives two and a half beats after the last stroke, and claims to
	# have been made two seconds before that.
	var second := _after(&"fire_bolt", START, 2.5)
	_send(remote, &"fire_bolt", second, second - START - 2_000_000, 30_000)
	assert_eq(foe_circle.cadence.verdict, Cadence.Verdict.OFF_THE_BEAT, "it is judged by when it arrived")


# On the screen

func test_a_cast_in_cadence_is_written_beside_its_grade() -> void:
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	var fire_bolt := _spell(&"fire_bolt")
	arena.spell_bar.choose_spell(fire_bolt)
	for stroke in fire_bolt.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, START + stroke.tick * BEAT)
	var shown: SpellShow = arena.spell_show
	var written := shown.marks_of(SpellMark.Kind.NUMBER).map(func (mark): return mark.text)
	assert_eq(written, ["16"])

	shown.marks.clear()
	var second := _after(&"fire_bolt", START, 2.0)
	for stroke in fire_bolt.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, second + stroke.tick * BEAT)
	written = shown.marks_of(SpellMark.Kind.NUMBER).map(func (mark): return mark.text)
	assert_eq(written, ["2 in cadence", "17"])
	var kept: SpellMark = shown.marks_of(SpellMark.Kind.NUMBER)[0]
	var grade: SpellMark = shown.marks_of(SpellMark.Kind.GRADE)[0]
	assert_lt(kept.at.y, grade.at.y - grade.size / 2.0, "above the grade, and clear of it")
	assert_eq(arena.player_panel.duelist.status_text(), "In cadence, 2 in a row")
