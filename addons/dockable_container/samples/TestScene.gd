extends VBoxContainer

const SAVED_LAYOUT_PATH := "user://layout.tres"

@onready var _container := $DockableContainers/DockableContainer as DockableContainer
@onready var _clone_control := $HBoxContainer/ControlPrefab as ColorRect
@onready var _checkbox_container := $HBoxContainer as HBoxContainer


func _ready() -> void:
	if not OS.is_userfs_persistent():
		$HBoxContainer/SaveLayoutButton.visible = false
		$HBoxContainer/LoadLayoutButton.visible = false

	var tabs := _container.get_tabs()
	for i in tabs.size():
		var checkbox := CheckBox.new()
		checkbox.text = str(i)
		checkbox.button_pressed = not _container.is_control_hidden(tabs[i])
		checkbox.toggled.connect(_on_CheckButton_toggled.bind(tabs[i]))
		_checkbox_container.add_child(checkbox)


func _on_add_pressed() -> void:
	var control := _clone_control.duplicate()
	control.get_node("Buttons/Rename").pressed.connect(
		_on_control_rename_button_pressed.bind(control)
	)
	control.get_node("Buttons/Remove").pressed.connect(
		_on_control_remove_button_pressed.bind(control)
	)
	control.color = Color(randf(), randf(), randf())
	control.name = "Control0"

	_container.add_child(control, true)
	await _container.sort_children
	_container.set_control_as_current_tab(control)


func _on_save_pressed() -> void:
	if ResourceSaver.save(_container.layout, SAVED_LAYOUT_PATH) != OK:
		print("ERROR")


func _on_load_pressed() -> void:
	var res = load(SAVED_LAYOUT_PATH)
	if res:
		_container.set_layout(res.clone())
	else:
		print("Error")


func _on_control_rename_button_pressed(control: Control) -> void:
	control.name = StringName(str(control.name) + " =D")


func _on_control_remove_button_pressed(control: Control) -> void:
	control.get_parent().remove_child(control)
	control.queue_free()


func _on_CheckButton_toggled(button_pressed: bool, tab: Control) -> void:
	_container.set_control_hidden(tab, not button_pressed)
