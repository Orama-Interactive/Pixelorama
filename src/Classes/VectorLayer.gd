class_name VectorLayer
extends BaseLayer
# A class for vector layer properties.


func _init(_project, _name := "") -> void:
	project = _project
	name = _name


# Overridden Methods:


func serialize() -> Dictionary:
	var dict = .serialize()
	dict["type"] = Global.LayerTypes.VECTOR
	dict["new_cels_linked"] = new_cels_linked
	var cels_serialized_vshapes := []
	# TODO: Consider serializing the cel data (including linked cels) from cels instead... (though it may make a bigger file)
	for frame in project.frames:
		var cel: VectorCel = frame.cels[index]
		cels_serialized_vshapes.append([])
		for vshape in cel.vshapes:
			cels_serialized_vshapes[-1].append(vshape.serialize())
	dict["vshapes"] = cels_serialized_vshapes
	return dict


func deserialize(dict: Dictionary) -> void:
	.deserialize(dict)
	new_cels_linked = dict.new_cels_linked
	for f in dict["vshapes"].size():
		var cel: VectorCel = project.frames[f].cels[index]
		for serialized_vshape in dict["vshapes"][f]:
			var vshape: BaseVectorShape
			match serialized_vshape["type"]:
				Global.VectorShapeTypes.TEXT:
					vshape = TextVectorShape.new()
			vshape.deserialize(serialized_vshape)


func set_name_to_default(number: int) -> void:
	name = tr("Vector") + " %s" % number


func new_empty_cel() -> BaseCel:
	return VectorCel.new()


#func can_layer_get_drawn() -> bool:
#	return is_visible_in_hierarchy() && !is_locked_in_hierarchy()


func instantiate_layer_button() -> Node:
	return Global.pixel_layer_button_node.instance()
