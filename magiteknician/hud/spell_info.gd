class_name SpellInfo
extends PanelContainer
## Names the spell on the circle and says what it is made of.

const NO_SPELL := "No spell chosen"

@onready var title: Label = %Title
@onready var lineage: Label = %Lineage
@onready var formula: Label = %Formula
@onready var effect: Label = %Effect
@onready var description: Label = %Description


func _ready() -> void:
	show_spell(null)


func show_spell(spell: Spell) -> void:
	if spell == null:
		title.text = NO_SPELL
		lineage.text = ""
		formula.text = ""
		effect.text = ""
		description.text = ""
		return
	title.text = spell.display_name
	lineage.text = "%s · %s" % [Spell.RANK_NAMES[spell.rank], Spell.SCHOOL_NAMES[spell.school]]
	formula.text = "%s   (%d strokes over %d ticks)" % [spell.formula(), spell.strokes.size(), spell.span_ticks()]
	effect.text = effect_text(spell)
	description.text = spell.description


## What the spell does and what it costs, e.g. "16 damage · 16 chi".
static func effect_text(spell: Spell) -> String:
	var parts: PackedStringArray = []
	if not spell.effects.is_empty():
		parts.append(spell.describe_effects())
	if spell.chi_cost > 0.0:
		parts.append(cost_text(spell))
	return " · ".join(parts)


## What the spell costs, e.g. "16 chi".
static func cost_text(spell: Spell) -> String:
	return "%s chi" % [String.num(spell.chi_cost, 1).trim_suffix(".0")]
