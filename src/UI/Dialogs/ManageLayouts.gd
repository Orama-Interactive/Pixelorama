extends AcceptDialog

var layout_selected := -1
var is_editing := false

onready var layout_list: ItemList = find_node("SavedLayouts")
onready var edit_layout: Button = find_node("EditLayout")
onready var delete_layout: Button = find_node("DeleteLayout")
onready var layout_settings: ConfirmationDialog = $LayoutSettings
onready var layout_name: LineEdit = $LayoutSettings/LayoutName
onready var delete_confirmation: ConfirmationDialog = $DeleteConfirmation
onready var mimic_ui = find_node("LayoutPreview")


func _on_ManageLayouts_about_to_show() -> void:
	for layout in Global.top_menu_container.layouts:
		layout_list.add_item(layout[0])
	refresh_preview()
	if layout_selected != -1:
		layout_list.select(layout_selected)


func _on_ManageLayouts_popup_hide() -> void:
	layout_list.clear()
	Global.dialog_open(false)


func _on_SavedLayouts_item_activated(index: int) -> void:
	Global.top_menu_container.set_layout(index)


func _on_SavedLayouts_item_selected(index: int) -> void:
	layout_selected = index
	edit_layout.disabled = index < Global.top_menu_container.default_layout_size
	delete_layout.disabled = index < Global.top_menu_container.default_layout_size
	refresh_preview()


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
	delete_confirmation.popup_centered()


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
				layout_selected + 1, layout_name.text
			)
		else:
			Global.top_menu_container.layouts.append([layout_name.text, layout])
			layout_list.add_item(layout_name.text)
			Global.top_menu_container.populate_layouts_submenu()
			var n: int = Global.top_menu_container.layouts_submenu.get_item_count()
			Global.top_menu_container.layouts_submenu.set_item_checked(n - 1, true)


func delete_layout_file(file_name: String) -> void:
	var dir := Directory.new()
	dir.remove("user://layouts/".plus_file(file_name))


func _on_DeleteConfirmation_confirmed() -> void:
	delete_layout_file(layout_list.get_item_text(layout_selected) + ".tres")
	Global.top_menu_container.layouts.remove(layout_selected)
	layout_list.remove_item(layout_selected)
	Global.top_menu_container.populate_layouts_submenu()
	layout_selected = -1
	edit_layout.disabled = true
	delete_layout.disabled = true
	refresh_preview()


func refresh_preview():
	for tab in mimic_ui.get_tabs():
		mimic_ui.remove_child(tab)
	for item in Global.top_menu_container.ui.get_tabs():
		var box := TextEdit.new()
		box.name = item.name
		box.text = item.name
		box.wrap_enabled = true
		box.readonly = true
		mimic_ui.add_child(box)
	if layout_selected == -1:
		mimic_ui.visible = false
		return
	mimic_ui.visible = true
	mimic_ui.set_layout(Global.top_menu_container.layouts[layout_selected][1].clone())
