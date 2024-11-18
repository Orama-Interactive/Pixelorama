class_name PixeloramaImage
extends Image

const TRANSPARENT := Color(0)
const SET_INDICES := preload("res://src/Shaders/SetIndices.gdshader")
const INDEXED_TO_RGB := preload("res://src/Shaders/IndexedToRGB.gdshader")

var is_indexed := false
var current_palette := Palettes.current_palette
var indices_image := Image.create_empty(1, 1, false, Image.FORMAT_R8)
var palette := PackedColorArray()


func _init() -> void:
	indices_image.fill(TRANSPARENT)
	Palettes.palette_selected.connect(select_palette)


static func create_custom(
	width: int, height: int, mipmaps: bool, format: Image.Format, _is_indexed := false
) -> PixeloramaImage:
	var new_image := PixeloramaImage.new()
	new_image.crop(width, height)
	if mipmaps:
		new_image.generate_mipmaps()
	new_image.convert(format)
	new_image.fill(TRANSPARENT)
	new_image.is_indexed = _is_indexed
	if new_image.is_indexed:
		new_image.resize_indices()
		new_image.select_palette("", false)
	return new_image


func copy_from_custom(image: Image, indexed := is_indexed) -> void:
	is_indexed = indexed
	copy_from(image)
	if is_indexed:
		resize_indices()
		select_palette("", false)
		convert_rgb_to_indexed()


func select_palette(_name: String, convert_to_rgb := true) -> void:
	current_palette = Palettes.current_palette
	if not is_instance_valid(current_palette) or not is_indexed:
		return
	update_palette()
	if not current_palette.data_changed.is_connected(update_palette):
		current_palette.data_changed.connect(update_palette)
	if not current_palette.data_changed.is_connected(convert_indexed_to_rgb):
		current_palette.data_changed.connect(convert_indexed_to_rgb)
	if convert_to_rgb:
		convert_indexed_to_rgb()


func update_palette() -> void:
	if palette.size() != current_palette.colors.size():
		palette.resize(current_palette.colors.size())
	for i in current_palette.colors:
		palette[i] = current_palette.colors[i].color


func convert_indexed_to_rgb() -> void:
	if not is_indexed:
		return
	var palette_image := Palettes.current_palette.convert_to_image()
	var palette_texture := ImageTexture.create_from_image(palette_image)
	var shader_image_effect := ShaderImageEffect.new()
	var indices_texture := ImageTexture.create_from_image(indices_image)
	var params := {"palette_texture": palette_texture, "indices_texture": indices_texture}
	shader_image_effect.generate_image(self, INDEXED_TO_RGB, params, get_size(), false)
	Global.canvas.queue_redraw()


func convert_rgb_to_indexed() -> void:
	if not is_indexed:
		return
	var palette_image := Palettes.current_palette.convert_to_image()
	var palette_texture := ImageTexture.create_from_image(palette_image)
	var params := {
		"palette_texture": palette_texture, "rgb_texture": ImageTexture.create_from_image(self)
	}
	var shader_image_effect := ShaderImageEffect.new()
	shader_image_effect.generate_image(
		indices_image, SET_INDICES, params, indices_image.get_size(), false
	)
	convert_indexed_to_rgb()


func on_size_changed() -> void:
	if is_indexed:
		resize_indices()
		convert_rgb_to_indexed()


func resize_indices() -> void:
	indices_image.crop(get_width(), get_height())


func set_pixel_custom(x: int, y: int, color: Color) -> void:
	set_pixelv_custom(Vector2i(x, y), color)


func set_pixelv_custom(point: Vector2i, color: Color) -> void:
	var new_color := color
	if is_indexed:
		var color_to_fill := TRANSPARENT
		var color_index := 0
		if not color.is_equal_approx(TRANSPARENT):
			if palette.has(color):
				color_index = palette.find(color)
			else:  # Find the most similar color
				var smaller_distance := color_distance(color, palette[0])
				for i in palette.size():
					var swatch := palette[i]
					if is_zero_approx(swatch.a):  # Skip transparent colors
						continue
					var dist := color_distance(color, swatch)
					if dist < smaller_distance:
						smaller_distance = dist
						color_index = i
			indices_image.set_pixelv(point, Color((color_index + 1) / 255.0, 0, 0, 0))
			color_to_fill = palette[color_index]
			new_color = color_to_fill
		else:
			indices_image.set_pixelv(point, TRANSPARENT)
			new_color = TRANSPARENT
	set_pixelv(point, new_color)


func color_distance(c1: Color, c2: Color) -> float:
	var v1 := Vector4(c1.r, c1.g, c1.b, c1.a)
	var v2 := Vector4(c2.r, c2.g, c2.b, c2.a)
	return v2.distance_to(v1)


## Adds image data to a [param dict] [Dictionary]. Used for undo/redo.
func add_data_to_dictionary(dict: Dictionary, other_image: PixeloramaImage = null) -> void:
	# The order matters! Setting self's data first would make undo/redo appear to work incorrectly.
	if is_instance_valid(other_image):
		dict[other_image.indices_image] = indices_image.data
		dict[other_image] = data
	else:
		dict[indices_image] = indices_image.data
		dict[self] = data
