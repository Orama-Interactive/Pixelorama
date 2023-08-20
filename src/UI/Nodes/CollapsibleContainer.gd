@tool
class_name CollapsibleContainer
extends VBoxContainer

@export var text := "": set = _set_text
@export var visible_content := false: set = _set_visible_content

var _button := Button.new()
var _texture_rect := TextureRect.new()
var _label := Label.new()


func _init() -> void:
	theme_type_variation = "CollapsibleContainer"


func _ready() -> void:
	_button.toggle_mode = true
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.connect("toggled", Callable(self, "_on_Button_toggled"))
	add_child(_button)
	move_child(_button, 0)
	_texture_rect.anchor_top = 0.5
	_texture_rect.anchor_bottom = 0.5
	_texture_rect.offset_left = 2
	_texture_rect.offset_top = -6
	_texture_rect.offset_right = 14
	_texture_rect.offset_bottom = 6
	_texture_rect.rotation = -90
	_texture_rect.pivot_offset = Vector2(6, 6)
	_texture_rect.add_to_group("UIButtons")
	_button.add_child(_texture_rect)
	_label.valign = Label.VALIGN_CENTER
	_label.position = Vector2(14, 0)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button.add_child(_label)
	_button.button_pressed = visible_content
	for child in get_children():
		if not child is CanvasItem or child == _button:
			continue
		child.connect("visibility_changed", Callable(self, "_child_visibility_changed").bind(child))


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_texture_rect.texture = get_icon("arrow_normal", "CollapsibleContainer")


func _set_text(value: String) -> void:
	text = value
	_label.text = value


func _set_visible_content(value: bool) -> void:
	visible_content = value
	_button.button_pressed = value


func _on_Button_toggled(button_pressed: bool) -> void:
	_set_visible(button_pressed)


func _set_visible(pressed: bool) -> void:
	var angle := 0.0 if pressed else -90.0
	var tween := create_tween()
	tween.tween_property(_texture_rect, "rotation", angle, 0.05)
	for child in get_children():
		if not child is CanvasItem or child == _button:
			continue
		child.visible = pressed


# Checks if a child becomes visible from another sure and ensures
# it remains invisible if the button is not pressed
func _child_visibility_changed(child: CanvasItem) -> void:
	if not _button.pressed:
		child.visible = false
