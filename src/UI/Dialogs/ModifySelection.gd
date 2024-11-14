extends ConfirmationDialog

enum Types { EXPAND, SHRINK, BORDER }

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
@onready var selection_node := Global.canvas.selection


func _on_visibility_changed() -> void:
	if not visible:
		Global.dialog_open(false)


func _on_confirmed() -> void:
	var project := Global.current_project
	if !project.has_selection:
		return
	selection_node.transform_content_confirm()
	var undo_data_tmp := selection_node.get_undo_data(false)
	var width: int = width_slider.value
	var brush := brush_option_button.selected
	project.selection_map.crop(project.size.x, project.size.y)
	if type == Types.EXPAND:
		project.selection_map.expand(width, brush)
	elif type == Types.SHRINK:
		project.selection_map.shrink(width, brush)
	else:
		project.selection_map.border(width, brush)
	selection_node.big_bounding_rectangle = project.selection_map.get_used_rect()
	project.selection_offset = Vector2.ZERO
	selection_node.commit_undo("Modify Selection", undo_data_tmp)
	selection_node.queue_redraw()
