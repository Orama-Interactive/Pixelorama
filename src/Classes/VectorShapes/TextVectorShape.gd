class_name TextVectorShape
extends BaseVectorShape

var pos: Vector2
var text: String setget _set_text
var font: DynamicFont
var font_size: int
var outline_size: int
var extra_spacing: Vector2
var color: Color
var outline_color: Color
var antialiased: bool

var lines: PoolStringArray  # Made from text split into each of its new lines


func draw(canvas_item: RID) -> void:
	font.size = font_size
	font.outline_size = outline_size
	font.extra_spacing_char = extra_spacing.x
	font.extra_spacing_bottom = extra_spacing.y
	font.outline_color = outline_color
	font.font_data.antialiased = antialiased
	var line_pos := pos
	for line in lines:
		font.draw(canvas_item, line_pos, line, color)
		line_pos.y += font.get_height()


func has_point(point: Vector2) -> bool:
	# TODO: For adding rotation, the trick will probably be to first rotate the point around this shape's pivot point
	font.size = font_size
	font.outline_size = outline_size
	font.extra_spacing_char = extra_spacing.x
	font.extra_spacing_bottom = extra_spacing.y
	var line_pos := pos
	for line in lines:
		if Rect2(pos, font.get_string_size(line)).has_point(point):
			return true
		line_pos.y += font.get_height()
	return false


func serialize() -> Dictionary:
	return {
		"type": Global.VectorShapeTypes.TEXT,
		"pos": [pos.x, pos.y],
		"text": text,
		"font": font.font_data.font_path,
		"f_size": font_size,
		"ol_size": outline_size,
		"ex_sp": extra_spacing,
		"col": color.to_html(true),
		"ol_col": outline_color.to_html(true),
		"aa": antialiased,
	}


func deserialize(dict: Dictionary) -> void:
	pos = Vector2(dict["pos"][0], dict["pos"][1])
	self.text = dict["text"]  # Call the setter too
#	font =  # TODO: figure out font
	font.size = dict["f_size"]
	font.outline_size = dict["ol_size"]
	extra_spacing = Vector2(dict["ex_sp"][0], dict["ex_sp"][1])
	color = Color(dict["col"])
	outline_color = Color(dict["ol_col"])
	antialiased = dict["aa"]


func _set_text(value: String) -> void:
	text = value
	lines = value.split("\n", false)
