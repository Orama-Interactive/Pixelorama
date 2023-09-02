class_name ReferenceImage
extends Sprite2D
## A class describing a reference image

signal properties_changed

var project := Global.current_project

var shader := preload("res://src/Shaders/SilhouetteShader.gdshader")

var image_path := ""
var filter := false
var silhouette := false


func _ready() -> void:
	project.reference_images.append(self)


func change_properties() -> void:
	properties_changed.emit()


## Resets the position and scale of the reference image.
func position_reset() -> void:
	position = project.size / 2.0
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
		"modulate_r": modulate.r,
		"modulate_g": modulate.g,
		"modulate_b": modulate.b,
		"modulate_a": modulate.a,
		"filter": filter,
		"silhouette": silhouette,
		"image_path": image_path
	}


## Load details of the reference image from a dictionary.
## Be aware that new ReferenceImages are created via deserialization.
## This is because deserialization sets up some nice defaults.
func deserialize(d: Dictionary) -> void:
	modulate = Color(1, 1, 1, 0.5)
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
		# TODO: Lsbt - Add a option in prefrences to customize the color
		# This color is almost black because it is less harsh
		mat.set_shader_parameter("silhouette_color", Color(0.069, 0.069326, 0.074219))
		set_material(mat)

	# Now that the image may have been established...
	position_reset()
	if d.has("x"):
		position.x = d["x"]
	if d.has("y"):
		position.y = d["y"]
	if d.has("scale_x"):
		scale.x = d["scale_x"]
	if d.has("scale_y"):
		scale.y = d["scale_y"]
	if d.has("modulate_r"):
		modulate.r = d["modulate_r"]
	if d.has("modulate_g"):
		modulate.g = d["modulate_g"]
	if d.has("modulate_b"):
		modulate.b = d["modulate_b"]
	if d.has("modulate_a"):
		modulate.a = d["modulate_a"]
	if d.has("filter"):
		filter = d["filter"]
	if d.has("silhouette"):
		get_material().set_shader_parameter("show_silhouette", d["silhouette"])
	change_properties()


## Useful for Web
func create_from_image(image: Image) -> void:
	var itex := ImageTexture.create_from_image(image)
	texture = itex
	position_reset()
