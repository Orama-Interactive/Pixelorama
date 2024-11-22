class_name Palette
extends RefCounted

signal data_changed

const DEFAULT_WIDTH := 8
const DEFAULT_HEIGHT := 8

# Metadata
var name := "Custom Palette":
	set(value):
		name = value.strip_edges()
var comment := ""
var path := ""

## The width of the grid
var width := DEFAULT_WIDTH
## The height of the grid
var height := DEFAULT_HEIGHT
## Sparse colors dictionary of [int] and [PaletteColor]
## Actual color position in the palette is determined by its index
var colors := {}
## How many colors fit in palette grid
var colors_max := 0


class PaletteColor:
	var color := Color(0, 0, 0, 0)
	var index := -1

	func _init(init_color := Color.BLACK, init_index := -1) -> void:
		color = init_color
		index = init_index

	func duplicate() -> PaletteColor:
		return PaletteColor.new(color, index)

	func serialize() -> Dictionary:
		return {"color": color, "index": index}

	func deserialize(dict: Dictionary) -> void:
		if dict.has("color"):
			color = dict["color"]
		if dict.has("index"):
			color = dict["index"]


func _init(
	_name := "Custom Palette", _width := DEFAULT_WIDTH, _height := DEFAULT_HEIGHT, _comment := ""
) -> void:
	name = _name
	comment = _comment
	width = _width
	height = _height
	colors_max = _width * _height
	colors = {}


func edit(new_name: String, new_width: int, new_height: int, new_comment: String) -> void:
	var old_width := width
	var old_height := height
	width = new_width
	height = new_height
	name = new_name
	comment = new_comment

	var old_colors_max := colors_max
	colors_max = width * height

	if colors_max < old_colors_max:
		# If size was reduced colors must be reindexed to fit into new smaller size
		reindex_colors_on_size_reduce(true)

	if old_width < new_width and height >= old_height:
		# If width increases colors have to be reindexed so they keep same grid positions
		# unless the height has become smaller and we have to re-position the colors
		# so that they won't get erased
		reindex_colors_on_width_increase(old_width)


func duplicate() -> Palette:
	var new_palette := Palette.new(name, width, height, comment)
	var new_colors := colors.duplicate(true)
	new_palette.colors = new_colors
	return new_palette


func _serialize() -> String:
	var serialize_data := {"comment": comment, "colors": [], "width": width, "height": height}
	for color in colors:
		serialize_data.colors.push_back(colors[color].serialize())

	return JSON.stringify(serialize_data, " ")


func deserialize(json_string: String) -> void:
	var test_json_conv := JSON.new()
	var err := test_json_conv.parse(json_string)
	if err != OK:  # If parse has errors
		printerr("JSON palette import error")
		printerr("Error: ", err)
		printerr("Error Line: ", test_json_conv.get_error_line())
		printerr("Error String: ", test_json_conv.get_error_message())
		return

	var data = test_json_conv.get_data()
	if not typeof(data) == TYPE_DICTIONARY:
		return
	deserialize_from_dictionary(data)


func deserialize_from_dictionary(data: Dictionary) -> void:
	if data.has("comment"):
		comment = data.comment
	if data.has("colors"):
		for color_data in data.colors:
			var color: Color
			if typeof(color_data["color"]) == TYPE_STRING:
				color = str_to_var("Color" + color_data["color"])
			elif typeof(color_data["color"]) == TYPE_COLOR:
				color = color_data["color"]
			var index := color_data["index"] as int
			var palette_color := PaletteColor.new(color, index)
			colors[index] = palette_color
	if data.has("width"):
		width = data.width
	if data.has("height"):
		height = data.height
	colors_max = width * height


func save_to_file() -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not is_instance_valid(file):
		return FileAccess.get_open_error()
	file.store_string(_serialize())
	file.close()
	return OK


## Iterates all colors from lowest index and reindexes them so they start at zero index
## Remove trailing removes all colors that are over colors_max limit and thus don't fit into grid
func reindex_colors_on_size_reduce(remove_trailing: bool) -> void:
	var sorted_colors_indexes := colors.keys()
	sorted_colors_indexes.sort()
	var new_index := 0
	for old_index: int in sorted_colors_indexes:
		# Color cannot fit into grid anymore - erase it
		if remove_trailing and new_index >= colors_max:
			colors.erase(old_index)

		# Move color to new lower index - erase it from its original index
		elif new_index < old_index:
			colors[new_index] = colors[old_index]
			colors[new_index].index = new_index
			colors.erase(old_index)

		new_index += 1


## Adds difference of old and new width to color indexes
## so they remain on the same position as before resize
func reindex_colors_on_width_increase(old_width: int) -> void:
	var sorted_colors_indices := colors.keys()
	sorted_colors_indices.sort()
	var new_colors := {}
	for old_index: int in sorted_colors_indices:
		var new_index := old_index + (width - old_width) * (old_index / old_width)
		new_colors[new_index] = colors[old_index]
		new_colors[new_index].index = new_index

	colors = new_colors


## Adds new color to the first empty swatch
func add_color(new_color: Color, start_index := 0) -> void:
	if start_index >= colors_max:
		return

	# If palette is full automatically increase the palette height
	if is_full():
		height += 1

	# Find the first empty index since start index and insert a new color
	for i in range(start_index, colors_max):
		if not colors.has(i):
			colors[i] = PaletteColor.new(new_color, i)
			break
	data_changed.emit()


## Returns color at index or null if no color exists
func get_color(index: int):
	var palette_color: PaletteColor = colors.get(index)
	if palette_color != null:
		return palette_color.color
	return null


## Changes color data
func set_color(index: int, new_color: Color) -> void:
	if colors.has(index):
		colors[index].color = new_color
		data_changed.emit()


## Removes a color at the specified index
func remove_color(index: int) -> void:
	colors.erase(index)
	data_changed.emit()


## Inserts a color to the specified index
## If index is already occupied move the original color to right
func insert_color(index: int, new_color: Color) -> void:
	var c := PaletteColor.new(new_color, index)
	# If insert happens on non empty swatch recursively move the original color
	# and every other color to its right one swatch to right
	if colors.has(index):
		_move_right(index)
	colors[index] = c
	data_changed.emit()


## Recursive function that moves every color to right until one of them is moved to empty swatch
func _move_right(index: int) -> void:
	# Moving colors to right would overflow the size of the palette
	# so increase its height automatically
	if index + 1 == colors_max:
		height += 1
		colors_max = width * height

	# If swatch to right to this color is not empty move that color right too
	if colors.has(index + 1):
		_move_right(index + 1)

	colors[index + 1] = colors[index]


## Swaps two colors
func swap_colors(from_index: int, to_index: int) -> void:
	var from_color: PaletteColor = colors.get(from_index)
	var to_color: PaletteColor = colors.get(to_index)

	if not from_color and to_color:
		colors[from_index] = to_color
		colors[from_index].index = from_index
		colors.erase(to_index)
	elif from_color and not to_color:
		colors[to_index] = from_color
		colors[to_index].index = to_index
		colors.erase(from_index)
	elif from_color and to_color:
		colors[to_index] = from_color
		colors[to_index].index = to_index
		colors[from_index] = to_color
		colors[from_index].index = from_index
	data_changed.emit()


## Copies color
func copy_colors(from_index: int, to_index: int) -> void:
	# Only allow copy of existing colors
	if colors[from_index] != null:
		colors[to_index] = colors[from_index].duplicate()
		colors[to_index].index = to_index
	data_changed.emit()


func reverse_colors() -> void:
	var reversed_colors := colors.values()
	reversed_colors.reverse()
	colors.clear()
	for i in reversed_colors.size():
		reversed_colors[i].index = i
		colors[i] = reversed_colors[i]
	data_changed.emit()


func sort(option: Palettes.SortOptions) -> void:
	var sorted_colors := colors.values()
	var sort_method: Callable
	match option:
		Palettes.SortOptions.HUE:
			sort_method = func(a: PaletteColor, b: PaletteColor): return a.color.h < b.color.h
		Palettes.SortOptions.SATURATION:
			sort_method = func(a: PaletteColor, b: PaletteColor): return a.color.s < b.color.s
		Palettes.SortOptions.VALUE:
			sort_method = func(a: PaletteColor, b: PaletteColor): return a.color.v < b.color.v
		Palettes.SortOptions.LIGHTNESS:
			# Code inspired from:
			# gdlint: ignore=max-line-length
			# https://github.com/bottosson/bottosson.github.io/blob/master/misc/colorpicker/colorconversion.js#L519
			sort_method = func(a: PaletteColor, b: PaletteColor):
				# function that returns OKHSL lightness
				var lum: Callable = func(c: Color):
					var l = 0.4122214708 * (c.r) + 0.5363325363 * (c.g) + 0.0514459929 * (c.b)
					var m = 0.2119034982 * (c.r) + 0.6806995451 * (c.g) + 0.1073969566 * (c.b)
					var s = 0.0883024619 * (c.r) + 0.2817188376 * (c.g) + 0.6299787005 * (c.b)
					var l_cr = pow(l, 1 / 3.0)
					var m_cr = pow(m, 1 / 3.0)
					var s_cr = pow(s, 1 / 3.0)
					var oklab_l = 0.2104542553 * l_cr + 0.7936177850 * m_cr - 0.0040720468 * s_cr
					# calculating toe
					var k_1 = 0.206
					var k_2 = 0.03
					var k_3 = (1 + k_1) / (1 + k_2)
					return (
						0.5
						* (
							k_3 * oklab_l
							- k_1
							+ sqrt(
								(
									(k_3 * oklab_l - k_1) * (k_3 * oklab_l - k_1)
									+ 4 * k_2 * k_3 * oklab_l
								)
							)
						)
					)
				return lum.call(a.color.srgb_to_linear()) < lum.call(b.color.srgb_to_linear())
		Palettes.SortOptions.RED:
			sort_method = func(a: PaletteColor, b: PaletteColor): return a.color.r < b.color.r
		Palettes.SortOptions.GREEN:
			sort_method = func(a: PaletteColor, b: PaletteColor): return a.color.g < b.color.g
		Palettes.SortOptions.BLUE:
			sort_method = func(a: PaletteColor, b: PaletteColor): return a.color.b < b.color.b
		Palettes.SortOptions.ALPHA:
			sort_method = func(a: PaletteColor, b: PaletteColor): return a.color.a < b.color.a
	sorted_colors.sort_custom(sort_method)
	colors.clear()
	for i in sorted_colors.size():
		sorted_colors[i].index = i
		colors[i] = sorted_colors[i]
	data_changed.emit()


## True if all swatches are occupied
func is_full() -> bool:
	return colors.size() >= colors_max


## True if palette has no colors
func is_empty() -> bool:
	return colors.size() == 0


func has_theme_color(color: Color) -> bool:
	for palette_color in colors.values():
		if palette_color.color == color:
			return true
	return false


static func strip_unvalid_characters(string_to_strip: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_]+")
	return regex.sub(string_to_strip, "", true)


func convert_to_image(crop_image := true) -> Image:
	var image := Image.create(colors_max, 1, false, Image.FORMAT_RGBA8)
	for i in colors_max:
		if colors.has(i):
			image.set_pixel(i, 0, Color(colors[i].color.to_html()))
	if crop_image:
		image.copy_from(image.get_region(image.get_used_rect()))
	return image
