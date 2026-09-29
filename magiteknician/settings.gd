extends Node
## What the player has chosen in the options, kept from one run of the
## game to the next.
##
## It is kept apart from the player's progress. Starting the campaign
## afresh replaces the progress, and should not put the options back.
##
## The file is JSON, as the save is: it can be read, and mended, in a text
## editor. A choice is written by name, so the file outlives a change to
## the order of the choices.

## Sent when any of the options has changed.
signal changed

enum Cursor {
	## The ring and the drop, drawn by the game.
	DRAWN,
	## The brush the game began with.
	BRUSH,
}

const VERSION := 1
const DEFAULT_PATH := "user://settings.json"
const DEFAULT_CURSOR := Cursor.DRAWN
## As loud as the sounds were made.
const DEFAULT_VOLUME := 1.0
## The bus that everything the game sounds goes through.
const BUS := &"Master"
const CURSOR_NAMES: Dictionary[Cursor, String] = {
	Cursor.DRAWN: "drawn",
	Cursor.BRUSH: "brush",
}

## Where the options are kept. Tests point this somewhere of their own.
var path: String = DEFAULT_PATH
var cursor: Cursor = DEFAULT_CURSOR
## How loud the game is, from 0, which is silent, to 1.
var volume: float = DEFAULT_VOLUME

# True while there is a choice that has not been written.
var _is_unkept: bool = false


func _ready() -> void:
	read()


## Chooses the cursor, and keeps the choice.
func choose_cursor(which: Cursor) -> void:
	if cursor == which:
		return
	cursor = which
	changed.emit()
	write()


## Sets how loud the game is, from 0 to 1. It is heard at once. It is
## kept at once too unless `keep_it` is false, which is for a slider that
## is still being dragged: say keep() when it is let go.
func choose_volume(how_loud: float, keep_it: bool = true) -> void:
	how_loud = clampf(how_loud, 0.0, 1.0)
	if not is_equal_approx(volume, how_loud):
		volume = how_loud
		_is_unkept = true
		apply_volume()
		changed.emit()
	if keep_it:
		keep()


## Writes what has been chosen and not yet written, if anything has.
func keep() -> void:
	if _is_unkept:
		write()


## How much of the sound's strength is let through at `how_loud`. Half
## way along the slider is a quarter of the strength, which is about half
## as loud to the ear.
static func strength_at(how_loud: float) -> float:
	return clampf(how_loud, 0.0, 1.0) ** 2.0


## Makes the game as loud as `volume` says.
func apply_volume() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus < 0:
		return
	var strength := strength_at(volume)
	AudioServer.set_bus_mute(bus, strength <= 0.0)
	if strength > 0.0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(strength))


## Puts every option back to what it is before the player has chosen
## anything. Nothing is written.
func reset() -> void:
	take({})


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"cursor": CURSOR_NAMES[cursor],
		"volume": volume,
	}


## Takes the options from `data`. What it does not say, or says in a way
## that cannot be understood, is left as it is before the player has chosen.
func take(data: Dictionary) -> void:
	var found: Variant = CURSOR_NAMES.find_key(str(data.get("cursor", "")))
	cursor = DEFAULT_CURSOR if found == null else found
	var how_loud: Variant = data.get("volume")
	volume = clampf(how_loud, 0.0, 1.0) if how_loud is float or how_loud is int else DEFAULT_VOLUME
	_is_unkept = false
	apply_volume()
	changed.emit()


func write() -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var error := FileAccess.get_open_error()
		push_warning("The options could not be saved to %s: %s" % [path, error_string(error)])
		return error
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	_is_unkept = false
	return OK


## Takes the options from the file at `path`. Returns false if there is
## none, or if what is there cannot be read, and then the options are what
## they are before the player has chosen anything.
func read() -> bool:
	if not FileAccess.file_exists(path):
		reset()
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or json.data is not Dictionary:
		push_warning("The options at %s could not be read and will be ignored." % [path])
		reset()
		return false
	take(json.data)
	return true
