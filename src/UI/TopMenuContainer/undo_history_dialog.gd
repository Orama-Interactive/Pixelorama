extends AcceptDialog

@onready var item_list: ItemList = $ItemList


func _on_visibility_changed() -> void:
	var project := Global.current_project
	var version := project.undo_redo.get_version()
	var history_count := project.undo_redo.get_history_count()
	if not is_instance_valid(item_list):
		return
	Global.dialog_open(visible)
	if visible:
		item_list.clear()
		for i in range(history_count - 1, -1, -1):
			var action := project.undo_redo.get_action_name(i)
			item_list.add_item(action)
		item_list.add_item("Initial state")
		item_list.select(history_count - version + 1)


func _on_item_list_item_selected(index: int) -> void:
	var project := Global.current_project
	var history_count := project.undo_redo.get_history_count()
	var history_point := history_count - index + 1
	while project.undo_redo.get_version() > history_point:
		project.commit_undo()
	while project.undo_redo.get_version() < history_point:
		project.commit_redo()
