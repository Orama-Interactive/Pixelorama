class_name GroupLayer
extends BaseLayer
# A class for group layer properties

var expanded := true


func _init(_project, _name := "") -> void:
	project = _project
	name = _name


# Overridden Methods:


func serialize() -> Dictionary:
	var data = .serialize()
	data["type"] = Global.LayerTypes.GROUP
	data["expanded"] = expanded
	return data


func deserialize(dict: Dictionary) -> void:
	.deserialize(dict)
	expanded = dict.expanded


func new_empty_cel() -> BaseCel:
	return GroupCel.new()


func set_name_to_default(number: int) -> void:
	name = tr("Group") + " %s" % number


func accepts_child(_layer: BaseLayer) -> bool:
	return true


func instantiate_layer_button() -> Node:
	return Global.group_layer_button_node.instance()
