class_name ImageExtended
extends Image

## A custom [Image] class that implements support for indexed mode.
## Before implementing indexed mode, we just used the [Image] class.
## In indexed mode, each pixel is assigned to a number that references a palette color.
## This essentially means that the colors of the image are restricted to a specific palette,
## and they will automatically get updated when you make changes to that palette, or when
## you switch to a different one.

const TRANSPARENT := Color(0)
const SET_INDICES := preload("res://src/Shaders/SetIndices.gdshader")
const INDEXED_TO_RGB := preload("res://src/Shaders/IndexedToRGB.gdshader")

## If [code]true[/code], the image uses indexed mode.
var is_indexed := false
## The [Palette] the image is currently using for indexed mode.
var current_palette := Palettes.current_palette
## An [Image] that contains the index of each pixel of the main image for indexed mode.
## The indices are stored in the red channel of this image, by diving each index by 255.
## This means that there can be a maximum index size of 255. 0 means that the pixel is transparent.
var indices_image := Image.create_empty(1, 1, false, Image.FORMAT_R8)
## A [PackedColorArray] containing all of the colors of the [member current_palette].
var palette := PackedColorArray()


func _init() -> void:
	indices_image.fill(TRANSPARENT)
	Palettes.palette_selected.connect(select_palette)


## Equivalent of [method Image.create_empty], but returns [ImageExtended] instead.
## If [param _is_indexed] is [code]true[/code], the image that is being returned uses indexed mode.
static func create_custom(
	width: int, height: int, mipmaps: bool, format: Image.Format, _is_indexed := false
) -> ImageExtended:
	var new_image := ImageExtended.new()
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


## Equivalent of [method Image.copy_from], but also handles the logic necessary for indexed mode.
## If [param _is_indexed] is [code]true[/code], the image is set to be using indexed mode.
func copy_from_custom(image: Image, indexed := is_indexed) -> void:
	is_indexed = indexed
	copy_from(image)
	if is_indexed:
		resize_indices()
		select_palette("", false)
		convert_rgb_to_indexed()


## Selects a new palette to use in indexed mode.
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


## Updates [member palette] to contain the colors of [member current_palette].
func update_palette() -> void:
	if not is_instance_valid(current_palette):
		return
	if palette.size() != current_palette.colors_max:
		palette.resize(current_palette.colors_max)
	palette.fill(TRANSPARENT)
	for i in current_palette.colors:
		# Due to the decimal nature of the color values, some values get rounded off
		# unintentionally.
		# Even though the decimal values change, the HTML code remains the same after the change.
		# So we're using this trick to convert the values back to how they are shown in
		# the palette.
		palette[i] = Color(current_palette.colors[i].color.to_html())


## Displays the actual RGBA values of each pixel in the image from indexed mode.
func convert_indexed_to_rgb() -> void:
	if not is_indexed or not is_instance_valid(current_palette):
		return
	var palette_image := current_palette.convert_to_image(false)
	var palette_texture := ImageTexture.create_from_image(palette_image)
	var shader_image_effect := ShaderImageEffect.new()
	var indices_texture := ImageTexture.create_from_image(indices_image)
	var params := {"palette_texture": palette_texture, "indices_texture": indices_texture}
	shader_image_effect.generate_image(self, INDEXED_TO_RGB, params, get_size(), false)
	Global.canvas.queue_redraw()


## Automatically maps each color of the image's pixel to the closest color of the palette,
## by finding the palette color's index and storing it in [member indices_image].
func convert_rgb_to_indexed() -> void:
	if not is_indexed or not is_instance_valid(current_palette):
		return
	var palette_image := current_palette.convert_to_image(false)
	var palette_texture := ImageTexture.create_from_image(palette_image)
	var params := {
		"palette_texture": palette_texture, "rgb_texture": ImageTexture.create_from_image(self)
	}
	var shader_image_effect := ShaderImageEffect.new()
	shader_image_effect.generate_image(
		indices_image, SET_INDICES, params, indices_image.get_size(), false
	)
	convert_indexed_to_rgb()


## Resizes indices and calls [method convert_rgb_to_indexed] when the image's size changes
## and indexed mode is enabled.
func on_size_changed() -> void:
	if is_indexed:
		resize_indices()
		convert_rgb_to_indexed()


## Resizes [indices_image] to the image's size.
func resize_indices() -> void:
	indices_image.crop(get_width(), get_height())


## Equivalent of [method Image.set_pixel],
## but also handles the logic necessary for indexed mode.
func set_pixel_custom(x: int, y: int, color: Color) -> void:
	set_pixelv_custom(Vector2i(x, y), color)


## Equivalent of [method Image.set_pixelv],
## but also handles the logic necessary for indexed mode.
func set_pixelv_custom(point: Vector2i, color: Color, index_image_only := false) -> void:
	var new_color := color
	if is_indexed:
		var color_to_fill := TRANSPARENT
		var color_index := 0
		if not color.is_equal_approx(TRANSPARENT):
			if palette.has(color):
				color_index = palette.find(color)
				# If the color selected in the palette is the same then it should take prioity.
				var selected_index = Palettes.current_palette_get_selected_color_index(
					Tools.active_button
				)
				if selected_index != -1:
					if palette[selected_index].is_equal_approx(color):
						color_index = selected_index
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
			if not indices_image.get_pixelv(point).r8 == color_index + 1:
				indices_image.set_pixelv(point, Color((color_index + 1) / 255.0, 0, 0, 0))
			color_to_fill = palette[color_index]
			new_color = color_to_fill
		else:
			indices_image.set_pixelv(point, TRANSPARENT)
			new_color = TRANSPARENT
	if not index_image_only:
		set_pixelv(point, new_color)


## Finds the distance between colors [param c1] and [param c2].
func color_distance(c1: Color, c2: Color) -> float:
	var v1 := Vector4(c1.r, c1.g, c1.b, c1.a)
	var v2 := Vector4(c2.r, c2.g, c2.b, c2.a)
	return v2.distance_to(v1)


## Adds image data to a [param dict] [Dictionary]. Used for undo/redo.
func add_data_to_dictionary(dict: Dictionary, other_image: ImageExtended = null) -> void:
	# The order matters! Setting self's data first would make undo/redo appear to work incorrectly.
	if is_instance_valid(other_image):
		dict[other_image.indices_image] = indices_image.data
		dict[other_image] = data
	else:
		dict[indices_image] = indices_image.data
		dict[self] = data
