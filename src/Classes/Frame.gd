class_name Frame
extends RefCounted
## A class for frame properties.
## A frame is a collection of cels, for each layer.

var cels: Array[BaseCel]
var duration := 1.0


func _init(_cels: Array[BaseCel] = [], _duration := 1.0) -> void:
	cels = _cels
	duration = _duration
