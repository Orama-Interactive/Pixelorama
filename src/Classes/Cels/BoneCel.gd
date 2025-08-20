class_name BoneCel
extends GroupCel
## A class for the properties of cels in BoneLayers.
## The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

const MIN_LENGTH: float = 5
const START_RADIUS: float = 6
const END_RADIUS: float = 4
const WIDTH: float = 2

# Variables set using serialize()
var gizmo_origin := Vector2.ZERO:
	set(value):
		if not gizmo_origin.is_equal_approx(value):
			var diff = value - gizmo_origin
			gizmo_origin = value
var gizmo_rotate_origin: float = 0:  ## Unit is Radians
	set(value):
		if not is_equal_approx(value, gizmo_rotate_origin):
			var diff = value - gizmo_rotate_origin
			gizmo_rotate_origin = value
var start_point := Vector2.ZERO:  ## This is relative to the gizmo_origin
	set(value):
		if not start_point.is_equal_approx(value):
			var diff = value - start_point
			start_point = value
			if should_update_children:
				update_children("start_point", diff)
var bone_rotation: float = 0:  ## This is relative to the gizmo_rotate_origin (Radians)
	set(value):
		if not is_equal_approx(value, bone_rotation):
			value = wrapf(value, -PI, PI)
			var diff = value - bone_rotation
			bone_rotation = value
			if should_update_children:
				update_children("bone_rotation", diff)
var gizmo_length: int = MIN_LENGTH + 5:
	set(value):
		if not is_equal_approx(value, gizmo_length) and value > int(MIN_LENGTH):
			if value < int(MIN_LENGTH):
				value = int(MIN_LENGTH)
			gizmo_length = value

var associated_layer: BoneLayer  ## only used in update_children()
var should_update_children := true

# Properties determined using above variables
var end_point: Vector2:  ## This is relative to the start_point
	get():
		return Vector2(gizmo_length, 0).rotated(gizmo_rotate_origin + bone_rotation)


## Converts coordinates that are relative to canvas get converted to position relative to
## gizmo_origin.
func rel_to_origin(pos: Vector2) -> Vector2:
	return pos - gizmo_origin


## Converts coordinates that are relative to canvas get converted to position relative to
## start point (the bigger circle).
func rel_to_start_point(pos: Vector2) -> Vector2:
	return pos - gizmo_origin - start_point


## Converts coordinates that are relative to gizmo_origin get converted to position relative to
## canvas.
func rel_to_canvas(pos: Vector2, is_rel_to_start_point := false) -> Vector2:
	var diff = start_point if is_rel_to_start_point else Vector2.ZERO
	return pos + gizmo_origin + diff


func _init(_opacity := 1.0, properties := {}) -> void:
	opacity = _opacity
	image_texture = ImageTexture.new()
	if not properties.is_empty():
		deserialize(properties)


func serialize(vector_to_string := true) -> Dictionary:
	# Make sure the name/types are the same as the variable names/types
	var data := super.serialize()
	if vector_to_string:
		data["gizmo_origin"] = var_to_str(gizmo_origin)
		data["gizmo_rotate_origin"] = var_to_str(gizmo_rotate_origin)
		data["start_point"] = var_to_str(start_point)
	else:
		data["gizmo_origin"] = gizmo_origin
		data["gizmo_rotate_origin"] = gizmo_rotate_origin
		data["start_point"] = start_point
	data["bone_rotation"] = bone_rotation
	data["gizmo_length"] = gizmo_length
	return data


func deserialize(data: Dictionary, update_children := false) -> void:
	if not update_children:
		should_update_children = false
	super.deserialize(data)
	# These need conversion before setting
	if typeof(data.get("gizmo_origin", gizmo_origin)) == TYPE_STRING:
		data["gizmo_origin"] = str_to_var(data.get("gizmo_origin", var_to_str(gizmo_origin)))

	if typeof(data.get("start_point", start_point)) == TYPE_STRING:
		data["start_point"] = str_to_var(data.get("start_point", start_point))

	if typeof(data.get("gizmo_rotate_origin", gizmo_rotate_origin)) == TYPE_STRING:
		data["gizmo_rotate_origin"] = str_to_var(
			data.get("gizmo_rotate_origin", gizmo_rotate_origin)
		)
	gizmo_origin = data.get("gizmo_origin", gizmo_origin)
	gizmo_rotate_origin = data.get("gizmo_rotate_origin", gizmo_rotate_origin)
	start_point = data.get("start_point", start_point)
	bone_rotation = data.get("bone_rotation", bone_rotation)
	gizmo_length = data.get("gizmo_length", gizmo_length)
	should_update_children = true


## Doesn't propagate to children
func reset(overrides := {}) -> void:
	var data := serialize()
	data["gizmo_origin"] = Vector2.ZERO
	data["start_point"] = Vector2.ZERO
	data["gizmo_rotate_origin"] = 0
	data["bone_rotation"] = 0
	data["gizmo_length"] = MIN_LENGTH
	overrides.merge(data)  # NOTE: duplicate keys are not copied over, unless overwrite is true.
	deserialize(overrides)


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
					var p_cel: BoneCel = project.frames[project.current_frame].cels[parent.index]
					var displacement := p_cel.rel_to_start_point(
						child_cel.rel_to_canvas(child_cel.start_point)
					)
					displacement = displacement.rotated(diff)
					child_cel.start_point = child_cel.rel_to_origin(
						p_cel.rel_to_canvas(start_point) + displacement
					)


func get_class_name() -> String:
	return "BoneCel"
