class_name FakeLink
extends Node
## Stands in for a NetLink in tests: the same signals and methods, joined
## to another FakeLink by a queue instead of a socket.
##
## Messages pass through JSON on the way, and wait in the queue until
## deliver() is called, so nothing arrives while its sender is still in
## the middle of sending.

signal received(contents: Dictionary)
signal peer_joined
signal peer_left
signal joined
signal join_failed
signal refused(reason: String)

var role: NetLink.Role = NetLink.Role.NONE
## The link at the other end, once joined.
var other: FakeLink
## Every message this link has sent, in order.
var sent: Array = []
## What host() and join() answer. Set to something else to have them fail.
var answer: Error = OK
## Hosts that can be joined, by address.
static var hosts: Dictionary = {}

var _waiting: Array = []
var _address: String = ""


## Forgets every host. Call between tests.
static func forget_hosts() -> void:
	hosts = {}


func host(port: int = NetLink.DEFAULT_PORT) -> Error:
	close()
	if answer != OK:
		return answer
	role = NetLink.Role.HOST
	_address = "127.0.0.1:%d" % [port]
	hosts[_address] = self
	return OK


func join(address: String, port: int = NetLink.DEFAULT_PORT) -> Error:
	close()
	if answer != OK:
		return answer
	role = NetLink.Role.GUEST
	_address = "%s:%d" % [address, port]
	return OK


## Carries out what a network would have by now: a guest that is looking
## for a host finds it or fails to, and every message in flight arrives.
func settle() -> void:
	if role == NetLink.Role.GUEST and other == null:
		var found: FakeLink = hosts.get(_address)
		if found == null or found.other != null:
			role = NetLink.Role.NONE
			join_failed.emit()
		else:
			other = found
			found.other = self
			found.peer_joined.emit()
			joined.emit()
	deliver()
	if other != null:
		other.deliver()
		deliver()


## Hands over everything that has been sent to this link.
func deliver() -> void:
	while not _waiting.is_empty():
		received.emit(_waiting.pop_front())


func close() -> void:
	if role == NetLink.Role.HOST:
		hosts.erase(_address)
	role = NetLink.Role.NONE
	_waiting = []
	if other != null:
		var was := other
		other = null
		was.other = null
		if was.role == NetLink.Role.GUEST:
			was.role = NetLink.Role.NONE
		was.peer_left.emit()


func is_joined() -> bool:
	return other != null


func send(contents: Dictionary) -> bool:
	if other == null:
		return false
	sent.append(contents)
	other._waiting.append(JSON.parse_string(JSON.stringify(contents)))
	return true


## The types of the messages sent so far, in order.
func sent_types() -> Array:
	return sent.map(func (contents): return contents[DuelProtocol.TYPE])
