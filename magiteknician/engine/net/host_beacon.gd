class_name HostBeacon
extends Node
## Calls out that there is a duel to be joined here, to whoever is
## listening on the same network.
##
## It says who is hosting and on which port, once a second, to every
## machine the network will carry it to. A HostFinder hears it. Neither
## has anything to do with the duel: this is how the two find each other,
## and the NetLink is how they meet.
##
## A machine can be on more than one network, and a call to everybody
## goes out on one of them, which the machine chooses. On the machine
## this was written on it chose a network that no other machine is on.
## So the call is made once on each network the machine is on.

## The port that is called out on and listened on. It is not the port the
## duel is fought on.
const DISCOVERY_PORT := 24654
## Everybody on the network.
const EVERYBODY := "255.255.255.255"
const EVERY_SECONDS := 1.0
## What is called out is from this game and no other.
const GAME := "magiteknician"
const MAX_BYTES := 512

## Where it is called out to. Tests call to themselves.
var address: String = EVERYBODY
var port: int = DISCOVERY_PORT
var is_calling: bool = false

# One for each network the call goes out on.
var _sockets: Array[PacketPeerUDP] = []
var _said: Dictionary = {}
var _since: float = 0.0


## Begins to call out that `host_name` is hosting on `game_port`.
func call_out(host_name: String, game_port: int) -> Error:
	stop()
	_said = announcement(host_name, game_port)
	# Which host this is, whatever address it is heard from.
	_said["id"] = "%08x" % [randi()]
	var error := ERR_CANT_CREATE
	for from in networks() if address == EVERYBODY else [""]:
		var socket := PacketPeerUDP.new()
		if not from.is_empty() and socket.bind(0, from) != OK:
			continue
		socket.set_broadcast_enabled(true)
		var set_to := socket.set_dest_address(address, port)
		if set_to != OK:
			error = set_to
			continue
		_sockets.append(socket)
	if _sockets.is_empty():
		return error
	is_calling = true
	_since = EVERY_SECONDS
	return OK


func stop() -> void:
	is_calling = false
	for socket in _sockets:
		socket.close()
	_sockets = []


## The addresses this machine has, one for each network it is on, and ""
## for whichever network the machine would choose for itself. Only
## addresses of the short kind, which are the ones that can be called
## out from to everybody.
static func networks() -> Array[String]:
	var found: Array[String] = [""]
	for local in IP.get_local_addresses():
		if local.is_valid_ip_address() and "." in local and not local.begins_with("127.") and not local.begins_with("169.254."):
			found.append(local)
	return found


func _process(delta: float) -> void:
	if not is_calling:
		return
	_since += delta
	if _since >= EVERY_SECONDS:
		_since = 0.0
		var call := JSON.stringify(_said).to_utf8_buffer()
		for socket in _sockets:
			socket.put_packet(call)


func _exit_tree() -> void:
	stop()


## What is called out.
static func announcement(host_name: String, game_port: int) -> Dictionary:
	return {
		"game": GAME,
		"version": DuelProtocol.VERSION,
		"name": DuelProtocol.tidy_name(host_name, "Host"),
		"port": game_port,
	}


## What `text` calls out, if it is a call from this game that this
## version can answer, and an empty dictionary if it is not. It has
## "name" and "port", and "id" if the host said which host it is.
static func read(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or json.data is not Dictionary:
		return {}
	var said: Dictionary = json.data
	if said.get("game") != GAME or said.get("name") is not String:
		return {}
	if not (said.get("version") is float or said.get("version") is int) or int(said["version"]) != DuelProtocol.VERSION:
		return {}
	if not (said.get("port") is float or said.get("port") is int):
		return {}
	var game_port := int(said["port"])
	if game_port < 1 or game_port > 65535:
		return {}
	var read_as := {"name": DuelProtocol.tidy_name(said["name"], "Host"), "port": game_port}
	if said.get("id") is String and not String(said["id"]).is_empty():
		read_as["id"] = String(said["id"]).left(16)
	return read_as
