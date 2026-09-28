extends TestCase
## Duelist: health, chi and wards.

var duelist: Duelist
var events: Array


func before_each() -> void:
	duelist = Duelist.new("Tester", 100.0, 100.0)
	events = []
	duelist.damaged.connect(func (amount, absorbed): events.append("damaged %d/%d" % [amount, absorbed]))
	duelist.healed.connect(func (amount): events.append("healed %d" % [amount]))
	duelist.ward_ended.connect(func (broken): events.append("ward broken" if broken else "ward lapsed"))
	duelist.defeated.connect(func (): events.append("defeated"))


func test_a_duelist_starts_whole() -> void:
	assert_almost_eq(duelist.health, 100.0)
	assert_almost_eq(duelist.chi, 100.0)
	assert_false(duelist.is_warded())
	assert_false(duelist.is_defeated())
	var sturdy := Duelist.new("Sturdy", 140.0, 60.0)
	assert_almost_eq(sturdy.health, 140.0)
	assert_almost_eq(sturdy.chi, 60.0)


func test_damage_comes_off_health() -> void:
	assert_almost_eq(duelist.take_damage(30.0), 30.0)
	assert_almost_eq(duelist.health, 70.0)
	assert_eq(events, ["damaged 30/0"])


func test_no_damage_is_no_event() -> void:
	assert_almost_eq(duelist.take_damage(0.0), 0.0)
	assert_almost_eq(duelist.take_damage(-5.0), 0.0)
	assert_eq(events, [])
	assert_almost_eq(duelist.health, 100.0)


func test_a_ward_soaks_up_damage_first() -> void:
	duelist.raise_ward(20.0, 8.0)
	assert_almost_eq(duelist.take_damage(15.0), 0.0)
	assert_almost_eq(duelist.health, 100.0)
	assert_almost_eq(duelist.ward, 5.0)
	assert_eq(events, ["damaged 15/15"])


func test_damage_beyond_the_ward_gets_through_and_breaks_it() -> void:
	duelist.raise_ward(20.0, 8.0)
	assert_almost_eq(duelist.take_damage(50.0), 30.0)
	assert_almost_eq(duelist.health, 70.0)
	assert_false(duelist.is_warded())
	assert_eq(events, ["ward broken", "damaged 50/20"])


func test_many_small_blows_drain_a_ward_as_surely_as_one_great_one() -> void:
	duelist.raise_ward(20.0, 8.0)
	for i in 4:
		duelist.take_damage(5.0)
	assert_false(duelist.is_warded())
	assert_almost_eq(duelist.health, 100.0)
	assert_almost_eq(duelist.take_damage(5.0), 5.0)


func test_a_ward_lapses_with_time() -> void:
	duelist.raise_ward(20.0, 8.0)
	duelist.advance(7.9)
	assert_true(duelist.is_warded())
	duelist.advance(0.2)
	assert_false(duelist.is_warded())
	assert_eq(events, ["ward lapsed"])


func test_wards_do_not_stack() -> void:
	duelist.raise_ward(20.0, 8.0)
	duelist.advance(5.0)
	duelist.raise_ward(45.0, 10.0)
	assert_almost_eq(duelist.ward, 45.0, 0.0001, "the stronger ward replaces the weaker")
	assert_almost_eq(duelist.ward_seconds_left, 10.0)
	duelist.raise_ward(20.0, 8.0)
	assert_almost_eq(duelist.ward, 45.0, 0.0001, "a weaker ward is wasted")
	assert_almost_eq(duelist.ward_seconds_left, 10.0)


func test_recasting_a_worn_ward_renews_it() -> void:
	duelist.raise_ward(20.0, 8.0)
	duelist.take_damage(15.0)
	duelist.advance(6.0)
	duelist.raise_ward(20.0, 8.0)
	assert_almost_eq(duelist.ward, 20.0)
	assert_almost_eq(duelist.ward_seconds_left, 8.0)


func test_healing_stops_at_full_health() -> void:
	duelist.take_damage(10.0)
	assert_almost_eq(duelist.heal(25.0), 10.0)
	assert_almost_eq(duelist.health, 100.0)
	assert_almost_eq(duelist.heal(5.0), 0.0)


func test_falling_to_zero_is_defeat() -> void:
	duelist.take_damage(250.0)
	assert_almost_eq(duelist.health, 0.0)
	assert_true(duelist.is_defeated())
	assert_eq(events, ["damaged 250/0", "defeated"])


func test_the_defeated_are_left_alone() -> void:
	duelist.take_damage(100.0)
	events.clear()
	assert_almost_eq(duelist.take_damage(10.0), 0.0)
	assert_almost_eq(duelist.heal(10.0), 0.0)
	duelist.advance(5.0)
	assert_eq(events, [])
	assert_true(duelist.is_defeated())


func test_spells_are_paid_for_in_chi() -> void:
	var spell := Spell.new()
	spell.chi_cost = 30.0
	assert_true(duelist.can_afford(spell))
	assert_true(duelist.pay_for(spell))
	assert_almost_eq(duelist.chi, 70.0)
	duelist.pay_for(spell)
	duelist.pay_for(spell)
	assert_almost_eq(duelist.chi, 10.0)
	assert_false(duelist.can_afford(spell))
	assert_false(duelist.pay_for(spell))
	assert_almost_eq(duelist.chi, 10.0, 0.0001, "nothing is taken for a spell that can't be afforded")
	assert_false(duelist.can_afford(null))


func test_chi_comes_back_with_time() -> void:
	duelist.chi = 0.0
	duelist.advance(2.0)
	assert_almost_eq(duelist.chi, 2.0 * duelist.chi_per_second)
	duelist.advance(1000.0)
	assert_almost_eq(duelist.chi, duelist.max_chi, 0.0001, "and stops when full")


func test_changes_are_announced() -> void:
	var health := []
	var chi := []
	var ward := []
	duelist.health_changed.connect(func (now, _max): health.append(now))
	duelist.chi_changed.connect(func (now, _max): chi.append(now))
	duelist.ward_changed.connect(func (now): ward.append(now))
	duelist.raise_ward(10.0, 5.0)
	duelist.take_damage(25.0)
	duelist.chi -= 40.0
	assert_eq(health, [85.0])
	assert_eq(chi, [60.0])
	assert_eq(ward, [10.0, 0.0])
