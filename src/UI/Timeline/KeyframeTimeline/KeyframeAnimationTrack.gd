class_name KeyframeAnimationTrack
extends Control

## An enum that contains the possible types of the track.
## Such as layer effect, and in the future, 3D and bones.
enum TrackTypes { LAYER_EFFECT }

var timeline: KeyframeTimeline
var type := TrackTypes.LAYER_EFFECT
var animatable_object: AnimatableObject
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
			# Snap event.position to the nearest frame marking. This solves the issue of keyframe
			# getting created at the wrong frame even if the user right clicks at a frame marking.
			var track_offset := KeyframeTimeline.TRACK_X_MARGIN * KeyframeTimeline.frame_ui_size
			keyframe_at = roundi((event.position.x - track_offset) / KeyframeTimeline.frame_ui_size)
			if keyframe_at < 0:  # We currently do not allow keyframes at negative frames.
				keyframe_at = 0
			var rect := Rect2()
			rect.position = event.global_position
			rect.size = Vector2(100, 0)
			popup_menu.popup_on_parent(rect)


func _draw() -> void:
	if animatable_object != null:
		var dash_color := Color(line_color.r, line_color.g, line_color.b, line_color.a * 0.5)
		draw_dashed_line(Vector2(0, size.y / 2.0), Vector2(size.x, size.y / 2.0), dash_color)
	draw_line(Vector2(0, size.y), Vector2(size.x, size.y), line_color)


func _on_popup_menu_id_pressed(id: int) -> void:
	if id == 0:
		if (
			animatable_object.animated_params.has(param_name)
			and animatable_object.animated_params[param_name].has(keyframe_at)
		):
			return
		if type == TrackTypes.LAYER_EFFECT:
			timeline.add_effect_keyframe(animatable_object, keyframe_at, param_name)
