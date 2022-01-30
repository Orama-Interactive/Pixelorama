class_name PixelLayer
extends BaseLayer
# A class for standard pixel layer properties.

var new_cels_linked := false
var linked_cels := []  # Array of Frames


func _init(
	_name := "", _visible := true, _locked := false, _new_cels_linked := false, _linked_cels := []
) -> void:
	name = _name
	visible = _visible
	locked = _locked
	new_cels_linked = _new_cels_linked
	linked_cels = _linked_cels


func can_layer_get_drawn() -> bool:
	return is_visible_in_hierarchy() && !is_locked_in_hierarchy()
