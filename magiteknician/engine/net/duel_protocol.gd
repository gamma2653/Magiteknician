class_name DuelProtocol
extends RefCounted
## The messages two machines exchange to fight a duel, and the checks made
## on them when they arrive.
##
## Messages are dictionaries holding nothing but numbers, strings and
## booleans, so that any transport can carry them and they survive JSON.
## Spells are named by id.
##
## What goes over the wire is strokes, not verdicts. Each side sends where
## and when its strokes landed, by its own clock, and the other side puts
## them through a spell circle of its own. Two things follow. The
## opponent's spell can be watched as it takes shape. And because a cast
## is judged on its rhythm at whatever tempo and from whatever starting
## time, the delay of the network cannot spoil it: a stroke that arrives
## late was still struck when its sender says it was.

## Bumped when a message changes shape. Peers with different versions
## should not duel.
const VERSION := 1

const TYPE := "type"

## Before the duel: who I am, and which version of the game I have.
const HELLO := "hello"
## From the host, before the duel: both players' names as the duel will
## have them. Both sides go to the arena.
const START := "start"
## From the host: the duel is under way.
const GO := "go"
## A cast has begun. Carries the spell's id.
const BEGIN := "begin"
## A stroke was made, on target or not.
const STROKE := "stroke"
## The cast in progress was given up.
const ABANDON := "abandon"
## From the host: the state of both duelists.
const SNAPSHOT := "snapshot"
## From the host: a cast took effect. Carries a line for the combat log,
## and what the cast did, for it to be shown. A host from before spells
## were shown sends the line alone, and that is still a message.
const RESOLVED := "resolved"
## From the host: the receiver's cast was broken or refused.
const BROKEN := "broken"
## From the host: the duel is over.
const FINISHED := "finished"
## After the duel, from either: I would fight it again. When both have
## said so, both go back to the beginning.
const REMATCH := "rematch"

## Names are cut to this many characters.
const MAX_NAME_LENGTH := 16

## Strokes closer together than this, in microseconds, were not made by a
## hand.
const MIN_STROKE_GAP_USEC := 15_000
## A cast cannot have taken longer by its own account than it took to
## arrive, give or take this much, in microseconds.
const ARRIVAL_SLACK_USEC := 750_000


## `spells` are the ids of the spells the player brings. A player from
## before there were loadouts says nothing of them, and brings them all.
##
## The greeting also says which spells the sender's game has, so that
## neither player brings a spell the other's game has never heard of. Two
## versions of the game with different spells can still duel, with the
## spells they share.
static func hello(player_name: String, spells: Array = []) -> Dictionary:
	var message := {TYPE: HELLO, "version": VERSION, "name": tidy_name(player_name)}
	if not spells.is_empty():
		message["spells"] = spells.map(func (id): return String(id))
	message["library"] = Loadout.every_spell().map(func (id): return String(id))
	return message


## The spells that the sender of `greeting` and this game both have.
static func spells_in_common(greeting: Dictionary) -> Array[StringName]:
	var theirs: Variant = greeting.get("library")
	if theirs is not Array:
		theirs = Loadout.LEGACY
	return Loadout.in_common(Loadout.every_spell(), theirs)


## `host_spells` and `guest_spells` are what each brings, as the duel will
## have it.
static func start(host_name: String, guest_name: String, host_spells: Array = [], guest_spells: Array = []) -> Dictionary:
	var message := {TYPE: START, "host": host_name, "guest": guest_name}
	if not host_spells.is_empty():
		message["host_spells"] = host_spells.map(func (id): return String(id))
	if not guest_spells.is_empty():
		message["guest_spells"] = guest_spells.map(func (id): return String(id))
	return message


## The spells a message says are brought, under `field`, made fit to
## bring. Empty if it says nothing of them.
static func spells_in(message: Dictionary, field: String = "spells") -> Array[StringName]:
	var said: Variant = message.get(field)
	if said is not Array or said.is_empty():
		return []
	# Of the spells this game has. One it has not is left out, and not
	# refused: it is a spell from a version this one has not caught up with.
	return Loadout.in_common(Loadout.tidy(said, said), Loadout.every_spell())


static func go() -> Dictionary:
	return {TYPE: GO}


## `name` made fit to show: trimmed, cut to length, and never empty.
static func tidy_name(player_name: String, fallback: String = "Caster") -> String:
	var tidy := player_name.strip_edges().replace("\n", " ").left(MAX_NAME_LENGTH).strip_edges()
	return fallback if tidy.is_empty() else tidy


## The names two players will have in a duel. They have to differ, since
## the combat log tells the players apart by name.
static func names_for_duel(host_name: String, guest_name: String) -> Array[String]:
	var host := tidy_name(host_name, "Host")
	var guest := tidy_name(guest_name, "Guest")
	if host == guest:
		guest = "%s II" % [guest.left(MAX_NAME_LENGTH - 3).strip_edges()]
	return [host, guest]


static func begin(spell: Spell) -> Dictionary:
	return {TYPE: BEGIN, "spell": String(spell.id)}


## A stroke of `rune` at `location` on the circle, `offset_usec` after the
## first stroke of the cast.
##
## The first stroke of a cast can say how long it was after the first
## stroke of the sender's last cast, in `since_usec`. That is what lets a
## cast be judged to follow the one before it: the casts reach the other
## machine as far apart as the network made them, and were made as far
## apart as the sender says.
static func stroke(rune: Rune.Type, location: Vector2, offset_usec: int, since_usec: int = -1) -> Dictionary:
	var message := {TYPE: STROKE, "rune": int(rune), "x": location.x, "y": location.y, "t": offset_usec}
	if since_usec >= 0:
		message["since"] = since_usec
	return message


static func abandon() -> Dictionary:
	return {TYPE: ABANDON}


## The state of a duel, from the host's side. `elapsed` is in seconds.
static func snapshot(host: Duelist, guest: Duelist, elapsed: float) -> Dictionary:
	return {TYPE: SNAPSHOT, "host": host.to_dict(), "guest": guest.to_dict(), "elapsed": elapsed}


static func resolved(outcome: SpellOutcome, by_host: bool) -> Dictionary:
	var message := outcome.to_dict()
	message[TYPE] = RESOLVED
	message["by_host"] = by_host
	message["line"] = outcome.describe()
	return message


## The receiver's cast of `spell` came to nothing. `refused` is true if it
## could not be afforded, false if it was broken by the other side.
static func broken(spell: Spell, refused: bool) -> Dictionary:
	return {TYPE: BROKEN, "spell": String(spell.id) if spell != null else "", "refused": refused}


static func finished(host_won: bool) -> Dictionary:
	return {TYPE: FINISHED, "host_won": host_won}


static func rematch() -> Dictionary:
	return {TYPE: REMATCH}


## Everything wrong with `message` as it arrived. Empty when it is fit to
## act on. This checks the shape of the message and nothing about whether
## it makes sense at this point in the duel.
static func problems(message: Variant) -> PackedStringArray:
	var found: PackedStringArray = []
	if message is not Dictionary:
		found.append("The message is not a dictionary.")
		return found
	var type: Variant = message.get(TYPE)
	if type is not String:
		found.append("The message does not say what type it is.")
		return found
	match type:
		HELLO:
			if not _is_number(message.get("version")):
				found.append("The greeting does not say which version it is from.")
			if message.get("name") is not String:
				found.append("The greeting has no name in it.")
			if message.has("spells") and not _are_spells(message["spells"]):
				found.append("The greeting does not say properly which spells are brought.")
		START:
			for side in ["host", "guest"]:
				if message.get(side) is not String or String(message.get(side, "")).is_empty():
					found.append("The start does not name the %s." % [side])
				if message.has(side + "_spells") and not _are_spells(message[side + "_spells"]):
					found.append("The start does not say properly which spells the %s brings." % [side])
		GO:
			pass
		BEGIN:
			if message.get("spell") is not String:
				found.append("A cast began without naming its spell.")
			elif not SpellLibrary.has_spell(StringName(message["spell"])):
				found.append("There is no spell with the id '%s'." % [message["spell"]])
		STROKE:
			for field in ["rune", "x", "y", "t"]:
				if not _is_number(message.get(field)):
					found.append("The stroke's '%s' is not a number." % [field])
			if found.is_empty():
				if int(message["rune"]) not in Rune.Type.values():
					found.append("There is no rune numbered %d." % [int(message["rune"])])
				if int(message["t"]) < 0:
					found.append("The stroke was made before its cast began.")
				if not (is_finite(float(message["x"])) and is_finite(float(message["y"]))):
					found.append("The stroke did not land anywhere.")
				if message.has("since") and (not _is_number(message["since"]) or float(message["since"]) < 0.0):
					found.append("The stroke does not say properly how long it was after the last cast.")
		ABANDON:
			pass
		SNAPSHOT:
			for side in ["host", "guest"]:
				if message.get(side) is not Dictionary:
					found.append("The snapshot has no %s." % [side])
			if not _is_number(message.get("elapsed")):
				found.append("The snapshot does not say how long the duel has run.")
		RESOLVED:
			if message.get("by_host") is not bool:
				found.append("The outcome does not say whose cast it was.")
			if message.get("line") is not String:
				found.append("The outcome has no description.")
			if message.has("entries"):
				# It says what the cast did, and has to say it properly.
				if message.get("spell") is not String:
					found.append("The outcome does not name its spell.")
				elif not SpellLibrary.has_spell(StringName(message["spell"])):
					found.append("There is no spell with the id '%s'." % [message["spell"]])
				for field in ["grade", "quality", "potency"]:
					if not _is_number(message.get(field)):
						found.append("The outcome's '%s' is not a number." % [field])
				if message["entries"] is not Array:
					found.append("What the cast did is not a list.")
				else:
					for entry: Variant in message["entries"]:
						if entry is not Dictionary or not _is_number(entry.get("kind")) \
								or int(entry["kind"]) not in SpellEffect.Kind.values():
							found.append("The outcome has an effect of no known kind.")
							break
		BROKEN:
			if message.get("refused") is not bool:
				found.append("The message does not say whether the cast was refused or broken.")
		FINISHED:
			if message.get("host_won") is not bool:
				found.append("The message does not say who won.")
		REMATCH:
			pass
		_:
			found.append("There is no message of type '%s'." % [type])
	return found


## `line`, which the host wrote with the casters' names in it, as it
## should read to the player called `name`: "Gil cast Spark" becomes
## "You cast Spark", and "Gil's Spark fizzled" becomes "Your Spark fizzled".
static func in_second_person(line: String, name: String) -> String:
	if name.is_empty():
		return line
	if line.begins_with("%s's " % [name]):
		return "Your " + line.trim_prefix("%s's " % [name])
	if line.begins_with("%s cast " % [name]):
		return "You cast " + line.trim_prefix("%s cast " % [name])
	return line


## Passes `message` through JSON and back, as a transport would.
static func through_json(message: Dictionary) -> Variant:
	return JSON.parse_string(JSON.stringify(message))


# True if `value` is a list of the ids of spells, and no more of them
# than can be brought. They need not be spells this game has.
static func _are_spells(value: Variant) -> bool:
	if value is not Array or value.size() > Loadout.SIZE:
		return false
	for id: Variant in value:
		if id is not String or String(id).is_empty():
			return false
	return true


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
