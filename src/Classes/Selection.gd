class_name Selection extends Reference


var selected_area := [] # Selected pixels for each selection
var borders : PoolVector2Array
var node : SelectionShape


func _init(_node : SelectionShape) -> void:
	node = _node
	Global.canvas.add_child(node)
