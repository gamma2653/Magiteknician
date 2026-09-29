extends TestCase
## DuelProtocol: the messages, and the checks on them.


func _spark() -> Spell:
	return SpellLibrary.find(&"spark")


func test_every_message_survives_json() -> void:
	var host := Duelist.new("Hana")
	var guest := Duelist.new("Gil")
	var outcome := SpellResolver.resolve(_spark(), CastScorer.score([0, 1, 2], [0, 300_000, 600_000]), host, guest)
	var messages := [
		DuelProtocol.begin(_spark()),
		DuelProtocol.stroke(Rune.Type.FLOW, Vector2(-90.5, 50.25), 123_456),
		DuelProtocol.abandon(),
		DuelProtocol.snapshot(host, guest, 12.5),
		DuelProtocol.resolved(outcome, true),
		DuelProtocol.broken(_spark(), false),
		DuelProtocol.finished(true),
	]
	for message in messages:
		var arrived: Variant = DuelProtocol.through_json(message)
		assert_eq(DuelProtocol.problems(arrived), PackedStringArray(), message[DuelProtocol.TYPE])
		assert_eq(arrived[DuelProtocol.TYPE], message[DuelProtocol.TYPE])


func test_a_stroke_says_what_where_and_when() -> void:
	var arrived: Dictionary = DuelProtocol.through_json(DuelProtocol.stroke(Rune.Type.DECAY, Vector2(12.5, -40), 250_000))
	assert_eq(int(arrived["rune"]), Rune.Type.DECAY)
	assert_almost_eq(arrived["x"], 12.5)
	assert_almost_eq(arrived["y"], -40.0)
	assert_eq(int(arrived["t"]), 250_000)


func test_spells_are_named_by_id() -> void:
	assert_eq(DuelProtocol.begin(_spark())["spell"], "spark")


func test_what_is_not_a_message_is_refused() -> void:
	for nonsense in [null, 42, "begin", [1, 2], {}, {"type": 7}, {"type": "dance"}]:
		assert_gt(DuelProtocol.problems(nonsense).size(), 0, str(nonsense))


func test_a_cast_must_name_a_spell_that_exists() -> void:
	assert_gt(DuelProtocol.problems({"type": "begin"}).size(), 0)
	assert_gt(DuelProtocol.problems({"type": "begin", "spell": 3}).size(), 0)
	assert_gt(DuelProtocol.problems({"type": "begin", "spell": "no_such_spell"}).size(), 0)


func test_a_stroke_must_be_whole_and_sane() -> void:
	var good := DuelProtocol.stroke(Rune.Type.FLOW, Vector2.ZERO, 0)
	assert_eq(DuelProtocol.problems(good).size(), 0)
	for field in ["rune", "x", "y", "t"]:
		var missing := good.duplicate()
		missing.erase(field)
		assert_gt(DuelProtocol.problems(missing).size(), 0, "without %s" % [field])
		var wrong := good.duplicate()
		wrong[field] = "seven"
		assert_gt(DuelProtocol.problems(wrong).size(), 0, "%s as text" % [field])

	var no_such_rune := good.duplicate()
	no_such_rune["rune"] = 99
	assert_gt(DuelProtocol.problems(no_such_rune).size(), 0)

	var before_the_cast := good.duplicate()
	before_the_cast["t"] = -5
	assert_gt(DuelProtocol.problems(before_the_cast).size(), 0)

	var nowhere := good.duplicate()
	nowhere["x"] = INF
	assert_gt(DuelProtocol.problems(nowhere).size(), 0)


func test_a_snapshot_carries_both_duelists() -> void:
	var host := Duelist.new("Hana")
	var guest := Duelist.new("Gil", 80.0)
	host.take_damage(30.0)
	guest.raise_ward(12.0, 8.0)
	guest.apply_chill(0.35, 6.0)
	guest.casting = _spark()
	var arrived: Dictionary = DuelProtocol.through_json(DuelProtocol.snapshot(host, guest, 41.0))

	var copy := Duelist.new()
	copy.apply_dict(arrived["guest"])
	assert_eq(copy.display_name, "Gil")
	assert_almost_eq(copy.max_health, 80.0)
	assert_almost_eq(copy.ward, 12.0)
	assert_almost_eq(copy.ward_seconds_left, 8.0)
	assert_almost_eq(copy.chill, 0.35)
	assert_eq(copy.casting, _spark())
	copy.apply_dict(arrived["host"])
	assert_almost_eq(copy.health, 70.0)
	assert_null(copy.casting)
	assert_false(copy.is_warded())


func test_applying_a_snapshot_announces_what_changed() -> void:
	var copy := Duelist.new("Gil")
	var events := []
	copy.health_changed.connect(func (health, _max): events.append("health %d" % [health]))
	copy.damaged.connect(func (amount, _absorbed): events.append("damaged %d" % [amount]))
	copy.precision_changed.connect(func (precision): events.append("precision %.2f" % [precision]))
	copy.defeated.connect(func (): events.append("defeated"))

	var there := Duelist.new("Gil")
	there.take_damage(25.0)
	there.apply_chill(0.35, 6.0)
	copy.apply_dict(there.to_dict())
	assert_eq(events, ["health 75", "damaged 25", "precision 0.65"])

	events.clear()
	there.take_damage(500.0)
	copy.apply_dict(there.to_dict())
	assert_eq(events, ["health 0", "damaged 75", "defeated"])


func test_a_snapshot_with_parts_missing_changes_only_what_it_has() -> void:
	var copy := Duelist.new("Gil")
	copy.apply_dict({"health": 40.0})
	assert_almost_eq(copy.health, 40.0)
	assert_almost_eq(copy.chi, 100.0)
	assert_eq(copy.display_name, "Gil")


func test_an_outcome_is_sent_as_a_line_for_the_log() -> void:
	var host := Duelist.new("Hana")
	var guest := Duelist.new("Gil")
	var outcome := SpellResolver.resolve(_spark(), CastScorer.score([0, 1, 2], [0, 300_000, 600_000]), guest, host)
	var message := DuelProtocol.resolved(outcome, false)
	assert_eq(message["line"], "Gil cast Spark (S): 5 damage.")
	assert_false(message["by_host"])
	assert_eq(message["grade"], CastResult.Grade.S)


func test_an_outcome_says_what_the_cast_did() -> void:
	var host := Duelist.new("Hana")
	var guest := Duelist.new("Gil")
	host.raise_ward(10.0, 8.0)
	host.make_ward_reflect(0.5)
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	var outcome := SpellResolver.resolve(fire_bolt, CastScorer.score(fire_bolt.ticks(), _on_the_beat(fire_bolt)), guest, host)
	var arrived: Dictionary = DuelProtocol.through_json(DuelProtocol.resolved(outcome, false))
	assert_eq(DuelProtocol.problems(arrived), PackedStringArray())

	# On the other machine the same two players are other duelists.
	var gil_there := Duelist.new("Gil")
	var hana_there := Duelist.new("Hana")
	var rebuilt := SpellOutcome.from_dict(arrived, gil_there, hana_there)
	assert_eq(rebuilt.spell, fire_bolt)
	assert_eq(rebuilt.caster, gil_there)
	assert_eq(rebuilt.target, hana_there)
	assert_eq(rebuilt.result.grade, outcome.result.grade)
	assert_almost_eq(rebuilt.result.potency, outcome.result.potency)
	assert_almost_eq(rebuilt.result.quality, outcome.result.quality)
	assert_false(rebuilt.fizzled)
	assert_eq(rebuilt.entries.size(), 1)
	var entry: Dictionary = rebuilt.entries[0]
	assert_eq(entry["kind"], SpellEffect.Kind.DAMAGE)
	assert_eq(entry["on"], hana_there)
	assert_almost_eq(entry["absorbed"], 10.0)
	assert_almost_eq(entry["through"], 6.0)
	assert_almost_eq(entry["reflected"], 5.0)
	assert_true(entry["broke_ward"])
	assert_almost_eq(rebuilt.damage_dealt(), outcome.damage_dealt())
	assert_eq(rebuilt.describe(), outcome.describe(), "and it reads the same")


func test_every_kind_of_effect_survives_the_crossing() -> void:
	for spell in SpellLibrary.all():
		var host := Duelist.new("Hana")
		var guest := Duelist.new("Gil")
		host.health = 50.0
		guest.raise_ward(8.0, 8.0)
		guest.casting = SpellLibrary.find(&"lightning")
		var outcome := SpellResolver.resolve(spell, CastScorer.score(spell.ticks(), _on_the_beat(spell)), host, guest)
		var arrived: Dictionary = DuelProtocol.through_json(DuelProtocol.resolved(outcome, true))
		assert_eq(DuelProtocol.problems(arrived), PackedStringArray(), spell.display_name)
		var rebuilt := SpellOutcome.from_dict(arrived, Duelist.new("Hana"), Duelist.new("Gil"))
		assert_eq(rebuilt.entries.size(), outcome.entries.size(), spell.display_name)
		assert_eq(rebuilt.describe(), outcome.describe())
		for i in outcome.entries.size():
			var was: Dictionary = outcome.entries[i]
			var now: Dictionary = rebuilt.entries[i]
			assert_eq(now["kind"], was["kind"])
			assert_eq(now["on"] == rebuilt.caster, was["on"] == outcome.caster, "on the same side")
			assert_eq(now.get("broke"), was.get("broke"))


func test_a_broken_cast_is_named_across_the_crossing() -> void:
	var host := Duelist.new("Hana")
	var guest := Duelist.new("Gil")
	guest.casting = SpellLibrary.find(&"lightning")
	var flinch := SpellLibrary.find(&"flinch")
	var outcome := SpellResolver.resolve(flinch, CastScorer.score(flinch.ticks(), _on_the_beat(flinch)), host, guest)
	var arrived: Dictionary = DuelProtocol.through_json(DuelProtocol.resolved(outcome, true))
	assert_eq(arrived["entries"][0]["broke"], "lightning")
	var rebuilt := SpellOutcome.from_dict(arrived, Duelist.new("Hana"), Duelist.new("Gil"))
	assert_eq(rebuilt.spell_broken(), SpellLibrary.find(&"lightning"))


func test_a_fizzle_survives_the_crossing() -> void:
	var outcome := SpellResolver.resolve(_spark(), CastResult.fizzle(), Duelist.new("Hana"), Duelist.new("Gil"))
	var arrived: Dictionary = DuelProtocol.through_json(DuelProtocol.resolved(outcome, true))
	assert_eq(DuelProtocol.problems(arrived), PackedStringArray())
	var rebuilt := SpellOutcome.from_dict(arrived, Duelist.new("Hana"), Duelist.new("Gil"))
	assert_true(rebuilt.fizzled)
	assert_eq(rebuilt.entries.size(), 0)
	assert_eq(rebuilt.describe(), "Hana's Spark fizzled.")


func test_an_outcome_from_before_spells_were_shown_is_still_a_message() -> void:
	# Showing spells did not change which versions can duel each other.
	assert_eq(DuelProtocol.VERSION, 1)
	var old := {"type": "resolved", "by_host": true, "spell": "spark", "grade": 0, "quality": 1.0, "line": "Hana cast Spark (S): 5 damage."}
	assert_eq(DuelProtocol.problems(DuelProtocol.through_json(old)), PackedStringArray())


func test_an_outcome_that_says_what_it_did_has_to_say_it_properly() -> void:
	var outcome := SpellResolver.resolve(_spark(), CastScorer.score([0, 1, 2], [0, 300_000, 600_000]), Duelist.new("Hana"), Duelist.new("Gil"))
	var good := DuelProtocol.resolved(outcome, true)
	assert_eq(DuelProtocol.problems(good), PackedStringArray())

	var no_list := good.duplicate(true)
	no_list["entries"] = "plenty"
	assert_gt(DuelProtocol.problems(no_list).size(), 0)

	var no_such_kind := good.duplicate(true)
	no_such_kind["entries"][0]["kind"] = 99
	assert_gt(DuelProtocol.problems(no_such_kind).size(), 0)

	var no_such_spell := good.duplicate(true)
	no_such_spell["spell"] = "fireball_of_doom"
	assert_gt(DuelProtocol.problems(no_such_spell).size(), 0)

	var no_potency := good.duplicate(true)
	no_potency.erase("potency")
	assert_gt(DuelProtocol.problems(no_potency).size(), 0)


func test_an_outcome_that_makes_no_sense_is_rebuilt_as_far_as_it_does() -> void:
	var me := Duelist.new("Gil")
	var foe := Duelist.new("Hana")
	var rebuilt := SpellOutcome.from_dict({
		"spell": "spark", "grade": 99, "quality": 1.0, "potency": 1.0,
		"entries": [{"kind": 99}, "nonsense", {"kind": 0, "through": 5.0}],
	}, me, foe)
	assert_eq(rebuilt.result.grade, CastResult.Grade.FIZZLE, "a grade there is none of is the last there is")
	assert_eq(rebuilt.entries.size(), 1)
	assert_eq(rebuilt.entries[0]["on"], foe)
	assert_eq(SpellOutcome.from_dict({}, me, foe).entries.size(), 0)


func _on_the_beat(spell: Spell) -> Array[int]:
	var times: Array[int] = []
	for stroke in spell.strokes:
		times.append(stroke.tick * 300_000)
	return times


func test_a_line_is_put_in_the_second_person_for_whoever_it_is_about() -> void:
	assert_eq(DuelProtocol.in_second_person("Gil cast Spark (S): 5 damage.", "Gil"), "You cast Spark (S): 5 damage.")
	assert_eq(DuelProtocol.in_second_person("Gil's Spark fizzled.", "Gil"), "Your Spark fizzled.")
	assert_eq(DuelProtocol.in_second_person("Hana cast Spark (S): 5 damage.", "Gil"), "Hana cast Spark (S): 5 damage.")
	assert_eq(DuelProtocol.in_second_person("Gilbert cast Spark (S): 5 damage.", "Gil"), "Gilbert cast Spark (S): 5 damage.")
