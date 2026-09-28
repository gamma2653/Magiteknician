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
signal defeated

var display_name: String = ""
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
## left on it, and is wasted on a stronger one.
func raise_ward(amount: float, seconds: float) -> void:
	if amount <= 0.0 or seconds <= 0.0:
		return
	if amount >= ward:
		ward = amount
		ward_seconds_left = seconds


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


func _end_ward(broken: bool) -> void:
	ward_seconds_left = 0.0
	ward_ended.emit(broken)


func _to_string() -> String:
	return "<%s %d/%d health, %d chi, ward %d>" % [
		display_name, roundi(health), roundi(max_health), roundi(chi), roundi(ward)
	]
