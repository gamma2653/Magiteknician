class_name SpellInfo
extends PanelContainer
## Names the spell on the circle and says what it is made of.

const NO_SPELL := "No spell chosen"

@onready var title: Label = %Title
@onready var lineage: Label = %Lineage
@onready var formula: Label = %Formula
@onready var description: Label = %Description


func _ready() -> void:
	show_spell(null)


func show_spell(spell: Spell) -> void:
	if spell == null:
		title.text = NO_SPELL
		lineage.text = ""
		formula.text = ""
		description.text = ""
		return
	title.text = spell.display_name
	lineage.text = "%s · %s" % [Spell.RANK_NAMES[spell.rank], Spell.SCHOOL_NAMES[spell.school]]
	formula.text = "%s   (%d strokes over %d ticks)" % [spell.formula(), spell.strokes.size(), spell.span_ticks()]
	description.text = spell.description
