class_name ReferenceImage
extends Sprite2D
## A class describing a reference image

signal properties_changed

var project := Global.current_project
var shader := preload("res://src/Shaders/ReferenceImageShader.gdshader")
var image_path := ""
var filter := false:
	set(value):
		filter = value
		if value:
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		else:
			texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
var monochrome := false:
	set(value):
		monochrome = value
		if material:
			get_material().set_shader_parameter("monochrome", value)
var overlay_color := Color.WHITE:
	set(value):
		overlay_color = value
		modulate = value
		if material:
			get_material().set_shader_parameter("monchrome_color", value)
var color_clamping := 0.0:
	set(value):
		color_clamping = value
		if material:
			get_material().set_shader_parameter("clamping", value)

@onready var parent := get_parent()


func _ready() -> void:
	Global.project_switched.connect(_project_switched)
	project.reference_images.append(self)
	# Make this show behind parent because we want to use _draw() to draw over it
	show_behind_parent = true


func change_properties() -> void:
	properties_changed.emit()


## Resets the position and scale of the reference image.
func position_reset() -> void:
	position = project.size / 2.0
	rotation_degrees = 0.0
	if texture != null:
		scale = (
			Vector2.ONE
			* minf(
				float(project.size.x) / texture.get_width(),
				float(project.size.y) / texture.get_height()
			)
		)
	else:
		scale = Vector2.ONE


## Serialize details of the reference image.
func serialize() -> Dictionary:
	return {
		"x": position.x,
		"y": position.y,
		"scale_x": scale.x,
		"scale_y": scale.y,
		"rotation_degrees": rotation_degrees,
		"overlay_color_r": overlay_color.r,
		"overlay_color_g": overlay_color.g,
		"overlay_color_b": overlay_color.b,
		"overlay_color_a": overlay_color.a,
		"filter": filter,
		"monochrome": monochrome,
		"color_clamping": color_clamping,
		"image_path": image_path
	}


## Load details of the reference image from a dictionary.
## Be aware that new ReferenceImages are created via deserialization.
## This is because deserialization sets up some nice defaults.
func deserialize(d: Dictionary) -> void:
	overlay_color = Color(1, 1, 1, 0.5)
	if d.has("image_path"):
		# Note that reference images are referred to by path.
		# These images may be rather big.
		image_path = d["image_path"]
		var img := Image.new()
		if img.load(image_path) == OK:
			var itex := ImageTexture.create_from_image(img)
			texture = itex
		# Apply the silhouette shader
		var mat := ShaderMaterial.new()
		mat.shader = shader
		set_material(mat)

	# Now that the image may have been established...
	position_reset()
	if d.has("x"):
		position.x = d["x"]
	if d.has("y"):
		position.y = d["y"]
	if d.has("scale_x"):
		scale.x = d["scale_x"]
	if d.has("rotation_degrees"):
		rotation_degrees = d["rotation_degrees"]
	if d.has("scale_y"):
		scale.y = d["scale_y"]
	if d.has("overlay_color_r"):
		overlay_color.r = d["overlay_color_r"]
	if d.has("overlay_color_g"):
		overlay_color.g = d["overlay_color_g"]
	if d.has("overlay_color_b"):
		overlay_color.b = d["overlay_color_b"]
	if d.has("overlay_color_a"):
		overlay_color.a = d["overlay_color_a"]
	if d.has("filter"):
		filter = d["filter"]
	if d.has("monochrome"):
		monochrome = d["monochrome"]
	if d.has("color_clamping"):
		color_clamping = d["color_clamping"]
	change_properties()


## Useful for Web
func create_from_image(image: Image) -> void:
	var itex := ImageTexture.create_from_image(image)
	texture = itex
	position_reset()


func _project_switched() -> void:
	# Remove from the tree if it doesn't belong to the current project.
	# It will still be in memory though.
	if Global.current_project.reference_images.has(self):
		if not is_inside_tree():
			parent.add_child(self)
	else:
		if is_inside_tree():
			parent.remove_child(self)
