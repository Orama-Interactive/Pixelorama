tool
extends EditorPlugin

const DockableContainer = preload("dockable_container.gd")
const LayoutInspectorPlugin = preload("inspector_plugin/editor_inspector_plugin.gd")

var _layout_inspector_plugin


func _enter_tree() -> void:
	_layout_inspector_plugin = LayoutInspectorPlugin.new()
	add_custom_type("DockableContainer", "Container", DockableContainer, null)
	add_inspector_plugin(_layout_inspector_plugin)


func _exit_tree() -> void:
	remove_inspector_plugin(_layout_inspector_plugin)
	remove_custom_type("DockableContainer")
	_layout_inspector_plugin = null
