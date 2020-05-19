class_name Palette
extends Reference


var name : String = "Custom_Palette"
# Its purpose is to store pallete source path to enable removing it in the future.
var source_path : String
var colors : Array = []
var comments : String = ""
var editable : bool = true


func get_class() -> String:
	return "Palette"


func is_class(_name : String) -> bool:
	return _name == "Palette" or .is_class(_name)


func insert_color(index : int, new_color : Color, _name : String = "no name") -> void:
	if index <= colors.size():
		var c := PaletteColor.new(new_color, _name)
		colors.insert(index, c)


func add_color(new_color : Color, _name : String = "no name") -> void:
	var c := PaletteColor.new(new_color, _name)
	colors.push_back(c)


func remove_color(index : int) -> void:
	if index < colors.size():
		colors.remove(index)


func move_color(from : int, to : int) -> void:
	if from < colors.size() && to < colors.size():
		var c : PaletteColor = colors[from]
		remove_color(from)
		insert_color(to, c.color, c.name)


func get_color(index : int) -> Color:
	var result := Color.black

	if index < colors.size():
		result = colors[index].color

	return result


func set_color(index : int, new_color : Color) -> void:
	if index < colors.size():
		colors[index].color = new_color


func get_color_data(index : int) -> String:
	var result := ""

	if index < colors.size():
		result = colors[index].data

	return result


func has_color(color: Color) -> bool:
	for palette_color in colors:
		if palette_color.color == color:
			return true
	return false


func set_color_data(index : int, new_color : String) -> void:
	if index < colors.size():
		colors[index].data = new_color


func get_color_name(index : int) -> String:
	var result = ""

	if index < colors.size():
		result = colors[index].name

	return result


func set_color_name(index : int, new_name : String) -> void:
	if index < colors.size():
		colors[index].name = new_name


func save_to_file(path : String) -> void:
	var file = File.new()
	file.open(path, File.WRITE)
	file.store_string(_serialize())
	file.close()
	source_path = path


func duplicate(): # -> Palette
	var copy = get_script().new() # : Palette
	copy.name = name
	copy.comments = comments
	copy.editable = editable
	for color in colors:
		copy.colors.push_back(color.duplicate())
	return copy


func _serialize() -> String:
	var result = ""
	var serialize_data : Dictionary = {
		"name" : name,
		"comments" : comments,
		"colors" : [],
		"editable" : editable
	}
	for color in colors:
		serialize_data.colors.push_back(color.toDict())

	result = JSON.print(serialize_data, " ")

	return result


func deserialize(input_string : String): # -> Palette
	var result = get_script().new()

	var result_json = JSON.parse(input_string)

	if result_json.error != OK:  # If parse has errors
		print("Error: ", result_json.error)
		print("Error Line: ", result_json.error_line)
		print("Error String: ", result_json.error_string)
		result = null
	else:  # If parse OK
		var data = result_json.result
		if data.has("name"): # If data is 'valid' palette file
			result = get_script().new()
			result.name = data.name
			if data.has("comments"):
				result.comments = data.comments
			if data.has("editable"):
				result.editable = data.editable
			for color_data in data.colors:
				result.add_color(color_data.data, color_data.name)

	return result


func load_from_file(path : String): # -> Palette
	var result = null # : Palette
	var file = File.new()

	if file.file_exists(path):
		file.open(path, File.READ)

		var text : String = file.get_as_text()
		result = deserialize(text)
		result.source_path = path

		file.close()

	return result


func remove_file() -> int:
	var dir = Directory.new()
	return dir.remove(source_path)
