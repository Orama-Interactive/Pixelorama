class_name Layer
extends Reference
# A class for layer properties.

var name := ""
var visible := true
var locked := false
var new_cels_linked := false
var linked_cels := []  # Array of Frames
var blend_mode := 0


func _init(
	_name := "",
	_visible := true,
	_locked := false,
	_new_cels_linked := false,
	_blend_mode := 0,
	_linked_cels := []
) -> void:
	name = _name
	visible = _visible
	locked = _locked
	new_cels_linked = _new_cels_linked
	blend_mode = _blend_mode
	linked_cels = _linked_cels


func can_layer_get_drawn() -> bool:
	return visible && !locked
