extends ConfirmationDialog

enum Types { EXPAND, SHRINK, BORDER, CENTER }

@export var type := Types.EXPAND:
	set(value):
		type = value
		if type == Types.EXPAND:
			title = "Expand Selection"
		elif type == Types.SHRINK:
			title = "Shrink Selection"
		elif type == Types.BORDER:
			title = "Border Selection"
		else:
			title = "Center Selection"

@onready var width_slider: ValueSlider = $Options/ExpandShrinkBorder/WidthSlider
@onready var brush_option_button: OptionButton = $Options/ExpandShrinkBorder/BrushOptionButton
@onready var with_content_node := $Options/HBoxContainer/WithContent
@onready var relative_checkbox := $Options/CenterContent/RelativeCheckbox
@onready var selection_node := Global.canvas.selection


func _on_about_to_popup() -> void:
	await get_tree().process_frame
	$Options/HBoxContainer.visible = type != Types.BORDER
	$Options/ExpandShrinkBorder.visible = type != Types.CENTER
	$Options/CenterContent.visible = type == Types.CENTER and with_content_node.button_pressed
	if not with_content_node.is_visible_in_tree():
		with_content_node.button_pressed = false


func _on_visibility_changed() -> void:
	if not visible:
		Global.dialog_open(false)


func _on_confirmed() -> void:
	var project := Global.current_project
	if !project.has_selection:
		return
	var width: int = width_slider.value
	if with_content_node.button_pressed:
		if !selection_node.transformation_handles.currently_transforming:
			selection_node.transformation_handles.begin_transform()
		var image_size := selection_node.preview_selection_map.get_used_rect().size
		var delta := Vector2i(width, width)
		match type:
			Types.EXPAND:
				selection_node.transformation_handles.resize_transform(delta)
			Types.SHRINK:
				selection_node.transformation_handles.resize_transform(-delta)
			Types.CENTER:
				var old_pos = selection_node.transformation_handles.preview_transform.origin
				var used_rect := Rect2i(
					old_pos, project.selection_map.get_selection_rect(project).size
				)
				if relative_checkbox.button_pressed:
					var transformed_image = selection_node.transformation_handles.transformed_image
					if is_instance_valid(transformed_image):
						used_rect = transformed_image.get_used_rect()
						used_rect.position += Vector2i(old_pos)
				if not used_rect.has_area():
					return
				var offset: Vector2i = (0.5 * (project.size - used_rect.size)).floor()
				selection_node.transformation_handles.move_transform(offset - used_rect.position)
		return
	selection_node.transform_content_confirm()
	var undo_data_tmp := selection_node.get_undo_data(false)
	var brush := brush_option_button.selected
	project.selection_map.crop(project.size.x, project.size.y)
	if type == Types.EXPAND:
		project.selection_map.expand(width, brush)
	elif type == Types.SHRINK:
		project.selection_map.shrink(width, brush)
	elif type == Types.BORDER:
		project.selection_map.border(width, brush)
	else:
		project.selection_map.center()
	project.selection_offset = Vector2.ZERO
	selection_node.commit_undo("Modify Selection", undo_data_tmp)
	selection_node.queue_redraw()


func _on_with_content_toggled(toggled_on: bool) -> void:
	if toggled_on:
		brush_option_button.select(2)  # Square
	brush_option_button.set_item_disabled(0, toggled_on)  # Diamond
	brush_option_button.set_item_disabled(1, toggled_on)  # Circle
	$Options/CenterContent.visible = type == Types.CENTER and with_content_node.button_pressed
