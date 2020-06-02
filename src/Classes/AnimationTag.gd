class_name AnimationTag extends Reference
# A class for frame tag properties


var name : String
var color : Color
var from : int
var to : int


func _init(_name, _color, _from, _to) -> void:
	name = _name
	color = _color
	from = _from
	to = _to
