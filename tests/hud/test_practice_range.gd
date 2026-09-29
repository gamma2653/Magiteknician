extends TestCase
## The practice range, its result panel and its raster.

const RANGE := preload("res://magiteknician/levels/practice_range.tscn")
const BEAT := 250_000

var practice: Node


func before_each() -> void:
	practice = add_managed(RANGE.instantiate())


func _cast(nudges_in_ticks: Array = [], strays: int = 0) -> CastResult:
	var circle: SpellCircle = practice.circle
	var spell := circle.spell
	for i in spell.strokes.size():
		var stroke := spell.strokes[i]
		var nudge: float = nudges_in_ticks[i] if i < nudges_in_ticks.size() else 0.0
		circle.strike(stroke.rune, stroke.position, 2_000_000 + int((stroke.tick + nudge) * BEAT))
		if i == 0:
			for stray in strays:
				circle.strike(stroke.rune, Vector2(9999, 9999), 2_000_000)
	return circle.last_result


func test_the_range_opens_with_the_first_spell_laid_out() -> void:
	var first: Spell = practice.spellbook.spells[0]
	assert_eq(practice.circle.spell, first)
	assert_eq(practice.circle.state, SpellCircle.State.READY)
	assert_eq(practice.spell_info.title.text, first.display_name)
	assert_true(first.formula() in practice.spell_info.formula.text)
	assert_eq(practice.spell_info.description.text, first.description)


func test_the_range_offers_every_spell() -> void:
	assert_eq(practice.spellbook.spells, SpellLibrary.all())
	assert_eq(practice.spell_bar.spell_count(), SpellLibrary.all().size())
	assert_gt(practice.spell_bar.page_count(), 1, "a page at a time, there being more of them than keys")


func test_choosing_a_spell_lays_it_out() -> void:
	practice.spell_bar.choose(2)
	var spell: Spell = practice.spellbook.spells[2]
	assert_eq(practice.circle.spell, spell)
	assert_eq(practice.circle.expected.bound_runes.size(), spell.strokes.size())
	assert_eq(practice.spell_info.title.text, spell.display_name)
	assert_true(Spell.SCHOOL_NAMES[spell.school] in practice.spell_info.lineage.text)


func test_a_cast_is_reported_on_the_panel() -> void:
	var panel: ResultPanel = practice.result_panel
	assert_eq(panel.summary.text, ResultPanel.NOTHING_YET)
	var result := _cast()
	assert_eq(panel.grade.text, "S")
	assert_eq(panel.summary.text, ResultPanel.summary_text(result))
	assert_true("100%" in panel.summary.text)
	assert_true("240 ticks a minute" in panel.tempo.text)
	assert_true("Perfect %d" % [result.stroke_count] in panel.judgements.text)


func test_choosing_another_spell_clears_the_panel() -> void:
	_cast()
	practice.spell_bar.choose(1)
	assert_eq(practice.result_panel.summary.text, ResultPanel.NOTHING_YET)
	assert_eq(practice.result_panel.tempo.text, "")


func test_a_fizzle_is_called_a_fizzle() -> void:
	var result := _cast([], 20)
	assert_true(result.fizzled)
	assert_eq(practice.result_panel.grade.text, "Fizzle")
	assert_true("fizzled" in practice.result_panel.summary.text)
	assert_true("Stray 20" in practice.result_panel.judgements.text)


func test_short_spells_say_their_rhythm_was_not_judged() -> void:
	var result := CastScorer.score([0, 1], [0, 300_000])
	assert_true("Too few strokes" in ResultPanel.judgements_text(result))


func test_the_raster_puts_late_strokes_to_the_right() -> void:
	var raster: CastRaster = practice.result_panel.raster
	raster.size = Vector2(400, 80)
	practice.spell_bar.choose_spell(SpellLibrary.find(&"fire_bolt"))
	var spell: Spell = practice.circle.spell
	var result := _cast([0.0, 0.0, 0.3, 0.0, 0.0])
	raster.size = Vector2(400, 80)
	var ticks := spell.ticks()
	assert_gt(result.deviations[2], 0.0)
	assert_gt(raster.x_of(ticks[2] + result.deviations[2]), raster.x_of(ticks[2]))
	assert_lt(raster.x_of(ticks[0]), raster.x_of(ticks[-1]))
	assert_between(raster.x_of(ticks[0]), 0.0, 400.0)
	assert_between(raster.x_of(ticks[-1]), 0.0, 400.0)


func test_back_returns_to_the_main_menu() -> void:
	practice._on_back_pressed()
	assert_false(practice.circle.accepts_input, "no casting on the way out")
	assert_true(practice._leaving)
