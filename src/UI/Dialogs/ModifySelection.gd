extends ConfirmationDialog

enum Types { EXPAND, SHRINK, BORDER, CENTER }

@export var type := Types.EXPAND:
	set(value):
		type = value
		if type == Types.EXPAND:
			title = "Expand Selection"
		elif type == Types.SHRINK:
			title = "Shrink Selection"
		else:
			title = "Border Selection"

@onready var width_slider: ValueSlider = $GridContainer/WidthSlider
@onready var brush_option_button: OptionButton = $GridContainer/BrushOptionButton
@onready var with_content_node := $GridContainer/WithContent
@onready var selection_node := Global.canvas.selection


func _on_about_to_popup() -> void:
	await get_tree().process_frame
	with_content_node.visible = type != Types.BORDER
	$GridContainer/ContentLabel.visible = type != Types.BORDER
	if not with_content_node.visible:
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
		return
	selection_node.transform_content_confirm()
	var undo_data_tmp := selection_node.get_undo_data(false)
	var brush := brush_option_button.selected
	project.selection_map.crop(project.size.x, project.size.y)
	if type == Types.EXPAND:
		project.selection_map.expand(width, brush)
	elif type == Types.SHRINK:
		project.selection_map.shrink(width, brush)
	else:
		project.selection_map.border(width, brush)
	project.selection_offset = Vector2.ZERO
	selection_node.commit_undo("Modify Selection", undo_data_tmp)
	selection_node.queue_redraw()


func _on_with_content_toggled(toggled_on: bool) -> void:
	if toggled_on:
		brush_option_button.select(2)  # Square
	brush_option_button.set_item_disabled(0, toggled_on)  # Diamond
	brush_option_button.set_item_disabled(1, toggled_on)  # Circle
