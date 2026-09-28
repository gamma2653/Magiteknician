class_name Duelist
extends RefCounted
## One side of a duel: their health, their chi, and the ward around them.
##
## A duelist is state and rules with no node behind it. Time only passes
## when advance() is called, so a duel can be stepped through in a test, or
## replayed, and come out the same.

signal health_changed(health: float, max_health: float)
signal chi_changed(chi: float, max_chi: float)
signal ward_changed(ward: float)
## `amount` of damage arrived; `absorbed` of it was soaked up by the ward.
signal damaged(amount: float, absorbed: float)
signal healed(amount: float)
## The ward is gone. `broken` is true if damage used it up, false if it
## lapsed.
signal ward_ended(broken: bool)
## The cast the duelist was part-way through was broken from outside.
signal interrupted(spell: Spell)
## The duelist is chilled, or has just thawed. `precision` is what their
## tolerances are multiplied by: below 1 while chilled, 1 when not.
signal precision_changed(precision: float)
signal defeated

## However hard the chill, a duelist keeps this much of their tolerance.
const MIN_PRECISION := 0.3

## The name the player goes by, which takes "your" and not "'s".
const SECOND_PERSON := "You"

var display_name: String = ""
## The name as the owner of something: "Your" or "Femble's".
var possessive: String:
	get:
		if display_name == SECOND_PERSON:
			return "Your"
		return "%s's" % [display_name]
var max_health: float = 100.0
var health: float = 100.0:
	set(value):
		health = clampf(value, 0.0, max_health)
		health_changed.emit(health, max_health)

## Chi pays for spells. It comes back over time.
var max_chi: float = 100.0
var chi: float = 100.0:
	set(value):
		chi = clampf(value, 0.0, max_chi)
		chi_changed.emit(chi, max_chi)
## Chi regained each second.
var chi_per_second: float = 7.0

## Damage the ward can still soak up.
var ward: float = 0.0:
	set(value):
		ward = maxf(value, 0.0)
		ward_changed.emit(ward)
## Seconds until the ward lapses.
var ward_seconds_left: float = 0.0
## Share of what the ward soaks up that it turns back on the attacker.
var ward_reflect: float = 0.0

## How hard the duelist is chilled: the share taken off their tolerance.
var chill: float = 0.0
## Seconds until the chill wears off.
var chill_seconds_left: float = 0.0

## The spell the duelist is part-way through casting, if any. The duel
## keeps this up to date.
var casting: Spell

var spellbook: Spellbook = Spellbook.new()


func _init(name_: String = "", max_health_: float = 100.0, max_chi_: float = 100.0) -> void:
	display_name = name_
	max_health = max_health_
	max_chi = max_chi_
	health = max_health
	chi = max_chi


func is_defeated() -> bool:
	return health <= 0.0


func is_warded() -> bool:
	return ward > 0.0


func is_chilled() -> bool:
	return chill > 0.0


## What the duelist's timing tolerances are multiplied by: 1 normally,
## less while chilled.
func precision() -> float:
	return maxf(1.0 - chill, MIN_PRECISION)


func can_afford(spell: Spell) -> bool:
	return spell != null and chi >= spell.chi_cost


## Pays for `spell`. Returns false, and takes nothing, if there is not
## enough chi.
func pay_for(spell: Spell) -> bool:
	if not can_afford(spell):
		return false
	chi -= spell.chi_cost
	return true


## Deals `amount` of damage. The ward soaks up what it can; the rest comes
## off health. Returns how much got through.
func take_damage(amount: float) -> float:
	if amount <= 0.0 or is_defeated():
		return 0.0
	var absorbed := minf(ward, amount)
	if absorbed > 0.0:
		ward -= absorbed
		if ward <= 0.0:
			_end_ward(true)
	var through := amount - absorbed
	if through > 0.0:
		health -= through
	damaged.emit(amount, absorbed)
	if is_defeated():
		defeated.emit()
	return through


## Restores up to `amount` of health. Returns how much was restored.
func heal(amount: float) -> float:
	if amount <= 0.0 or is_defeated():
		return 0.0
	var restored := minf(amount, max_health - health)
	health += restored
	healed.emit(restored)
	return restored


## Raises a ward that soaks up `amount` of damage for `seconds`.
## Wards do not stack: a new ward replaces a weaker one and renews the time
## left on it, and is wasted on a stronger one. Returns true if the ward
## was raised.
func raise_ward(amount: float, seconds: float) -> bool:
	if amount <= 0.0 or seconds <= 0.0 or amount < ward:
		return false
	ward_reflect = 0.0
	ward = amount
	ward_seconds_left = seconds
	return true


## Wears the ward down by up to `amount`, leaving health alone. Returns
## how much of the ward was taken.
func batter(amount: float) -> float:
	if amount <= 0.0 or not is_warded() or is_defeated():
		return 0.0
	var taken := minf(ward, amount)
	ward -= taken
	if ward <= 0.0:
		_end_ward(true)
	return taken


## Makes the ward turn back `share` of what it soaks up. Returns false if
## there is no ward to do it.
func make_ward_reflect(share: float) -> bool:
	if not is_warded() or share <= 0.0:
		return false
	ward_reflect = clampf(share, 0.0, 1.0)
	return true


## Breaks the cast in progress. Returns the spell that was broken, or null
## if a ward kept the interruption out or there was nothing to break.
func interrupt() -> Spell:
	if is_warded() or is_defeated() or casting == null:
		return null
	var broken := casting
	casting = null
	interrupted.emit(broken)
	return broken


## Chills the duelist for `seconds`. A harder chill replaces a milder one;
## a milder one only renews the time left.
func apply_chill(strength: float, seconds: float) -> void:
	if strength <= 0.0 or seconds <= 0.0 or is_defeated():
		return
	chill = maxf(chill, clampf(strength, 0.0, 1.0))
	chill_seconds_left = maxf(chill_seconds_left, seconds)
	precision_changed.emit(precision())


## Lets `seconds` pass: chi comes back and the ward runs down.
func advance(seconds: float) -> void:
	if seconds <= 0.0 or is_defeated():
		return
	if chi < max_chi:
		chi += chi_per_second * seconds
	if is_warded():
		ward_seconds_left -= seconds
		if ward_seconds_left <= 0.0:
			ward = 0.0
			_end_ward(false)
	if is_chilled():
		chill_seconds_left -= seconds
		if chill_seconds_left <= 0.0:
			chill = 0.0
			chill_seconds_left = 0.0
			precision_changed.emit(precision())


## What is wrong with the duelist just now, in a few words, or "".
func status_text() -> String:
	var parts: PackedStringArray = []
	if is_warded():
		var line := "Warded %.0fs" % [ceilf(ward_seconds_left)]
		if ward_reflect > 0.0:
			line += ", turning back %d%%" % [roundi(ward_reflect * 100.0)]
		parts.append(line)
	if is_chilled():
		parts.append("Chilled %.0fs" % [ceilf(chill_seconds_left)])
	return " · ".join(parts)


func _end_ward(broken: bool) -> void:
	ward_seconds_left = 0.0
	ward_reflect = 0.0
	ward_ended.emit(broken)


## Everything about the duelist that changes in a duel, as plain numbers.
func to_dict() -> Dictionary:
	return {
		"name": display_name,
		"health": health,
		"max_health": max_health,
		"chi": chi,
		"max_chi": max_chi,
		"ward": ward,
		"ward_seconds_left": ward_seconds_left,
		"ward_reflect": ward_reflect,
		"chill": chill,
		"chill_seconds_left": chill_seconds_left,
		"casting": String(casting.id) if casting != null else "",
	}


## Sets the duelist from a dictionary made by to_dict() on another machine.
## Parts that are missing are left as they were. The signals that would
## have been emitted by getting here step by step are emitted once.
func apply_dict(data: Dictionary) -> void:
	var was_defeated := is_defeated()
	var precision_before := precision()
	display_name = str(data.get("name", display_name))
	max_health = float(data.get("max_health", max_health))
	max_chi = float(data.get("max_chi", max_chi))
	var health_before := health
	health = float(data.get("health", health))
	chi = float(data.get("chi", chi))
	ward_seconds_left = float(data.get("ward_seconds_left", ward_seconds_left))
	ward_reflect = float(data.get("ward_reflect", ward_reflect))
	ward = float(data.get("ward", ward))
	chill = clampf(float(data.get("chill", chill)), 0.0, 1.0)
	chill_seconds_left = float(data.get("chill_seconds_left", chill_seconds_left))
	var casting_id := str(data.get("casting", ""))
	casting = null if casting_id.is_empty() else SpellLibrary.find(StringName(casting_id))
	if health < health_before:
		damaged.emit(health_before - health, 0.0)
	if not is_equal_approx(precision(), precision_before):
		precision_changed.emit(precision())
	if is_defeated() and not was_defeated:
		defeated.emit()


func _to_string() -> String:
	return "<%s %d/%d health, %d chi, ward %d>" % [
		display_name, roundi(health), roundi(max_health), roundi(chi), roundi(ward)
	]
