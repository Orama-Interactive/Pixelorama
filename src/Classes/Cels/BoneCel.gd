class_name BoneCel
extends GroupCel
## A class for the properties of cels in BoneLayers.
## The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

const MIN_LENGTH: float = 10
const START_RADIUS: float = 6
const END_RADIUS: float = 4
const WIDTH: float = 2

# Variables set using serialize()
var gizmo_origin := Vector2.ZERO:
	set(value):
		if value != gizmo_origin:
			var diff = value - gizmo_origin
			gizmo_origin = value
var gizmo_rotate_origin: float = 0:  ## Unit is Radians
	set(value):
		if value != gizmo_rotate_origin:
			var diff = value - gizmo_rotate_origin
			gizmo_rotate_origin = value
var start_point := Vector2.ZERO:  ## This is relative to the gizmo_origin
	set(value):
		if value != start_point:
			var diff = value - start_point
			start_point = value
			if should_update_children:
				update_children("start_point", diff)
var bone_rotation: float = 0:  ## This is relative to the gizmo_rotate_origin (Radians)
	set(value):
		if value != bone_rotation:
			var diff = value - bone_rotation
			bone_rotation = value
			if should_update_children:
				update_children("bone_rotation", diff)
var gizmo_length: int = MIN_LENGTH:
	set(value):
		if gizmo_length != value and value > int(MIN_LENGTH):
			if value < int(MIN_LENGTH):
				value = int(MIN_LENGTH)
			gizmo_length = value

var associated_layer: BoneLayer   ## only used in update_children()
var should_update_children := true

# Properties determined using above variables
var end_point: Vector2:  ## This is relative to the gizmo_origin
	get():
		return Vector2(gizmo_length, 0).rotated(gizmo_rotate_origin + bone_rotation)


func _init(_opacity := 1.0, properties := {}) -> void:
	opacity = _opacity
	image_texture = ImageTexture.new()
	if not properties.is_empty():
		deserialize(properties)


func serialize() -> Dictionary:
	# Make sure the name/types are the same as the variable names/types
	var data := super.serialize()
	data["gizmo_origin"] = var_to_str(gizmo_origin)
	data["gizmo_rotate_origin"] = var_to_str(gizmo_rotate_origin)
	data["start_point"] = var_to_str(start_point)
	data["bone_rotation"] = bone_rotation
	data["gizmo_length"] = gizmo_length
	return data


func deserialize(data: Dictionary, update_children := false) -> void:
	if not update_children:
		should_update_children = false
	super.deserialize(data)
	if typeof(data.get("gizmo_origin", gizmo_origin)) == TYPE_STRING:  # sanity check
		gizmo_origin = str_to_var(data.get("gizmo_origin", var_to_str(gizmo_origin)))
		gizmo_rotate_origin = str_to_var(
			data.get("gizmo_rotate_origin", var_to_str(gizmo_rotate_origin))
		)
		start_point = str_to_var(data.get("start_point", var_to_str(start_point)))
	bone_rotation = data.get("bone_rotation", bone_rotation)
	gizmo_length = data.get("gizmo_length", gizmo_length)
	should_update_children = true


func update_children(property: String, diff):
	var project = Global.current_project
	# NOTE: The update is done only on the cels that are part of the current frame so
	# the approach to get associated layer should be enough
	if associated_layer:  # sanity check
		if project.frames[project.current_frame].cels[associated_layer.index] != self:
			associated_layer = null
	if !associated_layer:
		var layer_idx = project.frames[project.current_frame].cels.find(self)
		if layer_idx != -1:
			associated_layer = project.layers[layer_idx]

	if not is_instance_valid(project) or !associated_layer:
		return
	## update first child (This will trigger a chain process)
	for child_layer in associated_layer.get_child_bones(false):
		if child_layer.get_layer_type() == Global.LayerTypes.BONE:
			var child_cel: BoneCel = project.frames[project.current_frame].cels[child_layer.index]
			if child_cel.get(property) == null:
				continue
			child_cel.set(property, child_cel.get(property) + diff)
			if property == "bone_rotation":
				var parent: BoneLayer = BoneLayer.get_parent_bone(child_layer)
				if parent:
					var displacement := parent.rel_to_start_point(
						child_layer.rel_to_global(child_cel.start_point)
					)
					displacement = displacement.rotated(diff)
					child_cel.start_point = child_layer.rel_to_origin(
						BoneLayer.get_parent_bone(child_layer).rel_to_global(start_point) + displacement
					)


func get_class_name() -> String:
	return "BoneCel"
