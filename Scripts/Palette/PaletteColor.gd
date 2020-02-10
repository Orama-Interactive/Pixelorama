class_name PaletteColor
extends Reference

func get_class():
	return "PaletteColor"
func is_class(_name):
	return _name == "PaletteColor" or .is_class(_name)

var color : Color = Color.black setget _set_color
var data : String = "" setget _set_data
var name : String = "no name"

func _init(new_color : Color = Color.black, new_name : String = "no name"):
	self.color = new_color
	self.name = new_name

func _set_color(new_value : Color) -> void:
	color = new_value
	data = color.to_html(true)

func _set_data(new_value : String) -> void:
	data = new_value
	color = Color(data)

func toDict() -> Dictionary:
	var result = {
			"data" : data,
			"name" : name
		}
	return result

func fromDict(input_dict : Dictionary): # -> PaletteColor
	var result = get_script().new()

	result.data = input_dict.data
	result.name = input_dict.name

	return result

func duplicate(): # -> PaletteColor
	var copy = get_script().new() # : PaletteColor
	copy.data = data
	copy.name = name
	return copy
