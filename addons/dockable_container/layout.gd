@tool
class_name DockableLayout
extends Resource
## DockableLayout Resource definition, holding the root DockableLayoutNode and hidden tabs.
##
## DockableLayoutSplit are binary trees with nested DockableLayoutSplit subtrees
## and DockableLayoutPanel leaves. Both of them inherit from DockableLayoutNode to help with
## type annotation and define common functionality.
##
## Hidden tabs are marked in the `hidden_tabs` Dictionary by name.

enum { MARGIN_LEFT, MARGIN_RIGHT, MARGIN_TOP, MARGIN_BOTTOM, MARGIN_CENTER }

@export var root: DockableLayoutNode = DockableLayoutPanel.new():
	get:
		return _root
	set(value):
		set_root(value)
@export var hidden_tabs := {}:
	get:
		return _hidden_tabs
	set(value):
		if value != _hidden_tabs:
			_hidden_tabs = value
			changed.emit()

var _changed_signal_queued := false
var _first_leaf: DockableLayoutPanel
var _hidden_tabs: Dictionary
var _leaf_by_node_name: Dictionary
var _root: DockableLayoutNode = DockableLayoutPanel.new()


func _init() -> void:
	resource_name = "Layout"


func set_root(value: DockableLayoutNode, should_emit_changed := true) -> void:
	if not value:
		value = DockableLayoutPanel.new()
	if _root == value:
		return
	if _root and _root.changed.is_connected(_on_root_changed):
		_root.changed.disconnect(_on_root_changed)
	_root = value
	_root.parent = null
	_root.changed.connect(_on_root_changed)
	if should_emit_changed:
		_on_root_changed()


func get_root() -> DockableLayoutNode:
	return _root


func clone() -> DockableLayout:
	return duplicate(true)


func get_names() -> PackedStringArray:
	return _root.get_names()


## Add missing nodes on first leaf and remove nodes outside indices from leaves.
##
## _leaf_by_node_name = {
##     (string keys) = respective Leaf that holds the node name,
## }
func update_nodes(names: PackedStringArray) -> void:
	_leaf_by_node_name.clear()
	_first_leaf = null
	var empty_leaves: Array[DockableLayoutPanel] = []
	_ensure_names_in_node(_root, names, empty_leaves)  # Changes _leaf_by_node_name and empty_leaves
	for l in empty_leaves:
		_remove_leaf(l)
	if not _first_leaf:
		_first_leaf = DockableLayoutPanel.new()
		set_root(_first_leaf)
	for n in names:
		if not _leaf_by_node_name.has(n):
			_first_leaf.push_name(n)
			_leaf_by_node_name[n] = _first_leaf
	_on_root_changed()


func move_node_to_leaf(node: Node, leaf: DockableLayoutPanel, relative_position: int) -> void:
	var node_name := node.name
	var previous_leaf: DockableLayoutPanel = _leaf_by_node_name.get(node_name)
	if previous_leaf:
		previous_leaf.remove_node(node)
		if previous_leaf.is_empty():
			_remove_leaf(previous_leaf)

	leaf.insert_node(relative_position, node)
	_leaf_by_node_name[node_name] = leaf
	_on_root_changed()


func get_leaf_for_node(node: Node) -> DockableLayoutPanel:
	return _leaf_by_node_name.get(node.name)


func split_leaf_with_node(leaf: DockableLayoutPanel, node: Node, margin: int) -> void:
	var root_branch := leaf.parent
	var new_leaf := DockableLayoutPanel.new()
	var new_branch := DockableLayoutSplit.new()
	if margin == MARGIN_LEFT or margin == MARGIN_RIGHT:
		new_branch.direction = DockableLayoutSplit.Direction.HORIZONTAL
	else:
		new_branch.direction = DockableLayoutSplit.Direction.VERTICAL
	if margin == MARGIN_LEFT or margin == MARGIN_TOP:
		new_branch.first = new_leaf
		new_branch.second = leaf
	else:
		new_branch.first = leaf
		new_branch.second = new_leaf
	if _root == leaf:
		set_root(new_branch, false)
	elif root_branch:
		if leaf == root_branch.first:
			root_branch.first = new_branch
		else:
			root_branch.second = new_branch

	move_node_to_leaf(node, new_leaf, 0)


func add_node(node: Node) -> void:
	var node_name := node.name
	if _leaf_by_node_name.has(node_name):
		return
	_first_leaf.push_name(node_name)
	_leaf_by_node_name[node_name] = _first_leaf
	_on_root_changed()


func remove_node(node: Node) -> void:
	var node_name := node.name
	var leaf: DockableLayoutPanel = _leaf_by_node_name.get(node_name)
	if not leaf:
		return
	leaf.remove_node(node)
	_leaf_by_node_name.erase(node_name)
	if leaf.is_empty():
		_remove_leaf(leaf)
	_on_root_changed()


func rename_node(previous_name: String, new_name: String) -> void:
	var leaf: DockableLayoutPanel = _leaf_by_node_name.get(previous_name)
	if not leaf:
		return
	leaf.rename_node(previous_name, new_name)
	_leaf_by_node_name.erase(previous_name)
	_leaf_by_node_name[new_name] = leaf
	_on_root_changed()


func set_tab_hidden(name: String, hidden: bool) -> void:
	if not _leaf_by_node_name.has(name):
		return
	if hidden:
		_hidden_tabs[name] = true
	else:
		_hidden_tabs.erase(name)
	_on_root_changed()


func is_tab_hidden(name: String) -> bool:
	return _hidden_tabs.get(name, false)


func set_node_hidden(node: Node, hidden: bool) -> void:
	set_tab_hidden(node.name, hidden)


func is_node_hidden(node: Node) -> bool:
	return is_tab_hidden(node.name)


func _on_root_changed() -> void:
	if _changed_signal_queued:
		return
	_changed_signal_queued = true
	set_deferred("_changed_signal_queued", false)
	emit_changed.call_deferred()


func _ensure_names_in_node(
	node: DockableLayoutNode, names: PackedStringArray, empty_leaves: Array[DockableLayoutPanel]
) -> void:
	if node is DockableLayoutPanel:
		node.update_nodes(names, _leaf_by_node_name)  # This changes _leaf_by_node_name
		if node.is_empty():
			empty_leaves.append(node)
		if not _first_leaf:
			_first_leaf = node
	elif node is DockableLayoutSplit:
		_ensure_names_in_node(node.first, names, empty_leaves)
		_ensure_names_in_node(node.second, names, empty_leaves)
	else:
		assert(false, "Invalid Resource, should be branch or leaf, found %s" % node)


func _remove_leaf(leaf: DockableLayoutPanel) -> void:
	assert(leaf.is_empty(), "FIXME: trying to remove_at a leaf with nodes")
	if _root == leaf:
		return
	var collapsed_branch := leaf.parent
	assert(collapsed_branch is DockableLayoutSplit, "FIXME: leaf is not a child of branch")
	var kept_branch: DockableLayoutNode = (
		collapsed_branch.first if leaf == collapsed_branch.second else collapsed_branch.second
	)
	var root_branch := collapsed_branch.parent  #HERE
	if collapsed_branch == _root:
		set_root(kept_branch, true)
	elif root_branch:
		if collapsed_branch == root_branch.first:
			root_branch.first = kept_branch
		else:
			root_branch.second = kept_branch


func _print_tree() -> void:
	print("TREE")
	_print_tree_step(_root, 0, 0)
	print("")


func _print_tree_step(tree_or_leaf: DockableLayoutNode, level: int, idx: int) -> void:
	if tree_or_leaf is DockableLayoutPanel:
		print(" |".repeat(level), "- (%d) = " % idx, tree_or_leaf.names)
	elif tree_or_leaf is DockableLayoutSplit:
		print(
			" |".repeat(level),
			"-+ (%d) = " % idx,
			tree_or_leaf.direction,
			" ",
			tree_or_leaf.percent
		)
		_print_tree_step(tree_or_leaf.first, level + 1, 1)
		_print_tree_step(tree_or_leaf.second, level + 1, 2)
