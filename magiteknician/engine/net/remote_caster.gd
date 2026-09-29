class_name RemoteCaster
extends Caster
## Casts for a player on another machine, from the messages they send.
##
## Each stroke that arrives is put through this machine's own spell circle,
## stamped with the time its sender gave it. The circle then judges the
## cast as it would any other. Nothing the sender says about how well they
## cast is taken on trust, because they are never asked.

## A message arrived that could not be acted on.
signal rejected(contents: Variant, reasons: PackedStringArray)
## The cast in progress came to nothing on this side: it was broken by an
## interruption, or refused for want of chi. The sender has to be told.
signal cast_lost(spell: Spell, refused: bool)

## The spell being cast, or null between casts.
var spell: Spell
## How many messages have been rejected since the caster began.
var rejections: int = 0

var _running: bool = false
# When the cast in progress began, by this machine's clock. Offsets in the
# messages are added to it.
var _began_usec: int = 0
var _last_offset_usec: int = -1
var _landed: int = 0
# When the cast before this one began, by this machine's clock, or -1 if
# there was none.
var _began_before_usec: int = -1


func begin() -> void:
	_running = true


func halt() -> void:
	_running = false
	_drop_cast()


func interrupt() -> bool:
	if spell == null:
		return false
	var lost := spell
	_drop_cast()
	cast_lost.emit(lost, false)
	return true


## Takes a message from the other machine. `arrival_usec` is when it
## arrived, by this machine's clock.
func receive(contents: Variant, arrival_usec: int = Time.get_ticks_usec()) -> void:
	var reasons := DuelProtocol.problems(contents)
	if reasons.is_empty():
		reasons = _problems_now(contents, arrival_usec)
	if not reasons.is_empty():
		_reject(contents, reasons)
		return

	match contents[DuelProtocol.TYPE]:
		DuelProtocol.BEGIN:
			_drop_cast()
			spell = SpellLibrary.find(StringName(contents["spell"]))
			circle.prepare(spell)
			_began_usec = arrival_usec
			_last_offset_usec = -1
			_landed = 0
		DuelProtocol.STROKE:
			_strike(contents)
		DuelProtocol.ABANDON:
			_drop_cast()


# What is wrong with a well-formed message given where the cast has got to.
func _problems_now(contents: Dictionary, arrival_usec: int) -> PackedStringArray:
	var found: PackedStringArray = []
	var type: String = contents[DuelProtocol.TYPE]
	if type not in [DuelProtocol.BEGIN, DuelProtocol.STROKE, DuelProtocol.ABANDON]:
		found.append("A '%s' is for the host to send, not to receive." % [type])
		return found
	if not _running:
		found.append("The duel is not under way.")
		return found
	match type:
		DuelProtocol.BEGIN:
			if me != null and not me.spellbook.knows(StringName(contents["spell"])):
				found.append("The caster does not know '%s'." % [contents["spell"]])
		DuelProtocol.STROKE:
			if spell == null:
				found.append("A stroke arrived with no cast in progress.")
				return found
			var offset := int(contents["t"])
			if _landed > 0 and offset < _last_offset_usec:
				found.append("The stroke is stamped earlier than the one before it.")
			# By its own account the cast has run for `offset`. It cannot
			# have run for longer than it has been since it began here.
			if offset > arrival_usec - _began_usec + DuelProtocol.ARRIVAL_SLACK_USEC:
				found.append("The stroke is stamped later than it could have been made.")
	return found


func _strike(contents: Dictionary) -> void:
	var rune := int(contents["rune"]) as Rune.Type
	var location := Vector2(float(contents["x"]), float(contents["y"]))
	var offset := int(contents["t"])
	var on_target := circle.expected.current_rune != null \
		and circle.expected.current_rune.rune_type == rune \
		and circle.expected.current_rune.contains(location)
	if on_target and _landed > 0 and offset - _last_offset_usec < DuelProtocol.MIN_STROKE_GAP_USEC:
		_reject(contents, PackedStringArray(["The stroke follows the last too closely to have been made by hand."]))
		return

	if _landed == 0 and on_target:
		_take_the_senders_word(contents)
	var outcome := circle.strike(rune, location, _began_usec + offset)
	match outcome:
		SpellCircle.Outcome.HIT:
			if _landed == 0:
				_began_before_usec = _began_usec
			_landed += 1
			_last_offset_usec = offset
			if circle.state != SpellCircle.State.CASTING:
				# That was the last rune. The circle has judged the cast.
				spell = null
		SpellCircle.Outcome.REFUSED:
			var lost := spell
			_drop_cast()
			cast_lost.emit(lost, true)


# A cast is taken to have begun when word of it arrived. If the sender
# says how long it was after their last cast, and that is near enough to
# how long it was in arriving, it is taken to have begun when they say.
# The two differ by however much the network held one up and not the
# other, which is what would put a cast off the beat that was on it.
func _take_the_senders_word(contents: Dictionary) -> void:
	if _began_before_usec < 0 or not contents.has("since"):
		return
	var by_their_account := _began_before_usec + int(contents["since"])
	if absi(by_their_account - _began_usec) <= DuelProtocol.ARRIVAL_SLACK_USEC:
		_began_usec = by_their_account


func _reject(contents: Variant, reasons: PackedStringArray) -> void:
	rejections += 1
	rejected.emit(contents, reasons)
	# A cast with a stroke missing from it cannot be finished. The sender
	# believes the stroke landed, so they have to be told the cast is lost.
	var was_a_stroke: bool = contents is Dictionary and contents.get(DuelProtocol.TYPE) == DuelProtocol.STROKE
	if was_a_stroke and spell != null:
		var lost := spell
		_drop_cast()
		cast_lost.emit(lost, false)


func _drop_cast() -> void:
	if spell == null:
		return
	spell = null
	if circle != null:
		circle.abandon()
