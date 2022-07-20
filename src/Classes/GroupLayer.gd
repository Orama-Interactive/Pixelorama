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


func copy_cel(frame_index: int, _linked: bool) -> BaseCel:
	var cel: GroupCel = project.frames[frame_index].cels[index]
	return GroupCel.new(cel.opacity)


func copy_all_cels() -> Array:
	var cels := []
	for frame in project.frames:
		var cel: GroupCel = frame.cels[index]
		cels.append(GroupCel.new(cel.opacity))
	return cels


func set_name_to_default(number: int) -> void:
	name = tr("Group") + " %s" % number


func accepts_child(_layer: BaseLayer) -> bool:
	return true


func create_layer_button() -> Node:
	return Global.group_layer_button_node.instance()
