class_name Frame
extends RefCounted
## A class for frame properties.
## A frame is a collection of cels, for each layer.

var cels: Array[BaseCel]  ## The array containing all of the frame's [BaseCel]s. One for each layer.
var duration := 1.0  ## The duration multiplier. This allows for individual frame timing.
var user_data := ""  ## User defined data, set in the frame properties.


func _init(_cels: Array[BaseCel] = [], _duration := 1.0) -> void:
	cels = _cels
	duration = _duration
