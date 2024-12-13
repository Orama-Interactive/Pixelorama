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


func get_duration_in_seconds(fps: float) -> float:
	return duration * (1.0 / fps)


func position_in_seconds(project: Project, start_from := 0) -> float:
	var pos := 0.0
	var index := project.frames.find(self)
	if index > start_from:
		for i in range(start_from, index):
			if i >= 0:
				var frame := project.frames[i]
				pos += frame.get_duration_in_seconds(project.fps)
			else:
				pos += 1.0 / project.fps
	else:
		if start_from >= project.frames.size():
			return -1.0
		for i in range(start_from, index, -1):
			var frame := project.frames[i]
			pos -= frame.get_duration_in_seconds(project.fps)
	return pos
