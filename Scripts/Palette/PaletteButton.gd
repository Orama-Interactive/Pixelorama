extends Button
signal on_drop_data

export var index := 0;
export var color : Color = Color.white
export var draggable := false

var drag_preview_texture = preload("res://Assets/Graphics/Palette/swatch_drag_preview.png")

func get_drag_data(_position):
	var data = null
	if draggable:
		data = {source_index = index}
		var drag_icon = TextureRect.new()
		drag_icon.texture = drag_preview_texture
		drag_icon.modulate = color
		set_drag_preview(drag_icon)
	return data

func can_drop_data(_position, _data):
	return true

func drop_data(_position, data):
	emit_signal("on_drop_data", data.source_index, index)
