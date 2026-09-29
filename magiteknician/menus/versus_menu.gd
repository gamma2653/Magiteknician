extends Transitionable
## Where two players find each other before a duel. One hosts, the other
## joins by address, and when both are there the host begins.

const DEFAULT_ADDRESS := "127.0.0.1"
const NOBODY_NEARBY := "Nobody nearby is hosting. A host further off can be joined by address."
const NOT_LISTENING := "Hosts nearby cannot be listened for: %s. A host can still be joined by address."

@onready var player_name: LineEdit = %PlayerName
@onready var address: LineEdit = %Address
@onready var host_button: Button = %Host
@onready var join_button: Button = %Join
@onready var begin_button: Button = %Begin
@onready var status: Label = %Status
@onready var spells_button: Button = %Spells
@onready var port_box: SpinBox = %Port
@onready var nearby: VBoxContainer = %Nearby
@onready var nobody_nearby: Label = %NobodyNearby
@onready var beacon: HostBeacon = $Beacon
@onready var finder: HostFinder = $Finder
@onready var loadout: LoadoutPanel = $Loadout
@onready var fade: ColorRect = $FadeTransition

## What carries the messages. The game's own link unless a test says
## otherwise.
var link: Node

var _their_name: String = ""
var _their_spells: Array[StringName] = []
# The spells both games have. Until the other has said, every spell.
var _in_common: Array[StringName] = Loadout.every_spell()
var _destination: String = ""


func _ready() -> void:
	if link == null:
		link = Net
	player_name.text = Session.versus_name
	address.text = DEFAULT_ADDRESS
	begin_button.disabled = true
	status.text = "Host a duel, or join one."
	spells_button.text = LoadoutPanel.summary(Settings.versus_spells)
	loadout.changed.connect(_on_spells_chosen)
	port_box.min_value = 1024
	port_box.max_value = 65535
	port_box.value = Settings.versus_port
	port_box.value_changed.connect(func (value): Settings.choose_versus_port(int(value)))
	finder.changed.connect(_list_hosts)
	listen_for_hosts()
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


## The port that is hosted on, and joined at unless the address says
## another.
func port() -> int:
	return Settings.tidy_port(int(port_box.value))


## Begins to listen for hosts calling out nearby.
func listen_for_hosts() -> void:
	beacon.stop()
	var error := finder.listen()
	nobody_nearby.text = NOBODY_NEARBY if error == OK else NOT_LISTENING % [error_string(error)]
	_list_hosts()


func _on_host_pressed() -> void:
	_forget_them()
	var error: Error = link.host(port())
	if error != OK:
		status.text = "Could not host on port %d: %s." % [port(), error_string(error)]
		return
	status.text = "Waiting for a challenger on port %d." % [port()]
	# A host calls out, and has nobody to listen for.
	finder.stop()
	beacon.call_out(my_name(), port())
	_lock_choices(true)


func _on_join_pressed() -> void:
	var where := where_to_join(address.text, port())
	if where.is_empty():
		status.text = "Say where the host is."
		return
	join(where["address"], where["port"])


## Looks for a host at `at_address`, on `at_port`.
func join(at_address: String, at_port: int) -> void:
	_forget_them()
	var error: Error = link.join(at_address, at_port)
	if error != OK:
		status.text = "Could not look for a host at %s: %s." % [at_address, error_string(error)]
		return
	status.text = "Looking for a host at %s." % [at_address]
	_lock_choices(true)


## Where `written` says to join, as "address" and "port". An address can
## have its port written after it, as "192.168.1.20:24700"; one that has
## not is joined at `usual_port`. Empty if nothing is written.
static func where_to_join(written: String, usual_port: int) -> Dictionary:
	var where := written.strip_edges()
	if where.is_empty():
		return {}
	var colon := where.rfind(":")
	# An address with more than one colon in it is of the long kind, and
	# its colons are its own.
	if colon > 0 and where.count(":") == 1 and where.substr(colon + 1).is_valid_int():
		return {"address": where.left(colon), "port": Settings.tidy_port(where.substr(colon + 1).to_int())}
	return {"address": where, "port": usual_port}


func _list_hosts() -> void:
	for child in nearby.get_children():
		nearby.remove_child(child)
		child.queue_free()
	nobody_nearby.visible = finder.hosts.is_empty()
	for host in finder.hosts:
		var button := Button.new()
		button.text = HostFinder.label_of(host)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 36)
		button.clip_text = true
		button.disabled = link.role != NetLink.Role.NONE
		button.pressed.connect(_on_nearby_pressed.bind(host))
		nearby.add_child(button)


func _on_nearby_pressed(host: Dictionary) -> void:
	address.text = host["address"]
	join(host["address"], host["port"])


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
	_list_hosts()


func _on_peer_left() -> void:
	_forget_them()
	if link.role == NetLink.Role.HOST:
		status.text = "They have left. Waiting for a challenger on port %d." % [port()]
		beacon.call_out(my_name(), port())
	else:
		status.text = "The host has gone."
		_lock_choices(false)
		_list_hosts()


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
			_in_common = DuelProtocol.spells_in_common(contents)
			_their_spells = Loadout.in_common(DuelProtocol.spells_in(contents), _in_common)
			if _their_spells.is_empty() and contents.has("spells"):
				# They brought nothing this game has, and bring what it has.
				_their_spells = Loadout.tidy([], _in_common)
			if link.role == NetLink.Role.HOST:
				status.text = "%s has joined. Begin when you are ready." % [_their_name]
				begin_button.disabled = false
				# There is room for one, and they have come.
				beacon.stop()
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
	link.send(DuelProtocol.start(names[0], names[1], what_i_bring(), _their_spells))
	_enter_arena(names[0], names[1], true)


## The spells I chose, of those both games have.
func what_i_bring() -> Array[StringName]:
	return Loadout.tidy(Loadout.in_common(Settings.versus_spells, _in_common), _in_common)


func _on_back_pressed() -> void:
	link.close()
	beacon.stop()
	finder.stop()
	# Keep the name for next time.
	Session.versus_name = player_name.text.strip_edges()
	_go_to(Session.MAIN_MENU_SCENE)


func _enter_arena(mine: String, theirs: String, hosting: bool) -> void:
	Session.versus_name = mine
	Session.versus_foe_name = theirs
	Session.versus_foe_spells = _their_spells
	Session.versus_is_host = hosting
	if hosting or Session.versus_spells.is_empty():
		Session.versus_spells = what_i_bring()
	_go_to(Session.VERSUS_ARENA_SCENE)


func _forget_them() -> void:
	_their_name = ""
	_their_spells = []
	_in_common = Loadout.every_spell()
	Session.versus_spells = []
	begin_button.disabled = true


func _lock_choices(locked: bool) -> void:
	host_button.disabled = locked
	join_button.disabled = locked
	# What is brought has been said, once there is somebody to say it to.
	spells_button.disabled = locked
	port_box.editable = not locked
	for button: Button in nearby.get_children():
		button.disabled = locked
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
