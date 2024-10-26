extends AcceptDialog

var layout_selected := -1
var is_editing := false

@onready var layout_list := %SavedLayouts as ItemList
@onready var rename_layout := %RenameLayout as Button
@onready var delete_layout := %DeleteLayout as Button
@onready var layout_settings := $LayoutSettings as ConfirmationDialog
@onready var layout_name := %LayoutName as LineEdit
@onready var layout_from := %LayoutFrom as OptionButton
@onready var delete_confirmation := $DeleteConfirmation as ConfirmationDialog
@onready var mimic_ui := %LayoutPreview as DockableContainer


func _ready() -> void:
	# Fill the copy layout from option button with the default layouts
	for layout in Global.default_layouts:
		layout_from.add_item(layout.resource_path.get_basename().get_file())


func _on_ManageLayouts_about_to_show() -> void:
	for layout in Global.layouts:
		layout_list.add_item(layout.resource_path.get_basename().get_file())
	refresh_preview()
	if layout_selected != -1:
		layout_list.select(layout_selected)


func _on_ManageLayouts_visibility_changed() -> void:
	if visible:
		return
	layout_list.clear()
	Global.dialog_open(false)


func _on_SavedLayouts_item_activated(index: int) -> void:
	Global.top_menu_container.set_layout(index)


func _on_SavedLayouts_item_selected(index: int) -> void:
	layout_selected = index
	rename_layout.disabled = false
	delete_layout.disabled = false
	refresh_preview()


func _on_SavedLayouts_empty_clicked(_position: Vector2, _button_index: int) -> void:
	rename_layout.disabled = true
	delete_layout.disabled = true


func _on_AddLayout_pressed() -> void:
	is_editing = false
	layout_name.text = "New Layout"
	layout_settings.title = "Add Layout"
	layout_from.get_parent().visible = true
	layout_settings.popup_centered()


func _on_rename_layout_pressed() -> void:
	is_editing = true
	layout_name.text = layout_list.get_item_text(layout_selected)
	layout_settings.title = "Rename Layout"
	layout_from.get_parent().visible = false
	layout_settings.popup_centered()


func _on_DeleteLayout_pressed() -> void:
	delete_confirmation.popup_centered()


func _on_LayoutSettings_confirmed() -> void:
	var file_name := layout_name.text + ".tres"
	var path := Global.LAYOUT_DIR.path_join(file_name)
	var layout: DockableLayout
	if layout_from.selected == 0:
		layout = Global.control.main_ui.layout.clone()
	else:
		layout = Global.default_layouts[layout_from.selected - 1].clone()
	layout.resource_name = layout_name.text
	layout.resource_path = path
	var err := ResourceSaver.save(layout, path)
	if err != OK:
		print(err)
		return
	if is_editing:
		var old_file_name: String = layout_list.get_item_text(layout_selected) + ".tres"
		if old_file_name != file_name:
			delete_layout_file(old_file_name)
		Global.layouts[layout_selected] = layout
		layout_list.set_item_text(layout_selected, layout_name.text)
	else:
		Global.layouts.append(layout)
		# Save the layout every time it changes
		layout.save_on_change = true
		Global.control.main_ui.layout = layout
		layout_list.add_item(layout_name.text)
	Global.layouts.sort_custom(
		func(a: DockableLayout, b: DockableLayout):
			return a.resource_path.get_file() < b.resource_path.get_file()
	)
	var layout_index := Global.layouts.find(layout)
	Global.top_menu_container.populate_layouts_submenu()
	Global.top_menu_container.layouts_submenu.set_item_checked(layout_index + 1, true)


func delete_layout_file(file_name: String) -> void:
	var dir := DirAccess.open(Global.LAYOUT_DIR)
	if not is_instance_valid(dir):
		return
	dir.remove(Global.LAYOUT_DIR.path_join(file_name))


func _on_DeleteConfirmation_confirmed() -> void:
	delete_layout_file(layout_list.get_item_text(layout_selected) + ".tres")
	Global.layouts.remove_at(layout_selected)
	layout_list.remove_item(layout_selected)
	Global.top_menu_container.populate_layouts_submenu()
	layout_selected = -1
	rename_layout.disabled = true
	delete_layout.disabled = true
	refresh_preview()


func refresh_preview() -> void:
	for tab in mimic_ui.get_tabs():
		mimic_ui.remove_child(tab)
		tab.queue_free()
	for item in Global.control.main_ui.get_tabs():
		var box := TextEdit.new()
		box.name = item.name
		box.text = item.name
		box.editable = false
		mimic_ui.add_child(box)
	if layout_selected == -1:
		mimic_ui.visible = false
		return
	mimic_ui.visible = true
	mimic_ui.set_layout(Global.layouts[layout_selected].clone())
