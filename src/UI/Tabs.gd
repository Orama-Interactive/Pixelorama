extends Tabs

onready var unsaved_changes_dialog: ConfirmationDialog = Global.control.find_node(
	"UnsavedCanvasDialog"
)


func _on_Tabs_tab_changed(tab: int) -> void:
	Global.current_project_index = tab


func _on_Tabs_tab_close(tab: int) -> void:
	if Global.projects.size() == 1:
		return

	if Global.projects[tab].has_changed:
		if !unsaved_changes_dialog.is_connected("confirmed", self, "delete_tab"):
			unsaved_changes_dialog.connect("confirmed", self, "delete_tab", [tab])
		unsaved_changes_dialog.popup_centered()
		Global.dialog_open(true)
	else:
		delete_tab(tab)


func _on_Tabs_reposition_active_tab_request(idx_to: int) -> void:
	var temp: Project = Global.projects[Global.current_project_index]
	Global.projects.erase(temp)
	Global.projects.insert(idx_to, temp)

	# Change save paths
	var temp_save_path = OpenSave.current_save_paths[Global.current_project_index]
	OpenSave.current_save_paths[Global.current_project_index] = OpenSave.current_save_paths[idx_to]
	OpenSave.current_save_paths[idx_to] = temp_save_path
	var temp_backup_path = OpenSave.backup_save_paths[Global.current_project_index]
	OpenSave.backup_save_paths[Global.current_project_index] = OpenSave.backup_save_paths[idx_to]
	OpenSave.backup_save_paths[idx_to] = temp_backup_path


func delete_tab(tab: int) -> void:
	remove_tab(tab)
	Global.projects[tab].remove()
	OpenSave.remove_backup(tab)
	OpenSave.current_save_paths.remove(tab)
	OpenSave.backup_save_paths.remove(tab)
	if Global.current_project_index == tab:
		if tab > 0:
			Global.current_project_index -= 1
		else:
			Global.current_project_index = 0
	else:
		if tab < Global.current_project_index:
			Global.current_project_index -= 1
	if unsaved_changes_dialog.is_connected("confirmed", self, "delete_tab"):
		unsaved_changes_dialog.disconnect("confirmed", self, "delete_tab")
