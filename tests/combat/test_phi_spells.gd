extends TestCase
## The spells that use φ, Equivalence: Transmute, Exchange and Echo.
##
## Equivalence reads a state or rewrites one. Each of these takes something
## that is already there and has it be something else, or somebody else's.

const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const VERSUS_MENU := preload("res://magiteknician/menus/versus_menu.tscn")
const BEAT := 250_000
const NOW := 5_000_000

var me: Duelist
var foe: Duelist


func before_each() -> void:
	forget_progress()
	forget_settings()
	FakeLink.forget_hosts()
	Session.versus_spells = []
	Session.versus_foe_spells = []
	me = Duelist.new("You")
	foe = Duelist.new("Femble")


func after_each() -> void:
	forget_progress()
	forget_settings()
	FakeLink.forget_hosts()
	Session.versus_spells = []
	Session.versus_foe_spells = []


func _spell(id: StringName) -> Spell:
	return SpellLibrary.find(id)


func _verdict(quality: float = 1.0) -> CastResult:
	var tuning := CastScorer.default_tuning()
	var result := CastResult.new()
	result.quality = quality
	result.grade = tuning.grade(quality)
	result.potency = tuning.potency(quality) if result.grade != CastResult.Grade.FIZZLE else 0.0
	return result


func _cast(id: StringName, caster: Duelist = me, quality: float = 1.0) -> SpellOutcome:
	return SpellResolver.resolve(_spell(id), _verdict(quality), caster, foe if caster == me else me)


# The spells

func test_there_are_three_spells_that_use_equivalence() -> void:
	# As names, to be put in order: names that are interned are put in
	# the order they were first met, which is no order at all.
	var found: Array[String] = []
	for spell in SpellLibrary.all():
		if spell.rune_counts().has(Rune.Type.EQUIVELANCE):
			found.append(String(spell.id))
	found.sort()
	assert_eq(found, ["echo", "exchange", "transmute"])


func test_each_can_be_cast() -> void:
	for id in [&"echo", &"exchange", &"transmute"]:
		var spell := _spell(id)
		assert_not_null(spell, String(id))
		assert_eq(spell.problems(), PackedStringArray(), String(id))
		assert_gt(spell.strokes.size(), 2, "%s has a rhythm to be judged on" % [id])
		assert_gt(spell.chi_cost, 0.0)
		assert_false(spell.description.is_empty())
		assert_gt(spell.rank, Spell.Rank.NOVICE, "%s is not a beginner's spell" % [id])


func test_none_has_the_rhythm_of_another_spell() -> void:
	var seen := {}
	for spell in SpellLibrary.all():
		var rhythm := str(spell.ticks())
		if spell.rune_counts().has(Rune.Type.EQUIVELANCE):
			assert_false(seen.has(rhythm), "%s has the rhythm of %s" % [spell.display_name, seen.get(rhythm, "")])
		seen[rhythm] = spell.display_name


func test_every_kind_of_effect_can_be_described() -> void:
	for kind in SpellEffect.Kind.values():
		assert_true(SpellEffect.KIND_NAMES.has(kind))
		assert_false(SpellEffect.make(kind, 1.0, 5.0).describe().is_empty(), SpellEffect.KIND_NAMES[kind])
	assert_eq(_spell(&"transmute").describe_effects(), "makes up to 20 of a ward into health")
	assert_eq(_spell(&"exchange").describe_effects(), "exchanges wards with the foe")
	assert_eq(_spell(&"exchange").describe_effects(0.6), "exchanges wards, keeping 60% of the foe's")
	assert_eq(_spell(&"echo").describe_effects(), "echoes the foe's last spell at 75%")


func test_the_old_kinds_of_effect_keep_their_numbers() -> void:
	# They are written in the spells' files and sent between machines.
	assert_eq(SpellEffect.Kind.DAMAGE, 0)
	assert_eq(SpellEffect.Kind.REFLECT, 6)
	assert_eq(SpellEffect.Kind.ECHO, 7)
	assert_eq(SpellEffect.Kind.TRANSMUTE, 8)
	assert_eq(SpellEffect.Kind.EXCHANGE, 9)


# Transmute

func test_a_ward_is_made_into_health() -> void:
	me.health = 50.0
	me.raise_ward(26.0, 10.0)
	var outcome := _cast(&"transmute")
	assert_almost_eq(me.health, 70.0)
	assert_almost_eq(me.ward, 6.0)
	assert_almost_eq(outcome.total(SpellEffect.Kind.TRANSMUTE), 20.0)
	assert_eq(outcome.describe(), "You cast Transmute (S): 20 of the ward made health.")
	assert_almost_eq(foe.health, 100.0, 1e-6, "the foe is left alone")


func test_no_more_is_made_than_there_is_of_the_ward() -> void:
	me.health = 50.0
	me.raise_ward(12.0, 8.0)
	_cast(&"transmute")
	assert_almost_eq(me.health, 62.0)
	assert_false(me.is_warded(), "the whole of it was made over")
	assert_almost_eq(me.ward_seconds_left, 0.0)


func test_no_more_is_made_than_there_is_room_for() -> void:
	me.health = 95.0
	me.raise_ward(26.0, 10.0)
	_cast(&"transmute")
	assert_almost_eq(me.health, 100.0)
	assert_almost_eq(me.ward, 21.0, 1e-6, "and the rest of the ward is kept")


func test_a_poorer_cast_makes_less() -> void:
	me.health = 50.0
	me.raise_ward(26.0, 10.0)
	var outcome := _cast(&"transmute", me, 0.6)
	assert_lt(outcome.total(SpellEffect.Kind.TRANSMUTE), 20.0)
	assert_gt(outcome.total(SpellEffect.Kind.TRANSMUTE), 5.0)
	assert_almost_eq(me.health + me.ward, 76.0, 1e-4, "nothing is made of nothing")


func test_with_no_ward_there_is_nothing_to_make() -> void:
	me.health = 50.0
	var outcome := _cast(&"transmute")
	assert_almost_eq(me.health, 50.0)
	assert_false(outcome.entries[0]["landed"])
	assert_eq(outcome.describe(), "You cast Transmute (S) to no effect.")


func test_a_ward_that_turns_blows_back_still_does_with_what_is_left() -> void:
	me.health = 50.0
	me.raise_ward(26.0, 10.0)
	me.make_ward_reflect(0.3)
	_cast(&"transmute")
	assert_almost_eq(me.ward_reflect, 0.3)
	me.transmute(100.0)
	assert_almost_eq(me.ward_reflect, 0.0, 1e-6, "and when none is left, does not")


# Exchange

func test_two_wards_change_hands() -> void:
	me.raise_ward(5.0, 3.0)
	foe.raise_ward(26.0, 9.0)
	foe.make_ward_reflect(0.3)
	var outcome := _cast(&"exchange")
	assert_almost_eq(me.ward, 26.0)
	assert_almost_eq(me.ward_seconds_left, 9.0)
	assert_almost_eq(me.ward_reflect, 0.3, 1e-6, "with all that went with it")
	assert_almost_eq(foe.ward, 5.0)
	assert_almost_eq(foe.ward_seconds_left, 3.0)
	assert_almost_eq(foe.ward_reflect, 0.0)
	assert_eq(outcome.describe(), "You cast Exchange (S): wards exchanged, a ward of 26 for one of 5.")


func test_a_caster_with_no_ward_takes_the_foes_and_gives_none() -> void:
	foe.raise_ward(26.0, 9.0)
	var outcome := _cast(&"exchange")
	assert_almost_eq(me.ward, 26.0)
	assert_false(foe.is_warded())
	assert_true(outcome.entries[0]["took_ward"])
	assert_almost_eq(outcome.entries[0]["gave"], 0.0)


func test_a_caster_can_be_the_worse_for_it() -> void:
	me.raise_ward(26.0, 9.0)
	_cast(&"exchange")
	assert_false(me.is_warded())
	assert_almost_eq(foe.ward, 26.0, 1e-6, "equivalence does not mind which caster has which")


func test_a_poorer_cast_keeps_less_of_what_it_took() -> void:
	me.raise_ward(5.0, 3.0)
	foe.raise_ward(26.0, 9.0)
	var outcome := _cast(&"exchange", me, 0.6)
	var share: float = outcome.result.potency
	assert_almost_eq(me.ward, 26.0 * share, 1e-4)
	assert_lt(me.ward, 26.0)
	assert_almost_eq(foe.ward, 5.0, 1e-6, "the foe has the caster's whole")


func test_with_no_wards_there_is_nothing_to_exchange() -> void:
	var outcome := _cast(&"exchange")
	assert_false(outcome.entries[0]["landed"])
	assert_false(me.is_warded())
	assert_false(foe.is_warded())
	assert_eq(outcome.describe(), "You cast Exchange (S) to no effect.")


func test_a_ward_that_is_had_is_not_raised() -> void:
	# A weaker ward is wasted on a stronger when it is raised. One that is
	# had by exchange takes the place of what was there.
	me.raise_ward(26.0, 9.0)
	me.have_ward(5.0, 3.0)
	assert_almost_eq(me.ward, 5.0)
	me.have_ward(0.0, 0.0)
	assert_false(me.is_warded())
	assert_almost_eq(me.ward_seconds_left, 0.0)


func test_a_ward_that_was_taken_runs_down_and_lapses() -> void:
	foe.raise_ward(26.0, 9.0)
	_cast(&"exchange")
	me.advance(8.0)
	assert_true(me.is_warded())
	me.advance(2.0)
	assert_false(me.is_warded())


# Echo

func test_an_echo_casts_the_foes_last_spell_again() -> void:
	foe.last_spell = _spell(&"fire_bolt")
	var outcome := _cast(&"echo")
	assert_almost_eq(foe.health, 100.0 - 16.0 * 0.75)
	assert_eq(outcome.spell_echoed(), _spell(&"fire_bolt"))
	assert_almost_eq(outcome.damage_dealt(), 12.0)
	assert_eq(outcome.describe(), "You cast Echo (S): echoing Fire Bolt, 12 damage.")


func test_what_was_the_foes_own_is_the_casters_own() -> void:
	foe.last_spell = _spell(&"ward")
	_cast(&"echo")
	assert_almost_eq(me.ward, 12.0 * 0.75)
	assert_false(foe.is_warded())
	foe.last_spell = _spell(&"mend")
	me.health = 50.0
	_cast(&"echo")
	assert_almost_eq(me.health, 50.0 + 12.0 * 0.75)


func test_every_effect_of_the_spell_is_echoed() -> void:
	foe.last_spell = _spell(&"frost_bolt")
	var outcome := _cast(&"echo")
	assert_almost_eq(outcome.damage_dealt(), 12.0 * 0.75)
	assert_true(foe.is_chilled())
	assert_eq(outcome.entries.size(), 3, "the echo, and the two things it did")
	assert_false(outcome.entries[0].get("echo", false))
	assert_true(outcome.entries[1]["echo"])
	assert_true(outcome.entries[2]["echo"])


func test_a_poorer_echo_is_fainter() -> void:
	foe.last_spell = _spell(&"lightning")
	var outcome := _cast(&"echo", me, 0.6)
	assert_almost_eq(outcome.damage_dealt(), 32.0 * 0.75 * outcome.result.potency, 1e-4)
	assert_lt(outcome.damage_dealt(), 24.0)


func test_with_nothing_cast_there_is_nothing_to_echo() -> void:
	var outcome := _cast(&"echo")
	assert_null(outcome.spell_echoed())
	assert_almost_eq(foe.health, 100.0)
	assert_eq(outcome.describe(), "You cast Echo (S): with nothing to echo.")


func test_an_echo_of_an_echo_is_of_nothing() -> void:
	foe.last_spell = _spell(&"echo")
	var outcome := _cast(&"echo")
	assert_eq(outcome.entries.size(), 1)
	assert_almost_eq(foe.health, 100.0)


func test_an_echo_does_as_any_blow_does_with_a_ward() -> void:
	foe.last_spell = _spell(&"fire_bolt")
	foe.raise_ward(50.0, 10.0)
	var outcome := _cast(&"echo")
	assert_almost_eq(outcome.damage_absorbed(), 12.0)
	assert_almost_eq(foe.health, 100.0)


# What was last cast, in a duel

func _duel() -> Duel:
	var my_circle: SpellCircle = add_managed(SpellCircle.new())
	var foe_circle: SpellCircle = add_managed(SpellCircle.new())
	var npc: NpcCaster = add_managed(NpcCaster.new())
	var duel: Duel = add_managed(Duel.new())
	duel.set_process(false)
	me.spellbook = Spellbook.complete()
	foe.spellbook = Spellbook.complete()
	duel.setup(me, foe, my_circle, foe_circle, npc)
	duel.begin()
	npc.halt()
	my_circle.accepts_input = false
	return duel


func _strike_out(circle: SpellCircle, id: StringName, first_usec: int, wobble: float = 0.0) -> void:
	var spell := _spell(id)
	circle.prepare(spell)
	for i in spell.strokes.size():
		var stroke := spell.strokes[i]
		var off := roundi(wobble * BEAT * (1.0 if i % 2 == 0 else -1.0))
		circle.strike(stroke.rune, stroke.position, first_usec + stroke.tick * BEAT + off)


func test_a_duel_remembers_what_each_last_cast() -> void:
	var duel := _duel()
	assert_null(me.last_spell)
	_strike_out(duel.player_circle, &"fire_bolt", NOW)
	assert_eq(me.last_spell, _spell(&"fire_bolt"))
	assert_null(foe.last_spell)
	_strike_out(duel.opponent_circle, &"ward", NOW)
	assert_eq(foe.last_spell, _spell(&"ward"))


func test_a_cast_that_fizzled_was_not_cast() -> void:
	var duel := _duel()
	_strike_out(duel.player_circle, &"fire_bolt", NOW)
	_strike_out(duel.player_circle, &"lightning", NOW + 20 * BEAT, 0.45)
	assert_true(duel.outcomes[-1].fizzled)
	assert_eq(me.last_spell, _spell(&"fire_bolt"))


func test_what_an_echo_echoed_is_what_was_cast() -> void:
	var duel := _duel()
	_strike_out(duel.opponent_circle, &"fire_bolt", NOW)
	_strike_out(duel.player_circle, &"echo", NOW)
	assert_eq(me.last_spell, _spell(&"fire_bolt"), "and not the echo")
	var before := me.health
	_strike_out(duel.opponent_circle, &"echo", NOW + 40 * BEAT)
	assert_eq(duel.outcomes[-1].spell_echoed(), _spell(&"fire_bolt"))
	assert_almost_eq(before - me.health, 12.0, 1e-4, "so the two can send one spell back and forth")


func test_an_echo_of_nothing_leaves_what_was_last_cast_alone() -> void:
	var duel := _duel()
	_strike_out(duel.player_circle, &"spark", NOW)
	_strike_out(duel.player_circle, &"echo", NOW + 40 * BEAT)
	assert_null(duel.outcomes[-1].spell_echoed())
	assert_eq(me.last_spell, _spell(&"spark"))


# Between two machines

func test_what_each_did_survives_the_crossing() -> void:
	foe.last_spell = _spell(&"frost_bolt")
	me.raise_ward(5.0, 3.0)
	foe.raise_ward(26.0, 9.0)
	for id in [&"echo", &"exchange", &"transmute"]:
		var outcome := _cast(id)
		var arrived: Dictionary = DuelProtocol.through_json(DuelProtocol.resolved(outcome, true))
		assert_eq(DuelProtocol.problems(arrived), PackedStringArray(), String(id))
		var rebuilt := SpellOutcome.from_dict(arrived, Duelist.new("You"), Duelist.new("Femble"))
		assert_eq(rebuilt.describe(), outcome.describe())
		assert_eq(rebuilt.entries.size(), outcome.entries.size())
		assert_eq(rebuilt.spell_echoed(), outcome.spell_echoed())
		for i in outcome.entries.size():
			assert_eq(rebuilt.entries[i].get("echo", false), outcome.entries[i].get("echo", false))


func test_a_greeting_says_which_spells_the_game_has() -> void:
	var greeting: Dictionary = DuelProtocol.through_json(DuelProtocol.hello("Gil", [&"echo", &"ward"]))
	assert_eq(DuelProtocol.problems(greeting), PackedStringArray())
	assert_eq(greeting["library"].size(), SpellLibrary.all().size())
	assert_eq(DuelProtocol.spells_in_common(greeting), Loadout.every_spell())


func test_a_game_that_does_not_say_has_the_spells_there_were() -> void:
	var old := {"type": "hello", "version": 1, "name": "Gil"}
	var common := DuelProtocol.spells_in_common(old)
	assert_eq(common.size(), 9)
	for id in [&"echo", &"exchange", &"transmute"]:
		assert_false(common.has(id), String(id))
	for id in Loadout.LEGACY:
		assert_true(SpellLibrary.has_spell(id), "%s is still a spell" % [id])
		assert_true(common.has(id))
	assert_eq(DuelProtocol.VERSION, 1, "and the two can still duel")


func test_a_spell_this_game_has_never_heard_of_is_left_out_and_not_refused() -> void:
	var newer := DuelProtocol.hello("Gil", [&"ward", &"spark"])
	newer["spells"] = ["ward", "meteor", "spark"]
	newer["library"] = ["ward", "meteor", "spark", "fire_bolt"]
	assert_eq(DuelProtocol.problems(DuelProtocol.through_json(newer)), PackedStringArray())
	assert_eq(DuelProtocol.spells_in(newer), [&"ward", &"spark"])
	var common := DuelProtocol.spells_in_common(newer).map(func (id): return String(id))
	common.sort()
	assert_eq(common, ["fire_bolt", "spark", "ward"])


func test_only_spells_both_games_have_are_brought() -> void:
	var host_link: FakeLink = add_managed(FakeLink.new())
	Settings.choose_versus_spells([&"echo", &"ward", &"exchange", &"fire_bolt"])
	var menu: Node = VERSUS_MENU.instantiate()
	menu.link = host_link
	add_managed(menu)
	menu.player_name.text = "Hana"
	menu._on_host_pressed()
	assert_eq(menu.what_i_bring(), [&"echo", &"ward", &"exchange", &"fire_bolt"], "until somebody says otherwise")
	# Somebody joins whose game is from before these spells.
	menu._on_received({"type": "hello", "version": 1, "name": "Gil"})
	assert_eq(menu.what_i_bring(), [&"ward", &"fire_bolt"])
	menu._on_begin_pressed()
	assert_eq(Session.versus_spells, [&"ward", &"fire_bolt"])
	assert_eq(Session.versus_foe_spells, [], "they did not say what they bring, and bring what they have")
	var start := DuelProtocol.start("Hana", "Gil", menu.what_i_bring(), [])
	assert_eq(start["host_spells"], ["ward", "fire_bolt"])
	assert_false(start.has("guest_spells"))


func test_a_player_who_chose_only_spells_the_other_has_not_brings_what_there_is() -> void:
	var host_link: FakeLink = add_managed(FakeLink.new())
	Settings.choose_versus_spells([&"echo", &"exchange"])
	var menu: Node = VERSUS_MENU.instantiate()
	menu.link = host_link
	add_managed(menu)
	menu._on_host_pressed()
	menu._on_received({"type": "hello", "version": 1, "name": "Gil"})
	var brought: Array[StringName] = menu.what_i_bring()
	assert_eq(brought.size(), Loadout.SIZE)
	assert_true(Loadout.does_harm(brought))


# What an NPC makes of them

func _weight(id: StringName, foe_spell: Spell = null) -> float:
	return NpcBrain.weigh(_spell(id), me, foe, foe_spell, CasterProfile.new())


func test_an_npc_echoes_what_is_worth_echoing() -> void:
	assert_almost_eq(_weight(&"echo"), 0.0, 1e-6, "nothing has been cast")
	foe.last_spell = _spell(&"lightning")
	var strong := _weight(&"echo")
	foe.last_spell = _spell(&"spark")
	var weak := _weight(&"echo")
	assert_gt(strong, weak)
	assert_gt(weak, 0.0)
	assert_lt(strong, _weight(&"lightning"), "and would sooner cast the spell itself")
	foe.last_spell = _spell(&"echo")
	assert_almost_eq(_weight(&"echo"), 0.0)


func test_an_npc_takes_a_ward_that_is_better_than_its_own() -> void:
	assert_almost_eq(_weight(&"exchange"), 0.0)
	foe.raise_ward(26.0, 9.0)
	var taking := _weight(&"exchange")
	assert_gt(taking, 0.0)
	me.raise_ward(20.0, 9.0)
	assert_lt(_weight(&"exchange"), taking, "the less there is to gain, the less it wants to")
	me.raise_ward(30.0, 9.0)
	assert_almost_eq(_weight(&"exchange"), 0.0, 1e-6, "and it keeps a ward that is the better of the two")


func test_an_npc_makes_health_of_a_ward_it_does_not_need() -> void:
	me.raise_ward(26.0, 9.0)
	assert_almost_eq(_weight(&"transmute"), 0.0, 1e-6, "it is not hurt")
	me.health = 25.0
	assert_gt(_weight(&"transmute"), 0.0)
	assert_almost_eq(_weight(&"transmute", _spell(&"lightning")), 0.0, 1e-6, "with a blow coming it keeps the ward")
	me.have_ward(0.0, 0.0)
	assert_almost_eq(_weight(&"transmute"), 0.0, 1e-6, "and with no ward there is nothing to make")


func test_the_opponents_who_know_them_can_still_do_harm() -> void:
	var campaign := Session.campaign
	assert_eq(campaign.problems(), PackedStringArray())
	var knowing := 0
	for index in campaign.stage_count():
		var opponent := campaign.stage(index).opponent
		assert_eq(opponent.problems(), PackedStringArray(), opponent.display_name)
		for id in [&"echo", &"exchange", &"transmute"]:
			if opponent.spell_ids.has(id):
				knowing += 1
	assert_gt(knowing, 2)


func test_the_campaign_teaches_all_three() -> void:
	var campaign := Session.campaign
	var taught := campaign.spell_ids_after(campaign.stage_count())
	for id in [&"echo", &"exchange", &"transmute"]:
		assert_true(taught.has(id), String(id))
	assert_eq(taught.size(), SpellLibrary.all().size(), "and every other spell there is")
	assert_gt(taught.size(), Loadout.SIZE, "which is more than can be brought")


# What is shown

func _a_show() -> SpellShow:
	var my_circle := SpellCircle.new()
	my_circle.accepts_input = false
	my_circle.position = Vector2(390, 336)
	add_managed(my_circle)
	var foe_circle := SpellCircle.new()
	foe_circle.accepts_input = false
	foe_circle.position = Vector2(936, 264)
	foe_circle.scale = Vector2(0.5, 0.5)
	add_managed(foe_circle)
	var show_ := SpellShow.new()
	show_.set_process(false)
	add_managed(show_)
	show_.place(me, my_circle)
	show_.place(foe, foe_circle)
	return show_


func _written(show_: SpellShow) -> Array:
	return show_.marks_of(SpellMark.Kind.NUMBER).map(func (mark): return mark.text)


func test_an_echo_is_shown_as_what_it_echoed() -> void:
	var show_ := _a_show()
	foe.last_spell = _spell(&"fire_bolt")
	show_.show_outcome(_cast(&"echo"), NOW)
	assert_eq(_written(show_), ["echoing Fire Bolt", "12"])
	assert_eq(show_.count_of(SpellMark.Kind.STREAK), 1)
	assert_eq(show_.count_of(SpellMark.Kind.BURST), 1)
	assert_eq(show_.marks_of(SpellMark.Kind.STREAK)[0].bands, SpellShow.bands_of(_spell(&"echo")), "in the colours of the echo's own runes")


func test_an_echo_of_nothing_says_so() -> void:
	var show_ := _a_show()
	show_.show_outcome(_cast(&"echo"), NOW)
	assert_eq(_written(show_), ["nothing to echo"])
	assert_eq(show_.count_of(SpellMark.Kind.STREAK), 0)


func test_an_exchange_is_shown_on_both_circles() -> void:
	var show_ := _a_show()
	me.raise_ward(5.0, 3.0)
	foe.raise_ward(26.0, 9.0)
	show_.show_outcome(_cast(&"exchange"), NOW)
	var raised := show_.marks_of(SpellMark.Kind.RAISE)
	assert_eq(raised.size(), 2)
	assert_eq(raised[0].at, show_.stand_of(me).centre)
	assert_eq(raised[1].at, show_.stand_of(foe).centre)
	assert_eq(_written(show_), ["wards exchanged"])
	var streak := show_.marks_of(SpellMark.Kind.STREAK)[0]
	assert_gt(streak.at.distance_to(show_.stand_of(foe).centre), show_.stand_of(foe).radius, "it goes as far as the ward")


func test_a_ward_that_is_taken_and_not_replaced_is_seen_to_go() -> void:
	var show_ := _a_show()
	foe.raise_ward(26.0, 9.0)
	show_.show_outcome(_cast(&"exchange"), NOW)
	assert_eq(show_.count_of(SpellMark.Kind.RAISE), 1)
	var gone := show_.marks_of(SpellMark.Kind.SHATTER)
	assert_eq(gone.size(), 1)
	assert_eq(gone[0].at, show_.stand_of(foe).centre)


func test_an_exchange_of_nothing_shows_nothing() -> void:
	var show_ := _a_show()
	show_.show_outcome(_cast(&"exchange"), NOW)
	assert_eq(show_.count_of(SpellMark.Kind.STREAK), 0)
	assert_eq(_written(show_), [])


func test_a_ward_made_into_health_is_shown_as_health() -> void:
	var show_ := _a_show()
	me.health = 50.0
	me.raise_ward(26.0, 10.0)
	show_.show_outcome(_cast(&"transmute"), NOW)
	assert_eq(show_.count_of(SpellMark.Kind.MOTES), 1)
	assert_eq(_written(show_), ["+20"])
	assert_eq(show_.marks_of(SpellMark.Kind.MOTES)[0].colour, SpellShow.KIND_COLOURS[SpellEffect.Kind.TRANSMUTE])
	assert_eq(show_.count_of(SpellMark.Kind.STREAK), 0)


func test_what_is_shown_is_heard() -> void:
	var show_ := _a_show()
	foe.raise_ward(26.0, 9.0)
	show_.show_outcome(_cast(&"exchange"), NOW)
	show_.announce(NOW + 1_000_000)
	var heard := show_.voice.sounded.map(func (played): return played["sound"])
	assert_true(SpellSounds.WARD_UP in heard)
	assert_true(SpellSounds.WARD_BREAK in heard)


# In the arena

func test_the_player_can_cast_them() -> void:
	Session.spell_ids = [&"echo", &"exchange", &"transmute", &"ward"]
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	assert_eq(arena.spell_bar.slot_count(), 4)
	arena.duel.opponent.last_spell = _spell(&"fire_bolt")
	var before: float = arena.duel.opponent.health
	var echo := _spell(&"echo")
	arena.spell_bar.choose_spell(echo)
	for stroke in echo.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, NOW + stroke.tick * BEAT)
	assert_almost_eq(before - arena.duel.opponent.health, 12.0)
	assert_eq(arena.combat_log.lines[-1], "You cast Echo (S): echoing Fire Bolt, 12 damage.")
