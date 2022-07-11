class_name GroupLayer
extends BaseLayer
# A class for group layer properties

var expanded := true

func _init(_name := "") -> void:
	name = _name

# Overridden Functions:

func serialize() -> Dictionary:
	var data = .serialize()
	data["type"] = Global.LayerTypes.GROUP
	data["expanded"] = expanded
	return data


func deserialize(dict: Dictionary) -> void:
	.deserialize(dict)
	expanded = dict.expanded


func get_default_name(number: int) -> String:
	return tr("Group") + " %s" % number


func accepts_child(_layer: BaseLayer) -> bool:
	return true


func create_layer_button() -> Node:
	return Global.group_layer_button_node.instance()
