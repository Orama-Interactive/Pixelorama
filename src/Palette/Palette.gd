class_name Palette
extends RefCounted

const DEFAULT_WIDTH := 8
const DEFAULT_HEIGHT := 8

# Metadata
var name := "Custom Palette"
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
	var color := Color.TRANSPARENT
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
	width = new_width
	height = new_height
	name = new_name
	comment = new_comment

	var old_colors_max := colors_max
	colors_max = width * height

	if colors_max < old_colors_max:
		# If size was reduced colors must be reindexed to fit into new smaller size
		reindex_colors_on_size_reduce(true)

	if old_width < new_width and colors_max > old_colors_max:
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
	if data.has("comment"):
		comment = data.comment
	if data.has("colors"):
		for color_data in data.colors:
			var color := str_to_var("Color" + color_data["color"]) as Color
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
	var sorted_colors_indexes := colors.keys()
	sorted_colors_indexes.sort()
	var new_colors := {}
	for old_index: int in sorted_colors_indexes:
		var new_index := old_index + (width - old_width) * (old_index / old_width)
		new_colors[new_index] = colors[old_index]

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


## Removes a color at the specified index
func remove_color(index: int) -> void:
	colors.erase(index)


## Inserts a color to the specified index
## If index is already occupied move the original color to right
func insert_color(index: int, new_color: Color) -> void:
	var c := PaletteColor.new(new_color, index)
	# If insert happens on non empty swatch recursively move the original color
	# and every other color to its right one swatch to right
	if colors[index] != null:
		move_right(index)
	colors[index] = c


## Recursive function that moves every color to right until one of them is moved to empty swatch
func move_right(index: int) -> void:
	# Moving colors to right would overflow the size of the palette
	# so increase its height automatically
	if index + 1 == colors_max:
		height += 1
		colors_max = width * height

	# If swatch to right to this color is not empty move that color right too
	if colors[index + 1] != null:
		move_right(index + 1)

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


## Copies color
func copy_colors(from_index: int, to_index: int) -> void:
	# Only allow copy of existing colors
	if colors[from_index] != null:
		colors[to_index] = colors[from_index].duplicate()
		colors[to_index].index = to_index


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


func convert_to_image() -> Image:
	var image := Image.create(colors_max, 1, false, Image.FORMAT_RGBA8)
	for i in colors_max:
		if colors.has(i):
			image.set_pixel(i, 0, colors[i].color)
	return image
