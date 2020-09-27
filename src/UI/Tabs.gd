extends Tabs


func _on_Tabs_tab_changed(tab : int) -> void:
	Global.current_project_index = tab


func _on_Tabs_tab_close(tab : int) -> void:
	if Global.projects.size() == 1 or Global.current_project_index != tab:
		return

	if Global.current_project.has_changed:
		if !Global.unsaved_changes_dialog.is_connected("confirmed", self, "delete_tab"):
			Global.unsaved_changes_dialog.connect("confirmed", self, "delete_tab", [tab])
		Global.unsaved_changes_dialog.popup_centered()
		Global.dialog_open(true)
	else:
		delete_tab(tab)


func _on_Tabs_reposition_active_tab_request(idx_to : int) -> void:
	var temp = Global.projects[Global.current_project_index]
	Global.projects.erase(temp)
	Global.projects.insert(idx_to, temp)

	# Change save paths
	var temp_save_path = OpenSave.current_save_paths[Global.current_project_index]
	OpenSave.current_save_paths[Global.current_project_index] = OpenSave.current_save_paths[idx_to]
	OpenSave.current_save_paths[idx_to] = temp_save_path
	var temp_backup_path = OpenSave.backup_save_paths[Global.current_project_index]
	OpenSave.backup_save_paths[Global.current_project_index] = OpenSave.backup_save_paths[idx_to]
	OpenSave.backup_save_paths[idx_to] = temp_backup_path


func delete_tab(tab : int) -> void:
	remove_tab(tab)
	Global.projects[tab].undo_redo.free()
	OpenSave.remove_backup(tab)
	OpenSave.current_save_paths.remove(tab)
	OpenSave.backup_save_paths.remove(tab)
	Global.projects.remove(tab)
	if tab > 0:
		Global.current_project_index -= 1
	else:
		Global.current_project_index = 0
	if Global.unsaved_changes_dialog.is_connected("confirmed", self, "delete_tab"):
		Global.unsaved_changes_dialog.disconnect("confirmed", self, "delete_tab")
