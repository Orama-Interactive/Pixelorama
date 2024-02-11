class_name ReferencesPanel
extends PanelContainer
## Panel for reference image management

const ReferenceImageButton = preload("res://src/UI/ReferenceImages/ReferenceImageButton.tscn")

var list_btn_group := ButtonGroup.new()
var transform_button_group: ButtonGroup

@onready var list := %List as HBoxContainer
@onready var drag_highlight := $Overlay/DragHighlight as ColorRect
@onready var remove_btn := $ScrollContainer/Container/ReferenceEdit/ImageOptions/Remove as Button
@onready var transform_tools_btns := $ScrollContainer/Container/Tools/TransformTools


func _ready() -> void:
	transform_button_group = transform_tools_btns.get_child(0).button_group
	transform_button_group.pressed.connect(_on_transform_tool_button_group_pressed)
	list_btn_group.pressed.connect(_on_reference_image_button_pressed)
	Global.canvas.reference_image_container.reference_image_changed.connect(
		_on_reference_image_changed
	)
	OpenSave.reference_image_imported.connect(_on_references_changed)
	# We call this function to update the buttons
	_on_references_changed()
	_update_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_highlight.hide()


func _on_transform_tool_button_group_pressed(button: Button) -> void:
	Global.canvas.reference_image_container.mode = button.get_index()


func _on_move_image_left_pressed() -> void:
	var index: int = Global.current_project.reference_index
	reorder_reference_image(index, index - 1)


func _on_move_image_right_pressed() -> void:
	var index: int = Global.current_project.reference_index
	reorder_reference_image(index, index + 1)


## This method allows you to reoreder reference image with undo redo support
## Please use this and not the method with the same name in project.gd
func reorder_reference_image(from: int, to: int, update_reference_index := true) -> void:
	var project := Global.current_project
	project.undo_redo.create_action("Reorder Reference Image")
	project.undo_redo.add_do_method(project.reorder_reference_image.bind(from, to))
	project.undo_redo.add_do_method(Global.reference_panel._on_references_changed)
	if update_reference_index:
		project.undo_redo.add_do_method(project.set_reference_image_index.bind(to))
	else:
		project.undo_redo.add_undo_method(
			project.set_reference_image_index.bind(project.reference_index)
		)
	project.undo_redo.add_do_method(_update_ui)

	project.undo_redo.add_undo_method(project.reorder_reference_image.bind(to, from))
	project.undo_redo.add_undo_method(Global.reference_panel._on_references_changed)
	if update_reference_index:
		project.undo_redo.add_undo_method(project.set_reference_image_index.bind(from))
	else:
		project.undo_redo.add_undo_method(
			project.set_reference_image_index.bind(project.reference_index)
		)

	project.undo_redo.add_undo_method(_update_ui)

	project.undo_redo.commit_action()


func _update_ui() -> void:
	var index: int = Global.current_project.reference_index

	# Enable the buttons as a default
	%MoveImageRightBtn.disabled = false
	%MoveImageLeftBtn.disabled = false

	if index == -1:
		%MoveImageLeftBtn.disabled = true
		%MoveImageRightBtn.disabled = true
	if index == 0:
		%MoveImageLeftBtn.disabled = true
	if index == Global.current_project.reference_images.size() - 1:
		%MoveImageRightBtn.disabled = true

	if %MoveImageLeftBtn.disabled:
		%MoveImageLeftBtn.mouse_default_cursor_shape = CURSOR_FORBIDDEN
	else:
		%MoveImageLeftBtn.mouse_default_cursor_shape = CURSOR_POINTING_HAND

	if %MoveImageRightBtn.disabled:
		%MoveImageRightBtn.mouse_default_cursor_shape = CURSOR_FORBIDDEN
	else:
		%MoveImageRightBtn.mouse_default_cursor_shape = CURSOR_POINTING_HAND

	# Update the remove button
	remove_btn.disabled = index == -1
	if remove_btn.disabled:
		remove_btn.mouse_default_cursor_shape = CURSOR_FORBIDDEN
	else:
		remove_btn.mouse_default_cursor_shape = CURSOR_POINTING_HAND


func _on_reference_image_button_pressed(button: Button) -> void:
	# We subtract 1 because we already have a default button to "select no reference image
	Global.current_project.set_reference_image_index(button.get_index() - 1)


# In case the signal is emitted for another node and not from a pressed button
func _on_reference_image_changed(index: int) -> void:
	_update_ui()
	# Update the buttons to show which one is pressed
	if list_btn_group.get_buttons().size() > 0:
		# First we loop through the buttons to "unpress them all"
		for b: Button in list_btn_group.get_buttons():
			b.set_pressed_no_signal(false)
		# Then we get the wanted button and we press it
		list_btn_group.get_buttons()[index + 1].set_pressed_no_signal(true)


func project_changed() -> void:
	var project_reference_index := Global.current_project.reference_index
	_on_references_changed()
	_update_ui()
	Global.current_project.set_reference_image_index(project_reference_index)


func _on_references_changed():
	# When we change the project we set the default
	Global.current_project.set_reference_image_index(-1)

	for c in list.get_children():
		if c is Button:
			c.button_group = null
		c.queue_free()

	# The default button
	var default = ReferenceImageButton.instantiate()
	default.button_group = list_btn_group
	default.text = "none"
	default.button_pressed = true
	list.add_child(default)

	# And update.
	for ref in Global.current_project.reference_images:
		var l: Button = ReferenceImageButton.instantiate()
		l.button_group = list_btn_group
		if ref.texture:
			l.icon = ref.texture
		list.add_child(l)
