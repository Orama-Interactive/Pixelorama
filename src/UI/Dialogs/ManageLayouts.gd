extends AcceptDialog

var layout_selected := -1
var is_editing := false

onready var layout_list: ItemList = $VBoxContainer/SavedLayouts
onready var edit_layout: Button = find_node("EditLayout")
onready var delete_layout: Button = find_node("DeleteLayout")
onready var layout_settings: ConfirmationDialog = $LayoutSettings
onready var layout_name: LineEdit = $LayoutSettings/LayoutName


func _on_ManageLayouts_about_to_show() -> void:
	for layout in Global.top_menu_container.layouts:
		layout_list.add_item(layout[0])


func _on_ManageLayouts_popup_hide() -> void:
	layout_list.clear()
	Global.dialog_open(false)


func _on_SavedLayouts_item_activated(index: int) -> void:
	Global.top_menu_container.set_layout(index)


func _on_SavedLayouts_item_selected(index: int) -> void:
	layout_selected = index
	edit_layout.disabled = index < 2
	delete_layout.disabled = index < 2


func _on_SavedLayouts_nothing_selected() -> void:
	edit_layout.disabled = true
	delete_layout.disabled = true


func _on_AddLayout_pressed() -> void:
	is_editing = false
	layout_name.text = "New Layout"
	layout_settings.window_title = "Add Layout"
	layout_settings.popup_centered()


func _on_EditLayout_pressed() -> void:
	is_editing = true
	layout_name.text = layout_list.get_item_text(layout_selected)
	layout_settings.window_title = "Edit Layout"
	layout_settings.popup_centered()


func _on_DeleteLayout_pressed() -> void:
	delete_layout_file(layout_list.get_item_text(layout_selected) + ".tres")
	Global.top_menu_container.layouts.remove(layout_selected)
	layout_list.remove_item(layout_selected)
	Global.top_menu_container.populate_layouts_submenu()
	layout_selected = -1
	edit_layout.disabled = true
	delete_layout.disabled = true


func _on_LayoutSettings_confirmed() -> void:
	var file_name := layout_name.text + ".tres"
	var path := "user://layouts/".plus_file(file_name)
	var layout = Global.control.ui.get_layout()
	var err := ResourceSaver.save(path, layout)
	if err != OK:
		print(err)
	else:
		if is_editing:
			var old_file_name: String = layout_list.get_item_text(layout_selected) + ".tres"
			if old_file_name != file_name:
				delete_layout_file(old_file_name)
			Global.top_menu_container.layouts[layout_selected][0] = layout_name.text
			Global.top_menu_container.layouts[layout_selected][1] = layout
			layout_list.set_item_text(layout_selected, layout_name.text)
			Global.top_menu_container.layouts_submenu.set_item_text(
				layout_selected + 2, layout_name.text
			)
		else:
			Global.top_menu_container.layouts.append([layout_name.text, layout])
			layout_list.add_item(layout_name.text)
			Global.top_menu_container.populate_layouts_submenu()
			var n: int = Global.top_menu_container.layouts_submenu.get_item_count()
			Global.top_menu_container.layouts_submenu.set_item_checked(n - 2, true)


func delete_layout_file(file_name: String) -> void:
	var dir := Directory.new()
	dir.remove("user://layouts/".plus_file(file_name))
