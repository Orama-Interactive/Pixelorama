extends EditorProperty

const DockableContainer = preload("../dockable_container.gd")
const Layout = preload("../layout.gd")

var _container = DockableContainer.new()
var _hidden_menu_button = MenuButton.new()
var _hidden_menu_popup: PopupMenu
var _hidden_menu_list: PoolStringArray


func _ready() -> void:
	rect_min_size = Vector2(128, 256)

	_hidden_menu_button.text = "Visible nodes"
	add_child(_hidden_menu_button)
	_hidden_menu_popup = _hidden_menu_button.get_popup()
	_hidden_menu_popup.hide_on_checkable_item_selection = false
	_hidden_menu_popup.connect("about_to_show", self, "_on_hidden_menu_popup_about_to_show")
	_hidden_menu_popup.connect("id_pressed", self, "_on_hidden_menu_popup_id_pressed")

	_container.clone_layout_on_ready = false
	_container.rect_min_size = rect_min_size

	var original_container: DockableContainer = get_edited_object()
	var value = original_container.get(get_edited_property())
	_container.set(get_edited_property(), value)
	for n in value.get_names():
		var child = _create_child_control(n)
		_container.add_child(child)
	add_child(_container)
	set_bottom_editor(_container)


func update_property() -> void:
	var value = _get_layout()
	_container.set(get_edited_property(), value)


func _get_layout() -> Layout:
	var original_container: DockableContainer = get_edited_object()
	return original_container.get(get_edited_property())


func _create_child_control(named: String) -> Control:
	var new_control = Label.new()
	new_control.name = named
	new_control.align = Label.ALIGN_CENTER
	new_control.valign = Label.VALIGN_CENTER
	new_control.clip_text = true
	new_control.text = named
	return new_control


func _on_hidden_menu_popup_about_to_show() -> void:
	var layout = _get_layout()
	_hidden_menu_popup.clear()
	_hidden_menu_list = layout.get_names()
	for i in _hidden_menu_list.size():
		var tab_name = _hidden_menu_list[i]
		_hidden_menu_popup.add_check_item(tab_name, i)
		_hidden_menu_popup.set_item_checked(i, not layout.is_tab_hidden(tab_name))


func _on_hidden_menu_popup_id_pressed(id: int) -> void:
	var layout = _get_layout()
	var tab_name = _hidden_menu_list[id]
	var new_hidden = not layout.is_tab_hidden(tab_name)
	layout.set_tab_hidden(tab_name, new_hidden)
	_hidden_menu_popup.set_item_checked(id, not new_hidden)
	emit_changed(get_edited_property(), layout)
