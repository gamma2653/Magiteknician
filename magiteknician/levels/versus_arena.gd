extends Transitionable
## Where duels between two players are fought. It looks like the arena
## for duels against NPCs, and it is one of two machines showing the same
## duel: the host, which runs it, or the guest, which is told how it goes.

## Seconds between the arena opening and the duel beginning.
const COUNTDOWN_SECONDS := 3.0

@onready var player_circle: SpellCircle = $PlayerCircle
@onready var opponent_circle: SpellCircle = $OpponentCircle
@onready var spell_show: SpellShow = $SpellShow
@onready var hud: DuelHud = $HUD

## What carries the messages. The game's own link unless a test says
## otherwise.
var link: Node
## One of these two is made, according to which side this machine is.
var host: DuelHost
var guest: DuelGuest

var me: Duelist
var foe: Duelist
var is_over: bool = false

var _countdown: float = COUNTDOWN_SECONDS
var _begun: bool = false
var _said_escalated: bool = false
var _destination: String = ""


func _ready() -> void:
	if link == null:
		link = Net
	me = Duelist.new(DuelProtocol.tidy_name(Session.versus_name, "Host" if Session.versus_is_host else "Guest"))
	me.spellbook = _book_of(Session.versus_spells if not Session.versus_spells.is_empty() else Settings.versus_spells)
	foe = Duelist.new(DuelProtocol.tidy_name(Session.versus_foe_name, "Guest" if Session.versus_is_host else "Host"))
	foe.spellbook = _book_of(Session.versus_foe_spells)

	if Session.versus_is_host:
		_set_up_as_host()
	else:
		_set_up_as_guest()

	spell_show.place(me, player_circle)
	spell_show.place(foe, opponent_circle)

	link.received.connect(_on_received)
	link.peer_left.connect(_on_peer_left)

	hud.spell_chosen.connect(player_circle.prepare)
	hud.fade_finished.connect(_on_fade_transition_timeout)
	hud.show_duelists(me, foe)
	hud.spell_bar.choose(0)
	hud.overlay.declined.connect(leave)
	opponent_circle.prepared.connect(hud.name_opponent_spell)
	opponent_circle.cast_finished.connect(func (_spell, _result): hud.name_opponent_spell(null))
	opponent_circle.cast_abandoned.connect(func (_spell): hud.name_opponent_spell(null))
	player_circle.cast_refused.connect(hud.refuse)
	_show_countdown()
	hud.fade_in()


# The spells with these ids, or every spell if there are none: a player
# from before there were loadouts does not say what they bring.
func _book_of(ids: Array[StringName]) -> Spellbook:
	if ids.is_empty():
		return Spellbook.complete()
	return Spellbook.of(ids)


func _exit_tree() -> void:
	link.received.disconnect(_on_received)
	link.peer_left.disconnect(_on_peer_left)


func _set_up_as_host() -> void:
	host = DuelHost.new()
	host.name = "Host"
	add_child(host)
	# The arena feeds the host its time, so that nothing happens during
	# the countdown.
	host.set_process(false)
	host.setup(me, foe, player_circle, opponent_circle)
	host.outgoing.connect(link.send)
	host.duel.spell_resolved.connect(func (outcome):
		hud.add_line(DuelProtocol.in_second_person(outcome.describe(), me.display_name))
	)
	host.duel.spell_resolved.connect(spell_show.show_outcome)
	host.duel.finished.connect(func (winner, _loser): _finish(winner == me))


func _set_up_as_guest() -> void:
	guest = DuelGuest.new()
	guest.name = "Guest"
	add_child(guest)
	guest.setup(me, foe, player_circle, opponent_circle)
	guest.outgoing.connect(link.send)
	guest.mirror.resolved.connect(func (line, _by_me): hud.add_line(line))
	# The host says what each cast did, and it is shown here as there.
	guest.mirror.shown.connect(spell_show.show_outcome)
	guest.mirror.finished.connect(_finish)


func _process(delta: float) -> void:
	if is_over:
		return
	if not _begun:
		if host != null:
			_countdown -= delta
			if _countdown <= 0.0:
				begin()
			else:
				_show_countdown()
		return
	if host != null:
		host.advance(delta)
	if not _said_escalated and elapsed_seconds() > Duel.ESCALATION_STARTS:
		_said_escalated = true
		hud.add_line(DuelHud.ESCALATION_LINE)


## Seconds the duel has been running, as far as this machine knows.
func elapsed_seconds() -> float:
	if host != null:
		return host.duel.elapsed_seconds
	return guest.mirror.elapsed_seconds


## Begins the duel. The host does this when its countdown runs out, and
## the guest when the host says so.
func begin() -> void:
	if _begun:
		return
	_begun = true
	hud.overlay.hide()
	if host != null:
		link.send(DuelProtocol.go())
		host.begin()
	else:
		guest.begin()


func _show_countdown() -> void:
	var brought := "They bring %s." % [_names_of(foe.spellbook)]
	var text := "%s\nWaiting for the host." % [brought]
	if host != null:
		text = "%s\nThe duel begins in %d." % [brought, ceili(maxf(_countdown, 0.0))]
	hud.overlay.show_notice(foe.display_name, "against you", text)


func _names_of(book: Spellbook) -> String:
	if book.spells.size() > Loadout.SIZE:
		return "every spell"
	var names: PackedStringArray = []
	for spell in book.spells:
		names.append(spell.display_name)
	return ", ".join(names)


func _on_received(contents: Dictionary) -> void:
	if is_over:
		return
	if contents.get(DuelProtocol.TYPE) == DuelProtocol.GO:
		if guest != null:
			begin()
		return
	if host != null:
		if _begun:
			host.receive(contents)
	else:
		guest.receive(contents)


func _on_peer_left() -> void:
	if is_over:
		return
	is_over = true
	player_circle.accepts_input = false
	player_circle.abandon()
	hud.overlay.show_notice(foe.display_name, "has left the duel", "There is nobody to fight.", true)


func _finish(i_won: bool) -> void:
	is_over = true
	hud.name_opponent_spell(null)
	opponent_circle.prepare(null)
	var text := "The duel lasted %d seconds.\nYou ended with %d health of %d, and %s with %d of %d." % [
		roundi(elapsed_seconds()),
		ceili(me.health), roundi(me.max_health),
		foe.display_name, ceili(foe.health), roundi(foe.max_health),
	]
	hud.overlay.show_result(i_won, foe.display_name, text)


## Lets go of the other player and goes back to the versus menu.
func leave() -> void:
	link.close()
	_go_to(Session.VERSUS_MENU_SCENE)


func _go_to(scene_path: String) -> void:
	if not _destination.is_empty():
		return
	_destination = scene_path
	player_circle.accepts_input = false
	hud.fade_out()


func _on_fade_transition_timeout() -> void:
	# The same signal fires when the fade that opens the scene ends.
	if not _destination.is_empty():
		get_tree().change_scene_to_file(_destination)
