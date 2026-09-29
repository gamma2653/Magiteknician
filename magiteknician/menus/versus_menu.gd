extends Transitionable
## Where two players find each other before a duel. One hosts, the other
## joins by address, and when both are there the host begins.

const DEFAULT_ADDRESS := "127.0.0.1"

@onready var player_name: LineEdit = %PlayerName
@onready var address: LineEdit = %Address
@onready var host_button: Button = %Host
@onready var join_button: Button = %Join
@onready var begin_button: Button = %Begin
@onready var status: Label = %Status
@onready var spells_button: Button = %Spells
@onready var loadout: LoadoutPanel = $Loadout
@onready var fade: ColorRect = $FadeTransition

## What carries the messages. The game's own link unless a test says
## otherwise.
var link: Node

var _their_name: String = ""
var _their_spells: Array[StringName] = []
var _destination: String = ""


func _ready() -> void:
	if link == null:
		link = Net
	player_name.text = Session.versus_name
	address.text = DEFAULT_ADDRESS
	begin_button.disabled = true
	status.text = "Host a duel, or join one by its address."
	spells_button.text = LoadoutPanel.summary(Settings.versus_spells)
	loadout.changed.connect(_on_spells_chosen)
	link.received.connect(_on_received)
	link.peer_joined.connect(_on_peer_joined)
	link.joined.connect(_on_joined)
	link.join_failed.connect(_on_join_failed)
	link.peer_left.connect(_on_peer_left)
	fade.end_transition()


func _exit_tree() -> void:
	link.received.disconnect(_on_received)
	link.peer_joined.disconnect(_on_peer_joined)
	link.joined.disconnect(_on_joined)
	link.join_failed.disconnect(_on_join_failed)
	link.peer_left.disconnect(_on_peer_left)


func my_name() -> String:
	return DuelProtocol.tidy_name(player_name.text, "Host" if link.role == NetLink.Role.HOST else "Guest")


func _on_host_pressed() -> void:
	_forget_them()
	var error: Error = link.host(NetLink.DEFAULT_PORT)
	if error != OK:
		status.text = "Could not host on port %d: %s." % [NetLink.DEFAULT_PORT, error_string(error)]
		return
	status.text = "Waiting for a challenger on port %d." % [NetLink.DEFAULT_PORT]
	_lock_choices(true)


func _on_join_pressed() -> void:
	_forget_them()
	var where := address.text.strip_edges()
	if where.is_empty():
		status.text = "Say where the host is."
		return
	var error: Error = link.join(where, NetLink.DEFAULT_PORT)
	if error != OK:
		status.text = "Could not look for a host at %s: %s." % [where, error_string(error)]
		return
	status.text = "Looking for a host at %s." % [where]
	_lock_choices(true)


func _on_spells_pressed() -> void:
	loadout.open(SpellLibrary.all(), Settings.versus_spells)


func _on_spells_chosen(chosen: Array[StringName]) -> void:
	Settings.choose_versus_spells(chosen)
	spells_button.text = LoadoutPanel.summary(Settings.versus_spells)


func _on_peer_joined() -> void:
	status.text = "Somebody has joined."
	link.send(DuelProtocol.hello(my_name(), Settings.versus_spells))


func _on_joined() -> void:
	status.text = "Joined. Waiting for the host."
	link.send(DuelProtocol.hello(my_name(), Settings.versus_spells))


func _on_join_failed() -> void:
	status.text = "Nobody answered at %s." % [address.text.strip_edges()]
	_lock_choices(false)


func _on_peer_left() -> void:
	_forget_them()
	if link.role == NetLink.Role.HOST:
		status.text = "They have left. Waiting for a challenger on port %d." % [NetLink.DEFAULT_PORT]
	else:
		status.text = "The host has gone."
		_lock_choices(false)


func _on_received(contents: Dictionary) -> void:
	if not DuelProtocol.problems(contents).is_empty():
		return
	match contents[DuelProtocol.TYPE]:
		DuelProtocol.HELLO:
			if int(contents["version"]) != DuelProtocol.VERSION:
				status.text = "They have a different version of the game, and the two cannot duel."
				link.close()
				_lock_choices(false)
				return
			_their_name = DuelProtocol.tidy_name(contents["name"], "Guest" if link.role == NetLink.Role.HOST else "Host")
			_their_spells = DuelProtocol.spells_in(contents)
			if link.role == NetLink.Role.HOST:
				status.text = "%s has joined. Begin when you are ready." % [_their_name]
				begin_button.disabled = false
			else:
				status.text = "Joined %s. Waiting for them to begin." % [_their_name]
		DuelProtocol.START:
			if link.role == NetLink.Role.GUEST:
				# The host says what each of us brings. What it says of
				# me is what it will let me cast.
				var mine := DuelProtocol.spells_in(contents, "guest_spells")
				if not mine.is_empty():
					Session.versus_spells = mine
				_their_spells = DuelProtocol.spells_in(contents, "host_spells")
				_enter_arena(contents["guest"], contents["host"], false)


func _on_begin_pressed() -> void:
	if link.role != NetLink.Role.HOST or _their_name.is_empty():
		return
	var names := DuelProtocol.names_for_duel(my_name(), _their_name)
	link.send(DuelProtocol.start(names[0], names[1], Settings.versus_spells, _their_spells))
	_enter_arena(names[0], names[1], true)


func _on_back_pressed() -> void:
	link.close()
	# Keep the name for next time.
	Session.versus_name = player_name.text.strip_edges()
	_go_to(Session.MAIN_MENU_SCENE)


func _enter_arena(mine: String, theirs: String, hosting: bool) -> void:
	Session.versus_name = mine
	Session.versus_foe_name = theirs
	Session.versus_foe_spells = _their_spells
	Session.versus_is_host = hosting
	if hosting or Session.versus_spells.is_empty():
		Session.versus_spells = Settings.versus_spells.duplicate()
	_go_to(Session.VERSUS_ARENA_SCENE)


func _forget_them() -> void:
	_their_name = ""
	_their_spells = []
	Session.versus_spells = []
	begin_button.disabled = true


func _lock_choices(locked: bool) -> void:
	host_button.disabled = locked
	join_button.disabled = locked
	# What is brought has been said, once there is somebody to say it to.
	spells_button.disabled = locked
	player_name.editable = not locked
	address.editable = not locked


func _go_to(scene_path: String) -> void:
	if not _destination.is_empty():
		return
	_destination = scene_path
	fade.start_transition()


func _on_fade_transition_timeout() -> void:
	# The same signal fires when the fade that opens the scene ends.
	if not _destination.is_empty():
		get_tree().change_scene_to_file(_destination)
