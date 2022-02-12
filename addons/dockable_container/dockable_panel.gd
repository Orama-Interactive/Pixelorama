tool
extends TabContainer

signal tab_layout_changed(tab)

const ReferenceControl = preload("dockable_panel_reference_control.gd")
const Layout = preload("layout.gd")

var leaf: Layout.LayoutPanel setget set_leaf, get_leaf

var _leaf: Layout.LayoutPanel


func _ready() -> void:
	drag_to_rearrange_enabled = true


func _enter_tree() -> void:
	connect("tab_selected", self, "_on_tab_selected")
	connect("tab_changed", self, "_on_tab_changed")


func _exit_tree() -> void:
	disconnect("tab_selected", self, "_on_tab_selected")
	disconnect("tab_changed", self, "_on_tab_changed")


func track_nodes(nodes: Array, new_leaf: Layout.LayoutPanel) -> void:
	_leaf = null  # avoid using previous leaf in tab_changed signals
	var min_size = min(nodes.size(), get_child_count())
	# remove spare children
	for i in range(min_size, get_child_count()):
		var child = get_child(min_size)
		child.reference_to = null
		remove_child(child)
		child.queue_free()
	# add missing children
	for i in range(min_size, nodes.size()):
		var ref_control = ReferenceControl.new()
		add_child(ref_control)
	assert(nodes.size() == get_child_count(), "FIXME")
	# setup children
	for i in nodes.size():
		var ref_control: ReferenceControl = get_child(i)
		ref_control.reference_to = nodes[i]
		set_tab_title(i, nodes[i].name)
	set_leaf(new_leaf)


func get_child_rect() -> Rect2:
	var control = get_current_tab_control()
	return Rect2(rect_position + control.rect_position, control.rect_size)


func set_leaf(value: Layout.LayoutPanel) -> void:
	if get_tab_count() > 0 and value:
		current_tab = clamp(value.current_tab, 0, get_tab_count() - 1)
	_leaf = value


func get_leaf() -> Layout.LayoutPanel:
	return _leaf


func get_layout_minimum_size() -> Vector2:
	return get_combined_minimum_size()


func _on_tab_selected(tab: int) -> void:
	if _leaf:
		_leaf.current_tab = tab


func _on_tab_changed(tab: int) -> void:
	if not _leaf:
		return
	var tab_name = get_tab_control(tab).name
	var name_index_in_leaf = _leaf.find_name(tab_name)
	if name_index_in_leaf != tab:  # NOTE: this handles added tabs (index == -1)
		emit_signal("tab_layout_changed", tab)
