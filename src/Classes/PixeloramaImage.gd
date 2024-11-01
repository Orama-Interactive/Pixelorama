class_name PixeloramaImage
extends Image

const TRANSPARENT := Color(0)

var current_palette := Palettes.current_palette
var indices := PackedInt32Array()
var palette := PackedColorArray()


func _init() -> void:
	select_palette("")
	Palettes.palette_selected.connect(select_palette)
	resize_indices()


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


func select_palette(_name: String) -> void:
	current_palette = Palettes.current_palette
	if not is_instance_valid(current_palette):
		return
	update_indices()
	if not current_palette.data_changed.is_connected(update_indices):
		current_palette.data_changed.connect(update_indices)


func update_indices() -> void:
	if palette.size() != current_palette.colors.size():
		palette.resize(current_palette.colors.size())
	for i in current_palette.colors:
		palette[i] = current_palette.colors[i].color
	for x in get_width():
		for y in get_height():
			var index := indices[(x * get_width()) + y]
			if index > -1:
				if index >= palette.size():
					set_pixel(x, y, TRANSPARENT)
				else:
					set_pixel(x, y, palette[index])
			else:
				set_pixel(x, y, TRANSPARENT)
	Global.canvas.queue_redraw()


func resize_indices() -> void:
	print(get_width() * get_height())
	indices.resize(get_width() * get_height())
	for i in indices.size():
		indices[i] = -1


func set_pixel_custon(x: int, y: int, color: Color) -> void:
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
	indices[(point.x * get_width()) + point.y] = color_index
	if color_index > -1:
		color_to_fill = palette[color_index]
	set_pixelv(point, color_to_fill)


func color_distance(c1: Color, c2: Color) -> float:
	var v1 := Vector4(c1.r, c1.g, c1.b, c1.a)
	var v2 := Vector4(c2.r, c2.g, c2.b, c2.a)
	return v2.distance_to(v1)
