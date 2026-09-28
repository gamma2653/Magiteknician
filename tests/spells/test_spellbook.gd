extends TestCase
## SpellLibrary and Spellbook.


func test_the_library_finds_spells_by_id() -> void:
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	assert_not_null(fire_bolt)
	assert_eq(fire_bolt.display_name, "Fire Bolt")
	assert_true(SpellLibrary.has_spell(&"ward"))
	assert_null(SpellLibrary.find(&"no_such_spell"))
	assert_false(SpellLibrary.has_spell(&"no_such_spell"))


func test_the_library_lists_spells_easiest_rank_first() -> void:
	var spells := SpellLibrary.all()
	assert_gt(spells.size(), 0)
	for i in range(1, spells.size()):
		assert_true(spells[i - 1].rank <= spells[i].rank, "%s before %s" % [spells[i - 1].id, spells[i].id])
		if spells[i - 1].rank == spells[i].rank:
			assert_true(spells[i - 1].display_name < spells[i].display_name)


func test_the_library_hands_out_the_same_spell_each_time() -> void:
	assert_eq(SpellLibrary.find(&"spark"), SpellLibrary.find(&"spark"))
	assert_eq(SpellLibrary.find(&"spark"), load("res://magiteknician/spells/spark.tres"))


func test_a_book_keeps_its_spells_in_order() -> void:
	var book := Spellbook.of([&"ward", &"spark", &"mend"])
	assert_eq(book.ids(), [&"ward", &"spark", &"mend"])
	assert_true(book.knows(&"spark"))
	assert_false(book.knows(&"lightning"))
	assert_eq(book.find(&"mend"), SpellLibrary.find(&"mend"))
	assert_null(book.find(&"lightning"))


func test_a_spell_is_learned_once() -> void:
	var book := Spellbook.new()
	var changes := []
	book.changed.connect(func (): changes.append(true))
	assert_true(book.learn(SpellLibrary.find(&"spark")))
	assert_false(book.learn(SpellLibrary.find(&"spark")), "already known")
	assert_false(book.learn(null))
	assert_eq(book.spells.size(), 1)
	assert_eq(changes.size(), 1, "the book announces the one change")


func test_unknown_ids_are_skipped() -> void:
	allow_errors = true
	var book := Spellbook.of([&"spark", &"no_such_spell", &"ward"])
	assert_eq(book.ids(), [&"spark", &"ward"])


func test_the_complete_book_holds_the_whole_library() -> void:
	assert_eq(Spellbook.complete().spells, SpellLibrary.all())
