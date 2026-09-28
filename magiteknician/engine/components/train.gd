@tool
@abstract
class_name Train  # Distinct from utils.gd/ActionTrain, as this is connected to display content
extends Node2D


var runes: Array[Rune]:
	get:
		var _runes: Array[Rune]
		_runes.assign(get_children().filter(func (node):
			return node is Rune
		))
		return _runes

var bound_runes: Array[Rune]:
	get:
		var _runes: Array[Rune]
		_runes.assign(get_children().filter(func (node):
			return (node is Rune) and ((node as Rune).is_bound())
		))
		return _runes

func clear_runes():
	get_children().map(func (node):
		if node is Rune:
			remove_child(node)
			node.queue_free()
	)

func clear_bound_runes():
	get_children().map(func (node):
		if node is Rune and (node as Rune).is_bound():
			remove_child(node)
			node.queue_free()
	)

func _to_string() -> String:
	var _ret = "; ".join(runes.map(func (rune):
		return rune._to_string()
	))
	return "{%s}" % [_ret]

## When each rune on the train falls due.
var ticks: Array[int]:
	get:
		var _ticks: Array[int] = []
		_ticks.assign(bound_runes.map(func (rune):
			return rune.unscaled_ticks
		))
		return _ticks

## Where each rune on the train sits.
var locations: Array[Vector2]:
	get:
		var _locs: Array[Vector2] = []
		_locs.assign(bound_runes.map(func (rune):
			return rune.position
		))
		return _locs
