class_name Frame extends Reference
# A class for frame properties.
# A frame is a collection of cels, for each layer.


var cels : Array # An array of Cels
var duration := 1.0


func _init(_cels := [], _duration := 1.0) -> void:
	cels = _cels
	duration = _duration
