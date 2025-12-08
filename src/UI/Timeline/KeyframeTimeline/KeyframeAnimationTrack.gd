class_name KeyframeAnimationTrack
extends Control

var effect: LayerEffect
var param_name: String
var is_property := false
var popup_menu := PopupMenu.new()
var keyframe_at := 0


func _ready() -> void:
	#size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_menu.add_item("Insert keyframe")
	popup_menu.id_pressed.connect(_on_popup_menu_id_pressed)
	add_child(popup_menu)


func _gui_input(event: InputEvent) -> void:
	if not is_property:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var rect := Rect2()
			keyframe_at = roundi(event.position.x / KeyframeTimeline.frame_ui_size)
			rect.position = event.global_position
			rect.size = Vector2(100, 0)
			popup_menu.popup(rect)


func _on_popup_menu_id_pressed(id: int) -> void:
	if id == 0:
		if not effect.animated_params.has(keyframe_at):
			effect.animated_params[keyframe_at] = {}
		effect.animated_params[keyframe_at][param_name] = effect.animated_params[0][param_name]
