extends Button

var layer_effects_settings: AcceptDialog
var layer: BaseLayer

@onready var panel := get_parent().get_parent()


func _get_drag_data(_position: Vector2) -> Variant:
	return ["LayerEffect", panel.get_index()]


func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_ARRAY:
		layer_effects_settings.drag_highlight.visible = false
		return false
	if data[0] != "LayerEffect":
		layer_effects_settings.drag_highlight.visible = false
		return false
	var drop_index: int = data[1]
	if panel.get_index() == drop_index:
		layer_effects_settings.drag_highlight.visible = false
		return false
	var region: Rect2
	if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):  # Top region
		region = _get_region_rect(-0.1, 0.15)
	else:  # Bottom region
		region = _get_region_rect(0.85, 1.1)
	layer_effects_settings.drag_highlight.visible = true
	layer_effects_settings.drag_highlight.set_deferred(&"global_position", region.position)
	layer_effects_settings.drag_highlight.set_deferred(&"size", region.size)
	return true


func _drop_data(_pos: Vector2, data) -> void:
	var drop_index: int = data[1]
	var to_index: int  # the index where the LOWEST moved layer effect should end up
	if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):  # Top region
		to_index = panel.get_index()
	else:  # Bottom region
		to_index = panel.get_index() + 1
	if drop_index < panel.get_index():
		to_index -= 1
	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Re-arrange layer effect")
	Global.current_project.undo_redo.add_do_method(
		layer_effects_settings.move_effect.bind(layer, drop_index, to_index)
	)
	Global.current_project.undo_redo.add_do_method(Global.canvas.queue_redraw)
	Global.current_project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	Global.current_project.undo_redo.add_undo_method(
		layer_effects_settings.move_effect.bind(layer, to_index, drop_index)
	)
	Global.current_project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
	Global.current_project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	Global.current_project.undo_redo.commit_action()
	panel.get_parent().move_child(panel.get_parent().get_child(drop_index), to_index)


func _get_region_rect(y_begin: float, y_end: float) -> Rect2:
	var rect := get_global_rect()
	rect.position.y += rect.size.y * y_begin
	rect.size.y *= y_end - y_begin
	return rect
