extends Node
## How often the game looks at the keys.
##
## A key is struck when it is struck, and the game hears of it when it
## next comes round, which is once a frame. Being late by the same amount
## every time would not matter, since a cast is judged on its rhythm and
## not on when it began. But a stroke is late by anything up to a whole
## frame, a different amount each time, and that is heard as unsteadiness
## in the caster's hand. At sixty frames a second it is a sixth of a tick
## at the tempo of a fast caster. A hand good enough for the best grade
## every time gets it little more than half the time.
##
## The engine does not say when a key was struck, only that it has been.
## So while there is a rune to strike, the game comes round more often:
## it stops waiting for the screen, and draws as many frames as it looks
## at the keys. That asks more of the machine, and the player can turn it
## off in the options.
##
## Whoever wants the keys read closely asks with quicken(), and says when
## they are done with settle().

## How often the keys are looked at while somebody wants them read
## closely, in times a second.
const QUICK_PER_SECOND := 500
## How long after the last of them is done the game waits before it goes
## back to its usual pace. Changing pace makes the screen stall for a
## moment, and a circle is done and wants again between one cast and the
## next.
const SETTLE_SECONDS := 0.75

## True while the keys are being read closely.
var is_quick: bool = false
## How the screen is waited for just now, as this last asked for it.
var vsync: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED

var _askers: Array[Object] = []
var _settles_in: float = 0.0
# The pace the game keeps when nobody is asking.
var _usual_vsync: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED
var _usual_per_second: int = 0


func _ready() -> void:
	_usual_vsync = DisplayServer.window_get_vsync_mode()
	_usual_per_second = Engine.max_fps
	vsync = _usual_vsync
	Settings.changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	_go_slow()


## Reads the keys closely from now, on behalf of `whom`.
func quicken(whom: Object) -> void:
	if whom not in _askers:
		_askers.append(whom)
	_settles_in = SETTLE_SECONDS
	if Settings.precise_timing:
		_go_quick()


## `whom` no longer wants the keys read closely. If nobody else does
## either, the game goes back to its usual pace before long.
func settle(whom: Object) -> void:
	_askers.erase(whom)
	_settles_in = SETTLE_SECONDS


## True while anybody wants the keys read closely.
func is_wanted() -> bool:
	_askers = _askers.filter(func (asker): return is_instance_valid(asker))
	return not _askers.is_empty()


## Goes back to the usual pace at once, whoever is asking.
func settle_now() -> void:
	_askers.clear()
	_settles_in = 0.0
	_go_slow()


## Lets `seconds` pass.
func advance(seconds: float) -> void:
	if not is_quick or is_wanted():
		return
	_settles_in -= seconds
	if _settles_in <= 0.0:
		_go_slow()


## When the game hears of a stroke that was struck at `struck_usec`, if it
## comes round every `period_usec` and came round at `phase_usec`: the
## next time it comes round.
static func heard_at(struck_usec: float, period_usec: float, phase_usec: float = 0.0) -> float:
	if period_usec <= 0.0:
		return struck_usec
	return ceilf((struck_usec - phase_usec) / period_usec) * period_usec + phase_usec


## How unsteady reading the keys `per_second` times a second makes a hand
## look, in seconds: the standard deviation of how late a stroke is heard.
static func unsteadiness(per_second: float) -> float:
	if per_second <= 0.0:
		return 0.0
	return 1.0 / per_second / sqrt(12.0)


func _process(delta: float) -> void:
	advance(delta)


func _on_settings_changed() -> void:
	if not Settings.precise_timing:
		_go_slow()
	elif is_wanted():
		_go_quick()


func _go_quick() -> void:
	if is_quick:
		return
	is_quick = true
	_usual_vsync = DisplayServer.window_get_vsync_mode()
	_usual_per_second = Engine.max_fps
	vsync = DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync)
	Engine.max_fps = QUICK_PER_SECOND


func _go_slow() -> void:
	if not is_quick:
		return
	is_quick = false
	vsync = _usual_vsync
	DisplayServer.window_set_vsync_mode(vsync)
	Engine.max_fps = _usual_per_second
