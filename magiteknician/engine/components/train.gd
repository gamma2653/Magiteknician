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
	#set(new_runes):
		#for child in get_children():
			#if child is not Rune:
				#continue
			## Remove rune children, deleting those not in new list
			#remove_child(child)  # for ordering purposes
			#if child not in new_runes:
				#child.queue_free()
		## Add children to tree
		#for rune in new_runes:
			#add_child(rune)
			

var bound_runes: Array[Rune]:
	get:
		var _runes: Array[Rune]
		_runes.assign(get_children().filter(func (node):
			return (node is Rune) and ((node as Rune).is_bound())
		))
		return _runes
	#set(new_runes):
		#for child in get_children():
			## Skip non-bound Runes/other nodes
			#if child is not Rune or not (child as Rune).is_bound():
				#continue
			## Only bound runes from here
			#remove_child(child)  # for ordering purposes
			#if child not in new_runes:
				#child.queue_free()
		#for rune in new_runes:
			#add_child(rune)

func clear_runes():
	get_children().map(func (node):
		if node is Rune:
			remove_child(node)
	)

func clear_bound_runes():
	get_children().map(func (node):
		if node is Rune and (node as Rune).is_bound():
			remove_child(node)
	)


func _to_string() -> String:
	var _ret = "; ".join(runes.map(func (rune):
		return rune._to_string()
	))
	return "{%s}" % [_ret]
