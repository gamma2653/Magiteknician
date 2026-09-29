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
const CURSOR_NAMES: Dictionary[Cursor, String] = {
	Cursor.DRAWN: "drawn",
	Cursor.BRUSH: "brush",
}

## Where the options are kept. Tests point this somewhere of their own.
var path: String = DEFAULT_PATH
var cursor: Cursor = DEFAULT_CURSOR


func _ready() -> void:
	read()


## Chooses the cursor, and keeps the choice.
func choose_cursor(which: Cursor) -> void:
	if cursor == which:
		return
	cursor = which
	changed.emit()
	write()


## Puts every option back to what it is before the player has chosen
## anything. Nothing is written.
func reset() -> void:
	take({})


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"cursor": CURSOR_NAMES[cursor],
	}


## Takes the options from `data`. What it does not say, or says in a way
## that cannot be understood, is left as it is before the player has chosen.
func take(data: Dictionary) -> void:
	var found: Variant = CURSOR_NAMES.find_key(str(data.get("cursor", "")))
	cursor = DEFAULT_CURSOR if found == null else found
	changed.emit()


func write() -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var error := FileAccess.get_open_error()
		push_warning("The options could not be saved to %s: %s" % [path, error_string(error)])
		return error
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
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
