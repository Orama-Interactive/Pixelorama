class_name Layer extends Reference
# A class for layer properties.


var name := ""
var visible := true
var locked := false
var frame_container : HBoxContainer
var new_cels_linked := false
var linked_cels := [] # Array of Frames


func _init(_name := tr("Layer") + " 0", _visible := true, _locked := false, _frame_container := HBoxContainer.new(), _new_cels_linked := false, _linked_cels := []) -> void:
	name = _name
	visible = _visible
	locked = _locked
	frame_container = _frame_container
	new_cels_linked = _new_cels_linked
	linked_cels = _linked_cels


func can_layer_get_drawn() -> bool:
	return visible && !locked
