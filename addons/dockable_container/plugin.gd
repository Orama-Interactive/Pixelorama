@tool
extends EditorPlugin

const LayoutInspectorPlugin := preload("inspector_plugin/editor_inspector_plugin.gd")
const Icon := preload("icon.svg")

var _layout_inspector_plugin: LayoutInspectorPlugin


func _enter_tree() -> void:
	_layout_inspector_plugin = LayoutInspectorPlugin.new()
	add_custom_type("DockableContainer", "Container", DockableContainer, Icon)
	add_inspector_plugin(_layout_inspector_plugin)


func _exit_tree() -> void:
	remove_inspector_plugin(_layout_inspector_plugin)
	remove_custom_type("DockableContainer")
	_layout_inspector_plugin = null
