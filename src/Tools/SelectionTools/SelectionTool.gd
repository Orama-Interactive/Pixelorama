extends BaseTool


var _add := false # Shift + Mouse Click
var _subtract := false # Ctrl + Mouse Click
var _intersect := false # Shift + Ctrl + Mouse Click

var undo_data : Dictionary


func draw_start(_position : Vector2) -> void:
	Global.canvas.selection.transform_content_confirm()
	undo_data = Global.canvas.selection._get_undo_data(false)
	_intersect = Tools.shift && Tools.control
	_add = Tools.shift && !_intersect
	_subtract = Tools.control && !_intersect


func draw_move(_position : Vector2) -> void:
	pass


func draw_end(_position : Vector2) -> void:
	pass
