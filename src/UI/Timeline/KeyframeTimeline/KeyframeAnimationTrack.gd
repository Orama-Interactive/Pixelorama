class_name KeyframeAnimationTrack
extends Control

var timeline: KeyframeTimeline
var effect: LayerEffect
var param_name: String
var is_property := false
var popup_menu := PopupMenu.new()
var keyframe_at := 0
var line_color := Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	popup_menu.add_item("Insert keyframe")
	popup_menu.id_pressed.connect(_on_popup_menu_id_pressed)
	add_child(popup_menu)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		var pressed_cel_button_stylebox := get_theme_stylebox(&"pressed", &"CelButton")
		if pressed_cel_button_stylebox is StyleBoxFlat:
			line_color = pressed_cel_button_stylebox.border_color


func _gui_input(event: InputEvent) -> void:
	if not is_property:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var rect := Rect2()
			keyframe_at = floori(event.position.x / KeyframeTimeline.frame_ui_size)
			rect.position = event.global_position
			rect.size = Vector2(100, 0)
			popup_menu.popup(rect)


func _draw() -> void:
	draw_line(Vector2(0, size.y), Vector2(size.x, size.y), line_color)


func _on_popup_menu_id_pressed(id: int) -> void:
	if id == 0:
		if (
			effect.animated_params.has(param_name)
			and effect.animated_params[param_name].has(keyframe_at)
		):
			return
		timeline.add_effect_keyframe(effect, keyframe_at, param_name)
