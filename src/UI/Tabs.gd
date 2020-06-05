extends Tabs


func _on_Tabs_tab_changed(tab : int) -> void:
	Global.current_project_index = tab


func _on_Tabs_tab_close(tab : int) -> void:
	if Global.projects.size() == 1:
		return

	if Global.current_project.has_changed:
		if !Global.unsaved_changes_dialog.is_connected("confirmed", self, "delete_tab"):
			Global.unsaved_changes_dialog.connect("confirmed", self, "delete_tab", [tab])
		Global.unsaved_changes_dialog.popup_centered()
		Global.dialog_open(true)
	else:
		delete_tab(tab)


func _on_Tabs_reposition_active_tab_request(idx_to : int) -> void:
	pass


func delete_tab(tab : int) -> void:
	remove_tab(tab)
	Global.current_project.undo_redo.free()
	Global.projects.remove(tab)
	if tab > 0:
		Global.current_project_index -= 1
	else:
		Global.current_project_index = 0
	Global.unsaved_changes_dialog.disconnect("confirmed", self, "delete_tab")
