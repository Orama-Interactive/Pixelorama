extends EditorInspectorPlugin

const DockableContainer = preload("../dockable_container.gd")
const LayoutEditorProperty = preload("layout_editor_property.gd")


func can_handle(object: Object) -> bool:
	return object is DockableContainer


func parse_property(
	_object: Object, _type: int, path: String, _hint: int, _hint_text: String, _usage: int
) -> bool:
	if path == "layout":
		var editor_property = LayoutEditorProperty.new()
		add_property_editor("layout", editor_property)
	return false
