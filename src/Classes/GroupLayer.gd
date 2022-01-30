class_name GroupLayer
extends BaseLayer
# A class for group layer properties

var children := []
var expanded := true
var blend_shader: Shader


func is_expanded_in_hierarchy() -> bool:
	if is_instance_valid(parent) and expanded:
		return parent.is_expanded_in_hierarchy()
	return expanded
