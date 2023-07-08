extends EditorInspectorPlugin

const LayoutEditorProperty := preload("layout_editor_property.gd")


func _can_handle(object: Object) -> bool:
	return object is DockableContainer


func _parse_property(
	_object: Object,
	_type: Variant.Type,
	name: String,
	_hint: PropertyHint,
	_hint_text: String,
	_usage: int,
	_wide: bool
) -> bool:
	if name == "layout":
		var editor_property := LayoutEditorProperty.new()
		add_property_editor("layout", editor_property)
	return false
