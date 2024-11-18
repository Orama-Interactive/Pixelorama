extends TabBar

@onready
var unsaved_changes_dialog: ConfirmationDialog = Global.control.find_child("UnsavedCanvasDialog")


func _input(_event: InputEvent) -> void:
	# NOTE: This feature has an unavoidable bug which sometimes causes the undoredo
	# system to fail, because user is trying to draw while switching project simultaneously.
	# This is because the current project has changed and the system tries to commit to the
	# wrong undoredo.
	# If a project is currently worked upon, then don't switch it.
	# This doesn't stop the bug completely but significantly reduces its chances
	# of appearing.
	if (
		Input.is_action_pressed("activate_left_tool")
		or Input.is_action_pressed("activate_right_tool")
	):
		return
	# Due to the bug mentioned above, we will use is_action_just_released
	# instead of is_action_just_pressed. This won't remove the bug completely
	# but it will significantly reduce its chance of appearing.
	var tab_idx := current_tab
	if Input.is_action_just_released(&"next_project", true):
		tab_idx += 1
		if tab_idx >= tab_count:
			tab_idx = 0
	elif Input.is_action_just_released(&"previous_project", true):
		tab_idx -= 1
		if tab_idx < 0:
			tab_idx = tab_count - 1
	if tab_idx != current_tab:
		current_tab = tab_idx


## Handles closing tab with middle-click
## Thanks to https://github.com/godotengine/godot/issues/64498#issuecomment-1217992089
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if !event.pressed or event.button_index != MOUSE_BUTTON_MIDDLE:
		return
	var rect := get_rect()
	var w := rect.position.x
	var w_limit := rect.size.x
	for i in get_tab_count():
		if i < get_tab_offset():
			continue
		w += get_tab_rect(i).size.x
		if w_limit < w:
			return
		if get_tab_rect(i).has_point(event.position):
			_on_tab_close_pressed(i)
			return


func _on_Tabs_tab_changed(tab: int) -> void:
	Global.current_project_index = tab


func _on_tab_close_pressed(tab: int) -> void:
	if Global.projects.size() == 1:
		return

	if Global.projects[tab].has_changed:
		if !unsaved_changes_dialog.confirmed.is_connected(delete_tab):
			unsaved_changes_dialog.confirmed.connect(delete_tab.bind(tab))
		unsaved_changes_dialog.popup_centered()
		Global.dialog_open(true)
	else:
		delete_tab(tab)


func _on_active_tab_rearranged(idx_to: int) -> void:
	var temp := Global.projects[Global.current_project_index]
	Global.projects.erase(temp)
	Global.projects.insert(idx_to, temp)


func delete_tab(tab: int) -> void:
	remove_tab(tab)
	Global.projects[tab].remove()
	if Global.current_project_index == tab:
		if tab > 0:
			Global.current_project_index -= 1
		else:
			Global.current_project_index = 0
	else:
		if tab < Global.current_project_index:
			Global.current_project_index -= 1
	if unsaved_changes_dialog.confirmed.is_connected(delete_tab):
		unsaved_changes_dialog.confirmed.disconnect(delete_tab)
