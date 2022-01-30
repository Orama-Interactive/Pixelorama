tool
extends "layout_node.gd"
# Layout leaf nodes, defining tabs

export(PoolStringArray) var names: PoolStringArray setget set_names, get_names
export(int) var current_tab: int setget set_current_tab, get_current_tab

var _names := PoolStringArray()
var _current_tab := 0


func _init() -> void:
	resource_name = "Tabs"


func clone():
	var new_panel = get_script().new()
	new_panel._names = _names
	new_panel._current_tab = _current_tab
	return new_panel


func set_current_tab(value: int) -> void:
	if value != _current_tab:
		_current_tab = value
		emit_tree_changed()


func get_current_tab() -> int:
	return int(clamp(_current_tab, 0, _names.size() - 1))


func set_names(value: PoolStringArray) -> void:
	_names = value
	emit_tree_changed()


func get_names() -> PoolStringArray:
	return _names


func push_name(name: String) -> void:
	_names.append(name)
	emit_tree_changed()


func insert_node(position: int, node: Node) -> void:
	_names.insert(position, node.name)
	emit_tree_changed()


func find_name(node_name: String) -> int:
	for i in _names.size():
		if _names[i] == node_name:
			return i
	return -1


func find_node(node: Node):
	return find_name(node.name)


func remove_node(node: Node) -> void:
	var i = find_node(node)
	if i >= 0:
		_names.remove(i)
		emit_tree_changed()
	else:
		push_warning("Remove failed, node '%s' was not found" % node)


func rename_node(previous_name: String, new_name: String) -> void:
	var i = find_name(previous_name)
	if i >= 0:
		_names.set(i, new_name)
		emit_tree_changed()
	else:
		push_warning("Rename failed, name '%s' was not found" % previous_name)


func empty() -> bool:
	return _names.empty()


func update_nodes(node_names: PoolStringArray, data: Dictionary):
	var i = 0
	var removed_any = false
	while i < _names.size():
		var current = _names[i]
		if not current in node_names or data.has(current):
			_names.remove(i)
			removed_any = true
		else:
			data[current] = self
			i += 1
	if removed_any:
		emit_tree_changed()
