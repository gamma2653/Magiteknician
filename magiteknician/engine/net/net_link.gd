class_name NetLink
extends Node
## Carries messages between two machines over ENet.
##
## One side hosts and the other joins. After that the two are equals as
## far as the link is concerned: either can send(), and what the other
## sent comes out of `received`. What the messages mean is not the link's
## business; DuelProtocol says what they are, and DuelHost and DuelGuest
## act on them.
##
## The link uses whatever multiplayer API the node was given, so two of
## them can be joined inside one running game, each under a branch of the
## tree with an API of its own. That is how it is tested.

## A message arrived from the other side.
signal received(contents: Dictionary)
## Hosting: somebody joined.
signal peer_joined
## The other side has gone, whichever side this is.
signal peer_left
## Joining: the host was reached.
signal joined
## Joining: the host could not be reached.
signal join_failed
## Something arrived that was not a message, and was thrown away.
signal refused(reason: String)

enum Role { NONE, HOST, GUEST }

const DEFAULT_PORT := 24653
## A duel is between two. The host takes one guest.
const MAX_GUESTS := 1
## Nothing in a duel needs a message anywhere near this long, in bytes.
const MAX_MESSAGE_BYTES := 8192

## How long a guest waits for a host to answer, in seconds. ENet's own
## patience runs to half a minute, which is a long time to look at a menu.
var join_timeout_seconds: float = 6.0

var role: Role = Role.NONE
## The id of the peer at the other end, or 0 while there is none.
var other_peer: int = 0

var _joining_for: float = 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Waits for a guest on `port`.
func host(port: int = DEFAULT_PORT) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_GUESTS)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	return OK


## Looks for a host at `address`.
func join(address: String, port: int = DEFAULT_PORT) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	role = Role.GUEST
	_joining_for = 0.0
	return OK


func _process(delta: float) -> void:
	if role != Role.GUEST or is_joined():
		return
	_joining_for += delta
	if _joining_for >= join_timeout_seconds:
		_on_connection_failed()


## Lets go of the other side and stops hosting or joining.
func close() -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.NONE
	other_peer = 0


func is_joined() -> bool:
	return other_peer != 0


## Sends a message to the other side. Returns false if there is nobody to
## send it to, or it is too long to send.
func send(contents: Dictionary) -> bool:
	if not is_joined():
		return false
	var text := JSON.stringify(contents)
	if text.to_utf8_buffer().size() > MAX_MESSAGE_BYTES:
		push_warning("A message of type '%s' is too long to send." % [contents.get(DuelProtocol.TYPE, "?")])
		return false
	_deliver.rpc_id(other_peer, text)
	return true


## Takes what the other side sent. Everything that arrives comes through
## here, and none of it is trusted to be a message until it has been read.
@rpc("any_peer", "call_remote", "reliable")
func _deliver(text: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != other_peer:
		refused.emit("It came from somebody who is not in the duel.")
		return
	accept(text)


## Reads `text` as a message and passes it on, or refuses it.
func accept(text: String) -> void:
	if text.to_utf8_buffer().size() > MAX_MESSAGE_BYTES:
		refused.emit("It was too long.")
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		refused.emit("It was not JSON.")
		return
	if json.data is not Dictionary:
		refused.emit("It was not a message.")
		return
	received.emit(json.data)


func _on_peer_connected(id: int) -> void:
	if role == Role.HOST:
		other_peer = id
		peer_joined.emit()


func _on_peer_disconnected(id: int) -> void:
	if id == other_peer:
		other_peer = 0
		peer_left.emit()


func _on_connected_to_server() -> void:
	# The host is always peer 1.
	other_peer = MultiplayerPeer.TARGET_PEER_SERVER
	joined.emit()


func _on_connection_failed() -> void:
	close()
	join_failed.emit()


func _on_server_disconnected() -> void:
	close()
	peer_left.emit()
