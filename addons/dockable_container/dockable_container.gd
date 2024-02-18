@tool
class_name DockableContainer
extends Container

const SplitHandle := preload("split_handle.gd")
const DockablePanel := preload("dockable_panel.gd")
const DragNDropPanel := preload("drag_n_drop_panel.gd")

@export var tab_alignment := TabBar.ALIGNMENT_CENTER:
	get:
		return _tab_align
	set(value):
		_tab_align = value
		for i in range(1, _panel_container.get_child_count()):
			var panel := _panel_container.get_child(i) as DockablePanel
			panel.tab_alignment = value
@export var use_hidden_tabs_for_min_size := false:
	get:
		return _use_hidden_tabs_for_min_size
	set(value):
		_use_hidden_tabs_for_min_size = value
		for i in range(1, _panel_container.get_child_count()):
			var panel := _panel_container.get_child(i) as DockablePanel
			panel.use_hidden_tabs_for_min_size = value
@export var tabs_visible := true:
	get:
		return _tabs_visible
	set(value):
		_tabs_visible = value
		for i in range(1, _panel_container.get_child_count()):
			var panel := _panel_container.get_child(i) as DockablePanel
			panel.show_tabs = _tabs_visible
## If [code]true[/code] and a panel only has one tab, it keeps that tab hidden even if
## [member tabs_visible] is [code]true[/code].
## Only takes effect is [member tabs_visible] is [code]true[/code].
@export var hide_single_tab := false:
	get:
		return _hide_single_tab
	set(value):
		_hide_single_tab = value
		for i in range(1, _panel_container.get_child_count()):
			var panel := _panel_container.get_child(i) as DockablePanel
			panel.hide_single_tab = _hide_single_tab
@export var rearrange_group := 0
@export var layout := DockableLayout.new():
	get:
		return _layout
	set(value):
		set_layout(value)
## If `clone_layout_on_ready` is true, `layout` will be cloned checked `_ready`.
## This is useful for leaving layout Resources untouched in case you want to
## restore layout to its default later.
@export var clone_layout_on_ready := true

var _layout := DockableLayout.new()
var _panel_container := Container.new()
var _split_container := Container.new()
var _drag_n_drop_panel := DragNDropPanel.new()
var _drag_panel: DockablePanel
var _tab_align := TabBar.ALIGNMENT_CENTER
var _tabs_visible := true
var _use_hidden_tabs_for_min_size := false
var _hide_single_tab := false
var _current_panel_index := 0
var _current_split_index := 0
var _children_names := {}
var _layout_dirty := false


func _init() -> void:
	child_entered_tree.connect(_child_entered_tree)
	child_exiting_tree.connect(_child_exiting_tree)


func _ready() -> void:
	set_process_input(false)
	_panel_container.name = "_panel_container"
	add_child(_panel_container)
	move_child(_panel_container, 0)
	_split_container.name = "_split_container"
	_split_container.mouse_filter = MOUSE_FILTER_PASS
	_panel_container.add_child(_split_container)

	_drag_n_drop_panel.name = "_drag_n_drop_panel"
	_drag_n_drop_panel.mouse_filter = MOUSE_FILTER_PASS
	_drag_n_drop_panel.visible = false
	add_child(_drag_n_drop_panel)

	if not _layout:
		set_layout(null)
	elif clone_layout_on_ready and not Engine.is_editor_hint():
		set_layout(_layout.clone())


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_resort()
	elif (
		what == NOTIFICATION_DRAG_BEGIN
		and _can_handle_drag_data(get_viewport().gui_get_drag_data())
	):
		_drag_n_drop_panel.set_enabled(true, not _layout.root.is_empty())
		set_process_input(true)
	elif what == NOTIFICATION_DRAG_END:
		_drag_n_drop_panel.set_enabled(false)
		set_process_input(false)


func _input(event: InputEvent) -> void:
	assert(get_viewport().gui_is_dragging(), "FIXME: should only be called when dragging")
	if event is InputEventMouseMotion:
		var local_position := get_local_mouse_position()
		var panel: DockablePanel
		for i in range(1, _panel_container.get_child_count()):
			var p := _panel_container.get_child(i) as DockablePanel
			if p.get_rect().has_point(local_position):
				panel = p
				break
		_drag_panel = panel
		if not panel:
			return
		fit_child_in_rect(_drag_n_drop_panel, panel.get_child_rect())


func _child_entered_tree(node: Node) -> void:
	if node == _panel_container or node == _drag_n_drop_panel:
		return
	_drag_n_drop_panel.move_to_front()
	_track_and_add_node(node)


func _child_exiting_tree(node: Node) -> void:
	if node == _panel_container or node == _drag_n_drop_panel:
		return
	_untrack_node(node)


func _can_drop_data(_position: Vector2, data) -> bool:
	return _can_handle_drag_data(data)


func _drop_data(_position: Vector2, data) -> void:
	var from_node := get_node(data.from_path)
	if from_node is TabBar:
		from_node = from_node.get_parent()
	if from_node == _drag_panel and _drag_panel.get_child_count() == 1:
		return
	var tab_index = data.tabc_element if data.has("tabc_element") else data.tab_index
	var moved_tab = from_node.get_tab_control(tab_index)
	if moved_tab is DockableReferenceControl:
		moved_tab = moved_tab.reference_to
	if not _is_managed_node(moved_tab):
		moved_tab.get_parent().remove_child(moved_tab)
		add_child(moved_tab)

	if _drag_panel != null:
		var margin := _drag_n_drop_panel.get_hover_margin()
		_layout.split_leaf_with_node(_drag_panel.leaf, moved_tab, margin)

	_layout_dirty = true
	queue_sort()


func set_control_as_current_tab(control: Control) -> void:
	assert(
		control.get_parent_control() == self,
		"Trying to focus a control not managed by this container"
	)
	if is_control_hidden(control):
		push_warning("Trying to focus a hidden control")
		return
	var leaf := _layout.get_leaf_for_node(control)
	if not leaf:
		return
	var position_in_leaf := leaf.find_child(control)
	if position_in_leaf < 0:
		return
	var panel: DockablePanel
	for i in range(1, _panel_container.get_child_count()):
		var p := _panel_container.get_child(i) as DockablePanel
		if p.leaf == leaf:
			panel = p
			break
	if not panel:
		return
	panel.current_tab = clampi(position_in_leaf, 0, panel.get_tab_count() - 1)


func set_layout(value: DockableLayout) -> void:
	if value == null:
		value = DockableLayout.new()
	if value == _layout:
		return
	if _layout and _layout.changed.is_connected(queue_sort):
		_layout.changed.disconnect(queue_sort)
	_layout = value
	_layout.changed.connect(queue_sort)
	_layout_dirty = true
	queue_sort()


func set_use_hidden_tabs_for_min_size(value: bool) -> void:
	_use_hidden_tabs_for_min_size = value
	for i in range(1, _panel_container.get_child_count()):
		var panel = _panel_container.get_child(i)
		panel.use_hidden_tabs_for_min_size = value


func get_use_hidden_tabs_for_min_size() -> bool:
	return _use_hidden_tabs_for_min_size


func set_control_hidden(child: Control, is_hidden: bool) -> void:
	_layout.set_node_hidden(child, is_hidden)


func is_control_hidden(child: Control) -> bool:
	return _layout.is_node_hidden(child)


func get_tabs() -> Array[Control]:
	var tabs: Array[Control] = []
	for i in get_child_count():
		var child := get_child(i)
		if _is_managed_node(child):
			tabs.append(child)
	return tabs


func get_tab_count() -> int:
	var count := 0
	for i in get_child_count():
		var child := get_child(i)
		if _is_managed_node(child):
			count += 1
	return count


func _can_handle_drag_data(data) -> bool:
	if data is Dictionary and data.get("type") in ["tab_container_tab", "tabc_element"]:
		var tabc := get_node_or_null(data.get("from_path"))
		return (
			tabc
			and tabc.has_method("get_tabs_rearrange_group")
			and tabc.get_tabs_rearrange_group() == rearrange_group
		)
	return false


func _is_managed_node(node: Node) -> bool:
	return (
		node.get_parent() == self
		and node != _panel_container
		and node != _drag_n_drop_panel
		and node is Control
		and not node.top_level
	)


func _update_layout_with_children() -> void:
	var names := PackedStringArray()
	_children_names.clear()
	for i in range(1, get_child_count() - 1):
		var c := get_child(i)
		if _track_node(c):
			names.append(c.name)
	_layout.update_nodes(names)
	_layout_dirty = false


func _track_node(node: Node) -> bool:
	if not _is_managed_node(node):
		return false
	_children_names[node] = node.name
	_children_names[node.name] = node
	if not node.renamed.is_connected(_on_child_renamed):
		node.renamed.connect(_on_child_renamed.bind(node))
	if not node.tree_exiting.is_connected(_untrack_node):
		node.tree_exiting.connect(_untrack_node.bind(node))
	return true


func _track_and_add_node(node: Node) -> void:
	var tracked_name = _children_names.get(node)
	if not _track_node(node):
		return
	if tracked_name and tracked_name != node.name:
		_layout.rename_node(tracked_name, node.name)
	_layout_dirty = true


func _untrack_node(node: Node) -> void:
	_children_names.erase(node)
	_children_names.erase(node.name)
	if node.renamed.is_connected(_on_child_renamed):
		node.renamed.disconnect(_on_child_renamed)
	if node.tree_exiting.is_connected(_untrack_node):
		node.tree_exiting.disconnect(_untrack_node)
	_layout_dirty = true


func _resort() -> void:
	assert(_panel_container, "FIXME: resorting without _panel_container")
	if _panel_container.get_index() != 0:
		move_child(_panel_container, 0)
	if _drag_n_drop_panel.get_index() < get_child_count() - 1:
		_drag_n_drop_panel.move_to_front()

	if _layout_dirty:
		_update_layout_with_children()

	var rect := Rect2(Vector2.ZERO, size)
	fit_child_in_rect(_panel_container, rect)
	_panel_container.fit_child_in_rect(_split_container, rect)

	_current_panel_index = 1
	_current_split_index = 0

	var children_list := []
	_calculate_panel_and_split_list(children_list, _layout.root)
	_fit_panel_and_split_list_to_rect(children_list, rect)

	_untrack_children_after(_panel_container, _current_panel_index)
	_untrack_children_after(_split_container, _current_split_index)


## Calculate DockablePanel and SplitHandle minimum sizes, skipping empty
## branches.
##
## Returns a DockablePanel checked non-empty leaves, a SplitHandle checked non-empty
## splits, `null` if the whole branch is empty and no space should be used.
##
## `result` will be filled with the non-empty nodes in this post-order tree
## traversal.
func _calculate_panel_and_split_list(result: Array, layout_node: DockableLayoutNode):
	if layout_node is DockableLayoutPanel:
		var nodes: Array[Control] = []
		for n in layout_node.names:
			var node: Control = _children_names.get(n)
			if node:
				assert(node is Control, "FIXME: node is not a control %s" % node)
				assert(
					node.get_parent_control() == self,
					"FIXME: node is not child of container %s" % node
				)
				if is_control_hidden(node):
					node.visible = false
				else:
					nodes.append(node)
		if nodes.is_empty():
			return null
		else:
			var panel := _get_panel(_current_panel_index)
			_current_panel_index += 1
			panel.track_nodes(nodes, layout_node)
			result.append(panel)
			return panel
	elif layout_node is DockableLayoutSplit:
		# by processing `second` before `first`, traversing `result` from back
		# to front yields a nice pre-order tree traversal
		var second_result = _calculate_panel_and_split_list(result, layout_node.second)
		var first_result = _calculate_panel_and_split_list(result, layout_node.first)
		if first_result and second_result:
			var split := _get_split(_current_split_index)
			_current_split_index += 1
			split.layout_split = layout_node
			split.first_minimum_size = first_result.get_layout_minimum_size()
			split.second_minimum_size = second_result.get_layout_minimum_size()
			result.append(split)
			return split
		elif first_result:
			return first_result
		else:  # NOTE: this returns null if `second_result` is null
			return second_result
	else:
		push_warning("FIXME: invalid Resource, should be branch or leaf, found %s" % layout_node)


## Traverse list from back to front fitting controls where they belong.
##
## Be sure to call this with the result from `_calculate_split_minimum_sizes`.
func _fit_panel_and_split_list_to_rect(panel_and_split_list: Array, rect: Rect2) -> void:
	var control = panel_and_split_list.pop_back()
	if control is DockablePanel:
		_panel_container.fit_child_in_rect(control, rect)
	elif control is SplitHandle:
		var split_rects = control.get_split_rects(rect)
		_split_container.fit_child_in_rect(control, split_rects["self"])
		_fit_panel_and_split_list_to_rect(panel_and_split_list, split_rects["first"])
		_fit_panel_and_split_list_to_rect(panel_and_split_list, split_rects["second"])


## Get the idx'th DockablePanel, reusing an instanced one if possible
func _get_panel(idx: int) -> DockablePanel:
	assert(_panel_container, "FIXME: creating panel without _panel_container")
	if idx < _panel_container.get_child_count():
		return _panel_container.get_child(idx)
	var panel := DockablePanel.new()
	panel.tab_alignment = _tab_align
	panel.show_tabs = _tabs_visible
	panel.hide_single_tab = _hide_single_tab
	panel.use_hidden_tabs_for_min_size = _use_hidden_tabs_for_min_size
	panel.set_tabs_rearrange_group(maxi(0, rearrange_group))
	_panel_container.add_child(panel)
	panel.tab_layout_changed.connect(_on_panel_tab_layout_changed.bind(panel))
	return panel


## Get the idx'th SplitHandle, reusing an instanced one if possible
func _get_split(idx: int) -> SplitHandle:
	assert(_split_container, "FIXME: creating split without _split_container")
	if idx < _split_container.get_child_count():
		return _split_container.get_child(idx)
	var split := SplitHandle.new()
	_split_container.add_child(split)
	return split


## Helper for removing and freeing all remaining children from node
func _untrack_children_after(node: Control, idx: int) -> void:
	for i in range(idx, node.get_child_count()):
		var child := node.get_child(idx)
		node.remove_child(child)
		child.queue_free()


## Handler for `DockablePanel.tab_layout_changed`, update its DockableLayoutPanel
func _on_panel_tab_layout_changed(tab: int, panel: DockablePanel) -> void:
	_layout_dirty = true
	var control := panel.get_tab_control(tab)
	if control is DockableReferenceControl:
		control = control.reference_to
	if not _is_managed_node(control):
		control.get_parent().remove_child(control)
		add_child(control)
	_layout.move_node_to_leaf(control, panel.leaf, tab)
	queue_sort()


## Handler for `Node.renamed` signal, updates tracked name for node
func _on_child_renamed(child: Node) -> void:
	var old_name: String = _children_names.get(child)
	if old_name == str(child.name):
		return
	_children_names.erase(old_name)
	_children_names[child] = child.name
	_children_names[child.name] = child
	_layout.rename_node(old_name, child.name)
