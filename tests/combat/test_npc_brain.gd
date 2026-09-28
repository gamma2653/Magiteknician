extends TestCase
## NpcBrain: which spell an NPC reaches for.

const DRAWS := 400

var rng: RandomNumberGenerator
var me: Duelist
var foe: Duelist
var profile: CasterProfile


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 77
	me = Duelist.new("Npc")
	foe = Duelist.new("Player")
	me.spellbook = Spellbook.of([&"spark", &"fire_bolt", &"ward", &"mend"])
	profile = CasterProfile.new()


## How often each spell is chosen over many draws, keyed by id.
func _tally(foe_spell: Spell = null) -> Dictionary:
	var counts := {}
	for i in DRAWS:
		var spell := NpcBrain.choose(me, foe, foe_spell, profile, rng)
		var id := spell.id if spell != null else &"nothing"
		counts[id] = counts.get(id, 0) + 1
	return counts


func _share(counts: Dictionary, id: StringName) -> float:
	return counts.get(id, 0) / float(DRAWS)


func test_with_nothing_else_going_on_it_attacks() -> void:
	var counts := _tally()
	assert_gt(_share(counts, &"spark") + _share(counts, &"fire_bolt"), 0.85)
	assert_gt(_share(counts, &"fire_bolt"), _share(counts, &"spark"), "and prefers the heavier blow")
	assert_eq(counts.get(&"mend", 0), 0, "it does not heal at full health")


func test_it_wards_when_it_sees_an_attack_coming() -> void:
	var calm := _share(_tally(), &"ward")
	var threatened := _share(_tally(SpellLibrary.find(&"fire_bolt")), &"ward")
	assert_gt(threatened, calm + 0.3)


func test_a_heavier_attack_is_more_worth_warding() -> void:
	var light := _share(_tally(SpellLibrary.find(&"spark")), &"ward")
	var heavy := _share(_tally(SpellLibrary.find(&"lightning")), &"ward")
	assert_gt(heavy, light)


func test_a_reckless_caster_does_not_bother_to_ward() -> void:
	profile.caution = 0.0
	assert_eq(_tally(SpellLibrary.find(&"fire_bolt")).get(&"ward", 0), 0)


func test_it_does_not_ward_over_a_ward_as_good() -> void:
	me.raise_ward(20.0, 8.0)
	assert_eq(_tally(SpellLibrary.find(&"fire_bolt")).get(&"ward", 0), 0)


func test_a_foes_ward_is_not_a_threat() -> void:
	var calm := _share(_tally(), &"ward")
	var watching_a_ward := _share(_tally(SpellLibrary.find(&"bulwark")), &"ward")
	assert_almost_eq(watching_a_ward, calm, 0.06)


func test_it_heals_when_badly_hurt() -> void:
	me.take_damage(75.0)
	assert_gt(_share(_tally(), &"mend"), 0.5)


func test_it_heals_more_readily_the_worse_it_is_hurt() -> void:
	me.health = 38.0
	var hurt := _share(_tally(), &"mend")
	me.health = 10.0
	var dying := _share(_tally(), &"mend")
	assert_gt(dying, hurt)


func test_it_presses_less_hard_against_a_warded_foe() -> void:
	var open := NpcBrain.weigh(SpellLibrary.find(&"fire_bolt"), me, foe, null, profile)
	foe.raise_ward(20.0, 8.0)
	var warded := NpcBrain.weigh(SpellLibrary.find(&"fire_bolt"), me, foe, null, profile)
	assert_lt(warded, open)


func test_it_only_chooses_what_it_can_afford() -> void:
	me.chi = 7.0
	var counts := _tally()
	assert_eq(counts.keys(), [&"spark"], "only Spark costs 6 chi or less")


func test_with_no_chi_it_chooses_nothing() -> void:
	me.chi = 0.0
	assert_null(NpcBrain.choose(me, foe, null, profile, rng))


func test_with_no_spells_it_chooses_nothing() -> void:
	me.spellbook = Spellbook.new()
	assert_null(NpcBrain.choose(me, foe, null, profile, rng))


func test_the_same_seed_makes_the_same_choices() -> void:
	var first := []
	for i in 20:
		first.append(NpcBrain.choose(me, foe, null, profile, rng).id)
	rng.seed = 77
	var second := []
	for i in 20:
		second.append(NpcBrain.choose(me, foe, null, profile, rng).id)
	assert_eq(first, second)
