@tool
extends TabContainer

signal tab_layout_changed(tab)

var leaf: DockableLayoutPanel:
	get:
		return get_leaf()
	set(value):
		set_leaf(value)
var show_tabs := true:
	get:
		return _show_tabs
	set(value):
		_show_tabs = value
		_handle_tab_visibility()
var hide_single_tab := false:
	get:
		return _hide_single_tab
	set(value):
		_hide_single_tab = value
		_handle_tab_visibility()

var _leaf: DockableLayoutPanel
var _show_tabs := true
var _hide_single_tab := false


func _ready() -> void:
	drag_to_rearrange_enabled = true


func _enter_tree() -> void:
	active_tab_rearranged.connect(_on_tab_changed)
	tab_selected.connect(_on_tab_selected)
	tab_changed.connect(_on_tab_changed)


func _exit_tree() -> void:
	active_tab_rearranged.disconnect(_on_tab_changed)
	tab_selected.disconnect(_on_tab_selected)
	tab_changed.disconnect(_on_tab_changed)


func track_nodes(nodes: Array[Control], new_leaf: DockableLayoutPanel) -> void:
	_leaf = null  # avoid using previous leaf in tab_changed signals
	var min_size := mini(nodes.size(), get_child_count())
	# remove spare children
	for i in range(min_size, get_child_count()):
		var child := get_child(min_size) as DockableReferenceControl
		child.reference_to = null
		remove_child(child)
		child.queue_free()
	# add missing children
	for i in range(min_size, nodes.size()):
		var ref_control := DockableReferenceControl.new()
		add_child(ref_control)
	assert(nodes.size() == get_child_count(), "FIXME")
	# setup children
	for i in nodes.size():
		var ref_control := get_child(i) as DockableReferenceControl
		ref_control.reference_to = nodes[i]
		set_tab_title(i, nodes[i].name)
	set_leaf(new_leaf)
	_handle_tab_visibility()


func get_child_rect() -> Rect2:
	var control := get_current_tab_control()
	return Rect2(position + control.position, control.size)


func set_leaf(value: DockableLayoutPanel) -> void:
	if get_tab_count() > 0 and value:
		current_tab = clampi(value.current_tab, 0, get_tab_count() - 1)
	_leaf = value


func get_leaf() -> DockableLayoutPanel:
	return _leaf


func get_layout_minimum_size() -> Vector2:
	return get_combined_minimum_size()


func _on_tab_selected(tab: int) -> void:
	if _leaf:
		_leaf.current_tab = tab


func _on_tab_changed(tab: int) -> void:
	if not _leaf:
		return
	var control := get_tab_control(tab)
	if not control:
		return
	var tab_name := control.name
	var name_index_in_leaf := _leaf.find_name(tab_name)
	if name_index_in_leaf != tab:  # NOTE: this handles added tabs (index == -1)
		tab_layout_changed.emit(tab)


func _handle_tab_visibility() -> void:
	if _hide_single_tab and get_tab_count() == 1:
		tabs_visible = false
	else:
		tabs_visible = _show_tabs
