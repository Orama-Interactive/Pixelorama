class_name BoneCel
extends GroupCel
## A class for the properties of cels in GroupLayers.
## The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).


## This class is used/created to perform calculations
enum {NONE, DISPLACE, ROTATE, SCALE}  ## I planned to add scaling too but decided to give up
const InteractionDistance = 20
const MIN_LENGTH: float = 10
const START_RADIUS: float = 6
const END_RADIUS: float = 4
const WIDTH: float = 2
const DESELECT_WIDTH: float = 1

# Variables set using serialize()
var bone_name: String
var parent_bone_name: String:
	set(value):
		if value != parent_bone_name:
			parent_bone_name = value
			update_children(bone_name ,"parent_bone_name", false, "")
var gizmo_origin: Vector2:
	set(value):
		if value != gizmo_origin:
			var diff = value - gizmo_origin
			gizmo_origin = value
			update_children(bone_name ,"gizmo_origin", false, diff)
var gizmo_rotate_origin: float = 0:  ## Unit is Radians
	set(value):
		if value != gizmo_rotate_origin:
			var diff = value - gizmo_rotate_origin
			gizmo_rotate_origin = value
			update_children(bone_name ,"gizmo_rotate_origin", false, diff)
var start_point: Vector2:  ## This is relative to the gizmo_origin
	set(value):
		if value != start_point:
			var diff = value - start_point
			start_point = value
			update_children(bone_name ,"start_point", true, diff)
var bone_rotation: float = 0:  ## This is relative to the gizmo_rotate_origin (Radians)
	set(value):
		if value != bone_rotation:
			var diff = value - bone_rotation
			bone_rotation = value
			update_children(bone_name ,"bone_rotation", true, diff)
var gizmo_length: int:
	set(value):
		if gizmo_length != value and value > int(MIN_LENGTH):
			var diff = value - gizmo_length
			if value < int(MIN_LENGTH):
				value = int(MIN_LENGTH)
				diff = 0
			gizmo_length = value
			update_children(bone_name ,"gizmo_length", false, diff)

# Properties determined using above variables
var end_point: Vector2:  ## This is relative to the gizmo_origin
	get():
		return Vector2(gizmo_length, 0).rotated(gizmo_rotate_origin + bone_rotation)
var modify_mode := NONE
var ignore_rotation_hover := false


func _init(_opacity := 1.0) -> void:
	opacity = _opacity
	image_texture = ImageTexture.new()


func get_class_name() -> String:
	return "BoneCel"


static func generate_empty_data(
	cel_bone_name := "Invalid Name", cel_parent_bone_name := "Invalid Parent"
) -> Dictionary:
	# Make sure the name/types are the same as the variable names/types
	return {
		"bone_name": cel_bone_name,
		"parent_bone_name": cel_parent_bone_name,
		"gizmo_origin": Vector2.ZERO,
		"gizmo_rotate_origin": 0,
		"start_point": Vector2.ZERO,
		"bone_rotation": 0,
		"gizmo_length": MIN_LENGTH,
	}

func deserialize(data: Dictionary) -> void:
	var reference_data = generate_empty_data()
	for key in reference_data.keys():
		if get(key) != data.get(key, reference_data[key]):
			set(key, data.get(key, reference_data[key]))

func hover_mode(mouse_position: Vector2, camera_zoom) -> int:
	var local_mouse_pos = rel_to_origin(mouse_position)
	if (start_point).distance_to(local_mouse_pos) <= InteractionDistance / camera_zoom.x:
		return DISPLACE
	elif (
		(start_point + end_point).distance_to(local_mouse_pos)
		<= InteractionDistance / camera_zoom.x
	):
		if !ignore_rotation_hover:
			return SCALE
	elif is_close_to_segment(
		rel_to_start_point(mouse_position),
		InteractionDistance / camera_zoom.x,
		Vector2.ZERO, end_point
	):
		if !ignore_rotation_hover:
			return ROTATE
	return NONE

static func is_close_to_segment(
	pos: Vector2, detect_distance: float, s1: Vector2, s2: Vector2
) -> bool:
	var test_line := (s2 - s1).rotated(deg_to_rad(90)).normalized()
	var from_a := pos - test_line * detect_distance
	var from_b := pos + test_line * detect_distance
	if Geometry2D.segment_intersects_segment(from_a, from_b, s1, s2):
		return true
	return false

func rel_to_origin(pos: Vector2) -> Vector2:
	return pos - gizmo_origin

func rel_to_start_point(pos: Vector2) -> Vector2:
	return pos - gizmo_origin - start_point

func rel_to_global(pos: Vector2) -> Vector2:
	return pos + gizmo_origin

#func reset_bone(overrides := {}) -> Dictionary:
	#var reset_data = generate_empty_data(bone_name, parent_bone_name)
	#var connection_array := update_property.get_connections()
	#for connection: Dictionary in connection_array:
		#update_property.disconnect(connection["callable"])
	#for key in reset_data.keys():
		#if key in overrides.keys():
			#set(key, overrides[key])
			#reset_data[key] = overrides[key]
		#else:
			#set(key, reset_data[key])
	#for connection: Dictionary in connection_array:
		#update_property.connect(connection["callable"])
	#return reset_data


func update_children(parent_name: String, property: String, should_propagate: bool, diff):
	var project = Global.current_project
	var layer: BoneLayer = project.layers[project.current_layer]
	if not is_instance_valid(project):
		return
	if !should_propagate:
		# If ignore_render_once is true this probably means we are in the process of modifying
		# "Individual" properties of the bone and don't want them to propagate down the
		# chain.
		return
	## update first child (This will trigger a chain process)
	for child_layers in layer.get_children(false):
		if layer.get_layer_type() == Global.LayerTypes.BONE:
			var bone_cel: BoneCel = project.frames[project.current_frame].cels[layer.index]
			if bone_cel.get(property) == null:
				continue
			bone_cel.set(property, bone_cel.get(property) + diff)
			if property == "bone_rotation":
				var displacement := rel_to_start_point(
					bone_cel.rel_to_global(bone_cel.start_point)
				)
				displacement = displacement.rotated(diff)
				bone_cel.start_point = bone_cel.rel_to_origin(
					rel_to_global(start_point) + displacement
				)
