class_name DuelHud
extends CanvasLayer
## Everything a duel shows that is not a spell circle: the two duelists,
## the spell bar, the combat log and the card over the top.
##
## It is the same whoever the opponent is. The arena for a duel against an
## NPC and the one for a duel against another player both put one of
## these over their circles.

## The player chose a spell from the bar.
signal spell_chosen(spell: Spell)
## A fade, in or out, has run its course.
signal fade_finished

const ESCALATION_LINE := "The duel escalates: every blow lands harder from here."

@onready var player_panel: DuelistPanel = %PlayerPanel
@onready var opponent_panel: DuelistPanel = %OpponentPanel
@onready var opponent_spell: Label = %OpponentSpell
@onready var chosen_spell: Label = %ChosenSpell
@onready var combat_log: CombatLog = %CombatLog
@onready var spell_bar: SpellBar = %SpellBar
@onready var overlay: DuelOverlay = %Overlay
@onready var fade: ColorRect = %FadeTransition


func _ready() -> void:
	spell_bar.show_costs = true
	spell_bar.spell_chosen.connect(_on_spell_chosen)
	fade.timeout.connect(func (): fade_finished.emit())


## Shows `player` and `opponent`, and offers the player's spells.
func show_duelists(player: Duelist, opponent: Duelist, opponent_subtitle: String = "") -> void:
	player_panel.bind(player)
	opponent_panel.bind(opponent, opponent_subtitle)
	spell_bar.spellbook = player.spellbook
	player.chi_changed.connect(func (chi, _max): spell_bar.show_affordable(chi))
	player.interrupted.connect(func (spell): add_line("Your %s was broken." % [spell.display_name]))


## Adds a line to the combat log.
func add_line(line: String) -> void:
	combat_log.add(line)


## Says that the player has not the chi for `spell`.
func refuse(spell: Spell) -> void:
	player_panel.flash_chi()
	add_line("Not enough chi for %s." % [spell.display_name])


## Names the spell the opponent is casting. Null clears the name.
func name_opponent_spell(spell: Spell) -> void:
	opponent_spell.text = spell.display_name if spell != null else ""


func fade_in() -> void:
	fade.end_transition()


func fade_out() -> void:
	fade.start_transition()


func _on_spell_chosen(spell: Spell) -> void:
	chosen_spell.text = "%s\n%s" % [spell.display_name, spell.describe_effects()]
	spell_chosen.emit(spell)
