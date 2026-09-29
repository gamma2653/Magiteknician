class_name HostFinder
extends Node
## Listens for hosts calling out on the same network, and keeps a list of
## those it has heard lately.

## The list of hosts is not what it was.
signal changed

## A host that has not been heard from for this long has gone.
const FORGET_SECONDS := 3.5
## No more hosts than this are listed.
const MOST := 8

## The hosts heard lately, the longest known first. Each is a dictionary
## with "name", "address" and "port".
var hosts: Array[Dictionary] = []
var is_listening: bool = false

var _socket := PacketPeerUDP.new()
# Seconds since each host was heard from, by where it is.
var _silent_for: Dictionary[String, float] = {}


## Begins to listen on `port`.
func listen(port: int = HostBeacon.DISCOVERY_PORT, on_address: String = "*") -> Error:
	stop()
	_socket = PacketPeerUDP.new()
	var error := _socket.bind(port, on_address)
	if error != OK:
		return error
	is_listening = true
	return OK


func stop() -> void:
	is_listening = false
	_socket.close()
	if not hosts.is_empty():
		hosts = []
		_silent_for = {}
		changed.emit()


func _process(delta: float) -> void:
	if not is_listening:
		return
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		hear(packet.get_string_from_utf8(), _socket.get_packet_ip())
	age(delta)


func _exit_tree() -> void:
	is_listening = false
	_socket.close()


## Takes what was called out from `address`.
func hear(text: String, address: String) -> void:
	var said := HostBeacon.read(text)
	if said.is_empty() or address.is_empty():
		return
	# A host that says which host it is, is that host wherever it is
	# heard from. A machine on two networks is heard from twice.
	var where := "%s:%d" % [address, said["port"]]
	if said.has("id"):
		where = "%s:%d" % [said["id"], said["port"]]
	var known := _silent_for.has(where)
	_silent_for[where] = 0.0
	for host in hosts:
		if host["where"] == where:
			if host["name"] != said["name"]:
				host["name"] = said["name"]
				changed.emit()
			return
	if known or hosts.size() >= MOST:
		return
	hosts.append({"name": said["name"], "address": address, "port": said["port"], "where": where})
	changed.emit()


## Lets `seconds` pass, and forgets the hosts that have gone quiet.
func age(seconds: float) -> void:
	var gone := false
	for where in _silent_for.keys():
		_silent_for[where] += seconds
		if _silent_for[where] > FORGET_SECONDS:
			_silent_for.erase(where)
			hosts = hosts.filter(func (host): return host["where"] != where)
			gone = true
	if gone:
		changed.emit()


## How a host is listed, e.g. "Hana, at 192.168.1.20".
static func label_of(host: Dictionary) -> String:
	var text := "%s, at %s" % [host["name"], host["address"]]
	if int(host["port"]) != NetLink.DEFAULT_PORT:
		text += ", port %d" % [host["port"]]
	return text
