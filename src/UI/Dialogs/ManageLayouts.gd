extends AcceptDialog

var layout_selected := -1

onready var layout_list: ItemList = $VBoxContainer/SavedLayouts
onready var layout_name: LineEdit = $VBoxContainer/HBoxContainer/LayoutName
onready var delete_layout: Button = $VBoxContainer/DeleteLayout
onready var save_layout: Button = $VBoxContainer/HBoxContainer/SaveLayout


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
	delete_layout.disabled = index < 2


func _on_SavedLayouts_nothing_selected() -> void:
	delete_layout.disabled = true


func _on_DeleteLayout_pressed() -> void:
	var dir := Directory.new()
	var file_name := layout_list.get_item_text(layout_selected) + ".tres"
	dir.remove("user://layouts/".plus_file(file_name))
	Global.top_menu_container.layouts.remove(layout_selected)
	layout_list.remove_item(layout_selected)
	Global.top_menu_container.populate_layouts_submenu()
	layout_selected = -1
	delete_layout.disabled = true


func _on_LayoutName_text_changed(new_text: String) -> void:
	save_layout.disabled = new_text.empty()


func _on_SaveLayout_pressed() -> void:
	var file_name := layout_name.text + ".tres"
	var path := "user://layouts/".plus_file(file_name)
	var layout = Global.control.ui.get_layout()
	var err := ResourceSaver.save(path, layout)
	if err != OK:
		print(err)
	else:
		Global.top_menu_container.layouts.append([layout_name.text, layout])
		layout_list.add_item(layout_name.text)
		Global.top_menu_container.populate_layouts_submenu()
		var n: int = Global.top_menu_container.layouts_submenu.get_item_count()
		Global.top_menu_container.layouts_submenu.set_item_checked(n - 2, true)
