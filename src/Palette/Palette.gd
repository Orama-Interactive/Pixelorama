class_name Palette
extends Resource

const DEFAULT_WIDTH = 8
const DEFAULT_HEIGHT = 8

# Metadata
export var name: String = "Custom Palette"
export var comment: String = ""

# Grid size
export var width := DEFAULT_WIDTH
export var height := DEFAULT_HEIGHT

# Sparse colors dictionary - actual color position in the palette is determined by it's index
export var colors: Dictionary = {}

# How many colors fit in palette grid
export var colors_max := 0


func _init(init_name: String = "Custom Palette", init_width: int = DEFAULT_WIDTH, init_height: int = DEFAULT_HEIGHT, init_comment: String = "") -> void:
	name = init_name
	comment = init_comment
	width = init_width
	height = init_height
	colors_max = init_width * init_height
	colors = {}


func edit(new_name: String, new_width: int, new_height: int, new_comment: String) -> void:
	var old_width = width
	width = new_width
	height = new_height
	name = new_name
	comment = new_comment


	var old_colors_max = colors_max
	colors_max = width * height

	if colors_max < old_colors_max:
		# If size was reduced colors must be reindexed to fit into new smaller size
		reindex_colors_on_size_reduce(true)

	if old_width < new_width:
		# If width increases colors have to be reindexed so they keep same grid positions
		reindex_colors_on_width_increase(old_width)


# Iterates all colors from lowest index and reindexes them so they start at zero index
# Remove trailing removes all colors that are over colors_max limit and thus don't fit into grid
func reindex_colors_on_size_reduce(remove_trailing: bool) -> void:
	var sorted_colors_indexes = colors.keys()
	sorted_colors_indexes.sort()

	var new_index = 0
	for old_index in sorted_colors_indexes:
		# Color cannot fit into grid anymore - erase it
		if remove_trailing and new_index >= colors_max:
			colors.erase(old_index)

		# Move color to new lower index - erase it from it's original index
		elif new_index < old_index:
			colors[new_index] = colors[old_index]
			colors[new_index].index = new_index
			colors.erase(old_index)

		new_index += 1


# Adds difference of old and new width to color indexes
# so they remain on the same position as before resize
func reindex_colors_on_width_increase(old_width: int) -> void:
	var sorted_colors_indexes = colors.keys()
	sorted_colors_indexes.sort()

	var new_colors = {}
	for old_index in sorted_colors_indexes:
		var new_index: int = old_index + (width - old_width) * (old_index / old_width)
		new_colors[new_index ] = colors[old_index]

	colors = new_colors


# Adds new color to the first empty swatch
func add_color(new_color: Color, start_index: int = 0) -> void:
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


# Returns color at index or null if no color exists
func get_color(index: int):
	var palette_color = colors.get(index)
	if palette_color != null:
		return palette_color.color
	return null


# Changes color data
func set_color(index: int, new_color: Color) -> void:
	if self.colors.has(index):
		self.colors[index].color = new_color


# Removes a color at the specified index
func remove_color(index: int) -> void:
	colors.erase(index)


# Inserts a color to the specified index
# If index is already occupied move the original color to right
func insert_color(index: int, new_color: Color) -> void:
	var c := PaletteColor.new(new_color, index)
	# If insert happens on non empty swatch recursively move the original color
	# and every other color to it's right one swatch to right
	if colors.get(index) != null:
		move_right(index)
	colors[index] = c


# Recursive function that moves every color to right until one of them is moved to empty swatch
func move_right(index: int) -> void:
	# Moving colors to right would overflow the size of the palette so increase it's height automatically
	if index + 1 == colors_max:
		height += 1
		colors_max = width * height

	# If swatch to right to this color is not empty move that color right too
	if colors.get(index + 1) != null:
		move_right(index + 1)

	colors[index + 1] = colors.get(index)


# Swaps two colors
func swap_colors(from_index: int, to_index: int) -> void:
	var from_color = colors.get(from_index)
	var to_color = colors.get(to_index)

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


# Copies color
func copy_colors(from_index: int, to_index: int) -> void:
	# Only allow copy of existing colors
	if colors.has(from_index):
		colors[to_index] = colors[from_index].duplicate()
		colors[to_index].index = to_index


# True if all swatches are occupied
func is_full() -> bool:
	return self.colors.size() >= self.colors_max


# True if palette has no colors
func is_empty() -> bool:
	return self.colors.size() == 0


func has_color(color: Color) -> bool:
	for palette_color in colors.values():
		if palette_color.color == color:
			return true
	return false


# Sets name that is used to save the palette to disk
func set_resource_name(new_resource_name: String) -> void:
	# Store palette path name only with valid path characters
	resource_name = strip_unvalid_characters(new_resource_name)


static func strip_unvalid_characters(string_to_strip: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_]+")
	return regex.sub(string_to_strip, "", true)
