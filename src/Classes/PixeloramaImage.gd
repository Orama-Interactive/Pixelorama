class_name PixeloramaImage
extends Image

const TRANSPARENT := Color(0)

var current_palette := Palettes.current_palette
var indices := PackedInt32Array()
var palette := PackedColorArray()


func _init() -> void:
	resize_indices()
	select_palette("")
	Palettes.palette_selected.connect(select_palette)


static func create_custom(
	width: int, height: int, mipmaps: bool, format: Image.Format
) -> PixeloramaImage:
	var new_image := PixeloramaImage.new()
	new_image.crop(width, height)
	new_image.fill(TRANSPARENT)
	if mipmaps:
		new_image.generate_mipmaps()
	new_image.convert(format)
	new_image.resize_indices()
	new_image.select_palette("")
	return new_image


func copy_from_custom(image: Image) -> void:
	copy_from(image)
	update_palette()
	resize_indices()
	convert_rgb_to_indexed()


func select_palette(_name: String) -> void:
	current_palette = Palettes.current_palette
	if not is_instance_valid(current_palette):
		return
	update_palette()
	convert_indexed_to_rgb()
	if not current_palette.data_changed.is_connected(update_palette):
		current_palette.data_changed.connect(update_palette)
	if not current_palette.data_changed.is_connected(convert_indexed_to_rgb):
		current_palette.data_changed.connect(convert_indexed_to_rgb)


func update_palette() -> void:
	if palette.size() != current_palette.colors.size():
		palette.resize(current_palette.colors.size())
	for i in current_palette.colors:
		palette[i] = current_palette.colors[i].color


func convert_indexed_to_rgb() -> void:
	for x in get_width():
		for y in get_height():
			var index := indices[(x * get_height()) + y]
			if index > -1:
				if index >= palette.size():
					set_pixel(x, y, TRANSPARENT)
				else:
					set_pixel(x, y, palette[index])
			else:
				set_pixel(x, y, TRANSPARENT)
	Global.canvas.queue_redraw()


func convert_rgb_to_indexed() -> void:
	for x in get_width():
		for y in get_height():
			var color := get_pixel(x, y)
			set_pixel_custom(x, y, color)


func resize_indices() -> void:
	print(get_width(), " ", get_height(), " ", get_width() * get_height())
	indices.resize(get_width() * get_height())
	for i in indices.size():
		indices[i] = -1


func set_pixel_custom(x: int, y: int, color: Color) -> void:
	set_pixelv_custom(Vector2i(x, y), color)


func set_pixelv_custom(point: Vector2i, color: Color) -> void:
	var color_to_fill := TRANSPARENT
	var color_index := -1
	if not color.is_equal_approx(TRANSPARENT):
		if palette.has(color):
			color_index = palette.find(color)
		else:  # Find the most similar color
			if not is_zero_approx(palette[0].a):
				color_index = 0
			var smaller_distance := color_distance(color, palette[0])
			for i in palette.size():
				var swatch := palette[i]
				if is_zero_approx(swatch.a):  # Skip transparent colors
					continue
				var dist := color_distance(color, swatch)
				if dist < smaller_distance:
					smaller_distance = dist
					color_index = i
	indices[(point.x * get_height()) + point.y] = color_index
	if color_index > -1:
		color_to_fill = palette[color_index]
	set_pixelv(point, color_to_fill)


func color_distance(c1: Color, c2: Color) -> float:
	var v1 := Vector4(c1.r, c1.g, c1.b, c1.a)
	var v2 := Vector4(c2.r, c2.g, c2.b, c2.a)
	return v2.distance_to(v1)


func blit_rect_custom(src: Image, src_rect: Rect2i, origin: Vector2i) -> void:
	blit_rect(src, src_rect, origin)
	convert_rgb_to_indexed()
