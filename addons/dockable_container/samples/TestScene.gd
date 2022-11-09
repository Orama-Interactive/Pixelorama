extends VBoxContainer

const SAVED_LAYOUT_PATH = "user://layout.tres"

onready var _container = $DockableContainers/DockableContainer
onready var _clone_control = $HBoxContainer/ControlPrefab
onready var _checkbox_container = $HBoxContainer


func _ready() -> void:
	if not OS.is_userfs_persistent():
		$HBoxContainer/SaveLayoutButton.visible = false
		$HBoxContainer/LoadLayoutButton.visible = false

	var tabs = _container.get_tabs()
	for i in tabs.size():
		var checkbox = CheckBox.new()
		checkbox.text = str(i)
		checkbox.pressed = not _container.is_control_hidden(tabs[i])
		checkbox.connect("toggled", self, "_on_CheckButton_toggled", [tabs[i]])
		_checkbox_container.add_child(checkbox)


func _on_add_pressed() -> void:
	var control = _clone_control.duplicate()
	control.get_node("Buttons/Rename").connect(
		"pressed", self, "_on_control_rename_button_pressed", [control]
	)
	control.get_node("Buttons/Remove").connect(
		"pressed", self, "_on_control_remove_button_pressed", [control]
	)
	control.color = Color(randf(), randf(), randf())
	control.name = "Control0"

	_container.add_child(control, true)
	yield(_container, "sort_children")
	_container.set_control_as_current_tab(control)


func _on_save_pressed() -> void:
	if ResourceSaver.save(SAVED_LAYOUT_PATH, _container.get_layout()) != OK:
		print("ERROR")


func _on_load_pressed() -> void:
	var res = load(SAVED_LAYOUT_PATH)
	if res:
		_container.set_layout(res.clone())
	else:
		print("Error")


func _on_control_rename_button_pressed(control: Control) -> void:
	control.name += " =D"


func _on_control_remove_button_pressed(control: Control) -> void:
	_container.remove_child(control)
	control.queue_free()


func _on_CheckButton_toggled(button_pressed: bool, tab: Control) -> void:
	_container.set_control_hidden(tab, not button_pressed)
