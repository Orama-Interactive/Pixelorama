extends Tabs


func _on_Tabs_tab_changed(tab : int):
	Global.current_project_index = tab
	Global.canvas.update()


func _on_Tabs_tab_close(tab : int):
	if Global.projects.size() == 1:
		return


func _on_Tabs_reposition_active_tab_request(idx_to : int):
	pass
