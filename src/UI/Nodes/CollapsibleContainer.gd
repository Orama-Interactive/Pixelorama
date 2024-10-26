@tool
class_name CollapsibleContainer
extends VBoxContainer
## A button that, when clicked, expands into a VBoxContainer.

@export var text := "":
	set(value):
		text = value
		_label.text = value
@export var visible_content := false:
	set(value):
		visible_content = value
		_button.button_pressed = value
@export var flat := false:
	set(value):
		flat = value
		_button.flat = value

var _button := Button.new()
var _texture_rect := TextureRect.new()
var _label := Label.new()


func _init() -> void:
	theme_type_variation = "CollapsibleContainer"


func _ready() -> void:
	if name.is_empty():
		name = "CollapsibleContainer"
	_button.flat = flat
	_button.toggle_mode = true
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.toggled.connect(set_visible_children)
	add_child(_button, false, Node.INTERNAL_MODE_FRONT)
	_texture_rect.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE
	)
	_texture_rect.rotation_degrees = -90
	_texture_rect.pivot_offset = Vector2(6, 6)
	_texture_rect.add_to_group("UIButtons")
	_button.add_child(_texture_rect)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(14, 0)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button.add_child(_label)
	_button.custom_minimum_size = _label.size
	_button.button_pressed = visible_content
	for child in get_children():
		if not child is CanvasItem or child == _button:
			continue
		child.visibility_changed.connect(_child_visibility_changed.bind(child))


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_texture_rect.texture = get_theme_icon("arrow_normal", "CollapsibleContainer")


## Toggles whether the children of the container are visible or not
func set_visible_children(pressed: bool) -> void:
	var angle := 0.0 if pressed else -90.0
	create_tween().tween_property(_texture_rect, "rotation_degrees", angle, 0.05)
	for child in get_children():
		if not child is CanvasItem or child == _button:
			continue
		child.visible = pressed


## Returns [member _button].
func get_button() -> Button:
	return _button


## Checks if a child becomes visible from another sure and ensures
## it remains invisible if the button is not pressed
func _child_visibility_changed(child: CanvasItem) -> void:
	if not _button.pressed:
		child.visible = false
