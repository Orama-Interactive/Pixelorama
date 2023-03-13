tool
extends Container
# Control that mimics its own visibility and rect into another Control.

var reference_to: Control setget set_reference_to, get_reference_to

var _reference_to: Control = null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _reference_to:
		_reference_to.visible = visible
	elif what == NOTIFICATION_SORT_CHILDREN and _reference_to:
		_reposition_reference()


func _get_minimum_size() -> Vector2:
	return _reference_to.get_combined_minimum_size() if _reference_to else Vector2.ZERO


func set_reference_to(control: Control) -> void:
	if _reference_to != control:
		if _reference_to:
			_reference_to.disconnect("renamed", self, "_on_reference_to_renamed")
			_reference_to.disconnect("minimum_size_changed", self, "minimum_size_changed")
		_reference_to = control
		minimum_size_changed()
		if not _reference_to:
			return
		_reference_to.connect("renamed", self, "_on_reference_to_renamed")
		_reference_to.connect("minimum_size_changed", self, "minimum_size_changed")
		_reference_to.visible = visible


func get_reference_to() -> Control:
	return _reference_to


func _reposition_reference() -> void:
	_reference_to.rect_global_position = rect_global_position
	_reference_to.rect_size = rect_size


func _on_reference_to_renamed() -> void:
	name = _reference_to.name
