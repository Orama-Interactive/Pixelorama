class_name Cel3D
extends BaseCel


var viewport: SubViewport  ## SubViewport used by the cel.

## A [Dictionary] of the scene properties such as [param ambient_light_color] etc...
var scene_properties := {}
## Keys are the ids of all [Cel3DObject]'s present in the scene, and their corresponding values
## point to a [Dictionary] containing the properties of that [Cel3DObject].
var object_properties := {}
var current_object_id := 0  ## Its value never decreases.


## Class Constructor (used as [code]Cel3D.new(size, from_pxo, object_prop, scene_prop)[/code])
func _init(_viewport: SubViewport) -> void:
	viewport = _viewport
	var viewport_image := viewport.get_texture().get_image()
	#viewport_image.convert(Image.FORMAT_RGBA8)
	image_texture = ImageTexture.create_from_image(viewport_image)


func size_changed(new_size: Vector2i) -> void:
	viewport.size = new_size
	await RenderingServer.frame_post_draw
	var viewport_image := viewport.get_texture().get_image()
	#viewport_image.convert(Image.FORMAT_RGBA8)
	(image_texture as ImageTexture).update(viewport_image)

# Overridden methods


func get_image() -> Image:
	return image_texture.get_image()


func duplicate_cel() -> Cel3D:
	var new_cel := Cel3D.new(viewport)
	new_cel.opacity = opacity
	new_cel.z_index = z_index
	new_cel.user_data = user_data
	new_cel.ui_color = ui_color
	return new_cel


## Used to update the texture of the cel.
func update_texture(_undo := false) -> void:
	await RenderingServer.frame_post_draw
	var viewport_image := viewport.get_texture().get_image()
	#viewport_image.convert(Image.FORMAT_RGBA8)
	(image_texture as ImageTexture).update(viewport_image)
	texture_changed.emit()
	# TODO: Not a huge fan of this. Perhaps we should connect the texture_changed signal
	# of every cel type to the canvas and call queue_redraw there.
	Global.canvas.queue_redraw()


func serialize() -> Dictionary:
	var dict := super.serialize()
	var scene_properties_str := {}
	for prop in scene_properties:
		scene_properties_str[prop] = var_to_str(scene_properties[prop])
	var object_properties_str := {}
	for prop in object_properties:
		object_properties_str[prop] = var_to_str(object_properties[prop])
	dict["scene_properties"] = scene_properties_str
	dict["object_properties"] = object_properties_str
	return dict


func deserialize(dict: Dictionary) -> void:
	if dict.has("pxo_version"):
		if dict["pxo_version"] == 2:  # It's a 0.x project convert it to 1.0 format
			convert_0x_to_1x(dict)
	super.deserialize(dict)
	scene_properties = {}
	var scene_properties_str: Dictionary = dict.get("scene_properties", {})
	var objects_copy_str: Dictionary = dict.get("object_properties", {})
	for prop in scene_properties_str:
		scene_properties[prop] = str_to_var(scene_properties_str[prop])
	for object_id_as_str in objects_copy_str:
		if typeof(object_id_as_str) != TYPE_STRING:  # failsafe in case something has gone wrong
			return
		var id := int(object_id_as_str)
		if current_object_id < id:
			current_object_id = id
		object_properties[id] = str_to_var(objects_copy_str[object_id_as_str])
	if scene_properties.is_empty():
		var camera_transform := Transform3D()
		camera_transform.origin = Vector3(0, 0, 3)
		scene_properties = {
			"camera_transform": camera_transform,
			"camera_projection": Camera3D.PROJECTION_PERSPECTIVE,
			"camera_fov": 70.0,
			"camera_size": 1.0,
			"ambient_light_color": Color.BLACK,
			"ambient_light_energy": 1,
		}
	current_object_id += 1


## Used to convert 3d cels found in projects exported from a 0.x version to 1.x
func convert_0x_to_1x(dict: Dictionary) -> void:
	# Converting the scene dictionary
	var scene_dict: Dictionary = dict["scene_properties"]
	var old_transform_string = scene_dict["camera_transform"]
	scene_dict["camera_transform"] = (
		"Transform3D(" + old_transform_string.replace(" - ", ", ") + ")"
	)
	scene_dict["camera_projection"] = var_to_str(int(scene_dict["camera_projection"]))
	scene_dict["camera_fov"] = var_to_str(scene_dict["camera_fov"])
	scene_dict["camera_size"] = var_to_str(scene_dict["camera_size"])
	scene_dict["ambient_light_color"] = "Color(" + scene_dict["ambient_light_color"] + ")"
	scene_dict["ambient_light_energy"] = var_to_str(scene_dict["ambient_light_energy"])
	# Converting the objects dictionary
	var objects_copy_str: Dictionary = dict["object_properties"]
	for object_id_as_str in objects_copy_str.keys():
		var object_info = objects_copy_str[object_id_as_str]
		for object_property in object_info:
			if object_property == "id" or object_property == "type":
				object_info[object_property] = int(object_info[object_property])
			elif typeof(object_info[object_property]) != TYPE_STRING:
				continue
			elif "color" in object_property:  # Convert a String to a Color
				object_info[object_property] = str_to_var(
					"Color(" + object_info[object_property] + ")"
				)
			elif "transform" in object_property:  # Convert a String to a Transform
				var transform_string: String = object_info[object_property].replace(" - ", ", ")
				object_info[object_property] = str_to_var("Transform3D(" + transform_string + ")")
			elif "v2" in object_property:  # Convert a String to a Vector2
				object_info[object_property] = str_to_var("Vector2" + object_info[object_property])
			elif "size" in object_property or "center_offset" in object_property:
				# Convert a String to a Vector3
				object_info[object_property] = str_to_var("Vector3" + object_info[object_property])
		# Special operations to adjust gizmo
		# take note of origin
		var origin = object_info["transform"].origin
		match object_info["type"]:
			0:  # BOX
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE * 2)
				object_info["transform"].origin = origin
				object_info["mesh_size"] /= 2
			1:  # SPHERE
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE * 2)
				object_info["transform"].origin = origin
				object_info["mesh_radius"] /= 2
				object_info["mesh_height"] /= 2
			2:  # CAPSULE
				object_info["transform"] = (
					object_info["transform"]
					. scaled(Vector3.ONE * 2)
					. rotated_local(Vector3.LEFT, deg_to_rad(-90))
				)
				object_info["transform"].origin = origin
				object_info["mesh_radius"] /= 2
				object_info["mesh_height"] = (
					object_info["mesh_mid_height"] + object_info["mesh_radius"]
				)
			3:  # CYLINDER
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE * 2)
				object_info["transform"].origin = origin
				object_info["mesh_height"] /= 2
				object_info["mesh_bottom_radius"] /= 2
				object_info["mesh_top_radius"] /= 2
			4:  # PRISM
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE * 2)
				object_info["transform"].origin = origin
				object_info["mesh_size"] /= 2
			6:  # PLANE
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE * 2)
				object_info["transform"].origin = origin
				object_info["mesh_sizev2"] /= 2
			7:  # TEXT
				object_info["mesh_vertical_alignment"] = VERTICAL_ALIGNMENT_BOTTOM
				object_info["mesh_font_size"] = 12
				object_info["mesh_offset"] = Vector2.UP * 3
		objects_copy_str[object_id_as_str] = var_to_str(objects_copy_str[object_id_as_str])


func get_class_name() -> String:
	return "Cel3D"
