class_name LayerEffectFoldable
extends FoldableContainer

var layer: BaseLayer
var parent_panel: LayerFXPanel


func _get_drag_data(pos: Vector2) -> Variant:
	if pos.y > 35:  # Only allow dragging from the title of the container.
		return null
	return ["LayerEffect", get_index()]


func _can_drop_data(pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_ARRAY:
		parent_panel.drag_highlight.visible = false
		return false
	if data[0] != "LayerEffect":
		parent_panel.drag_highlight.visible = false
		return false

	var effect_container := get_parent()
	var scroll_container := effect_container.get_parent() as ScrollContainer
	var panel_index := get_index()
	# Ensure that the target and its neighbors remain visible.
	scroll_container.ensure_control_visible(self)
	if pos.y > size.y / 2.0 and panel_index + 1 < effect_container.get_child_count():
		scroll_container.ensure_control_visible(effect_container.get_child(panel_index + 1))
	if pos.y < size.y / 2.0 and panel_index - 1 >= 0:
		scroll_container.ensure_control_visible(effect_container.get_child(panel_index - 1))
	var drop_index: int = data[1]
	if panel_index == drop_index:
		parent_panel.drag_highlight.visible = false
		return false
	var region: Rect2
	if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):  # Top region
		region = _get_region_rect(-0.1, 0.15)
	else:  # Bottom region
		region = _get_region_rect(0.85, 1.1)
	parent_panel.drag_highlight.visible = true
	parent_panel.drag_highlight.set_deferred(&"global_position", region.position)
	parent_panel.drag_highlight.set_deferred(&"size", region.size)
	return true


func _drop_data(_pos: Vector2, data) -> void:
	var drop_index: int = data[1]
	var to_index: int  # the index where the LOWEST moved layer effect should end up
	if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):  # Top region
		to_index = get_index()
	else:  # Bottom region
		to_index = get_index() + 1
	if drop_index < get_index():
		to_index -= 1
	parent_panel.move_effect(layer, drop_index, to_index)


func _get_region_rect(y_begin: float, y_end: float) -> Rect2:
	var rect := get_global_rect()
	rect.position.y += rect.size.y * y_begin
	rect.size.y *= y_end - y_begin
	return rect
