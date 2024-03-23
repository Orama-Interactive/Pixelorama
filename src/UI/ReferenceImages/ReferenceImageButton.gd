extends Button

var references_panel: ReferencesPanel


func _get_drag_data(_at_position: Vector2) -> Variant:
	var index := get_index() - 1
	# If the index < 0 then that means this button is the "reset button"
	if index < 0:
		return null

	set_drag_preview(self.duplicate())

	var data := ["ReferenceImage", index]

	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_ARRAY:
		references_panel.drag_highlight.visible = false
		return false
	if data[0] != "ReferenceImage":
		references_panel.drag_highlight.visible = false
		return false

	var index := get_index() - 1
	var from_index: int = data[1]
	# If the index < 0 then that means this button is the "reset button"
	# Or we are trying to drop on the same button
	if index < 0 or index == from_index:
		references_panel.drag_highlight.visible = false
		return false

	var side: int = -1
	if get_local_mouse_position().x > size.x / 2:
		side = 1

	var region := Rect2(global_position + Vector2(3, 0), Vector2(6, size.y))

	# Get the side
	if side == 1:
		region.position.x = (size.x + global_position.x) - 3

	references_panel.drag_highlight.visible = true
	references_panel.drag_highlight.position = region.position
	references_panel.drag_highlight.size = region.size

	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var from_index: int = data[1]
	var to_index := get_index()

	if get_local_mouse_position().x > size.x / 2:
		if from_index > to_index:
			to_index += 1
			print("Help mee")
	else:
		if from_index < to_index:
			to_index -= 1

	references_panel.reorder_reference_image(from_index, to_index - 1, false)
