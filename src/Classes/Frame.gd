class_name Frame extends Reference
# A class for frame properties.
# A frame is a collection of cels, for each layer.


var cels : Array # An array of Cels


func _init(_cels := []) -> void:
	cels = _cels
