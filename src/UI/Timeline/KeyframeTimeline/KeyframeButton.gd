class_name KeyframeButton
extends TextureButton

signal updated_position
signal deleted(id: int)

const KEYFRAME_ICON := preload("uid://yhha3l44svgs")
const KEYFRAME_SELECTED_ICON := preload("uid://dtx6hygsgoifb")

var keyframe_timeline: KeyframeTimeline
var keyframe_id := 0
var dict: Dictionary
var param_name: String
var frame_index: int
var is_dragged := false
var drag_mouse_start_pos := 0.0
var drag_pos := 0.0


func _init() -> void:
	add_to_group(&"KeyframeButtons")
	toggle_mode = true
	texture_normal = KEYFRAME_ICON
	texture_pressed = KEYFRAME_SELECTED_ICON
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	var selected_keyframe_buttons := KeyframeTimeline.get_selected_keyframe_buttons()
	var parent := get_parent() as Control
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			create_popup_menu(event.global_position)

	if not self in selected_keyframe_buttons:
		# Check if it was pressed just recently, if it is then we have to reset
		# selected_keyframe_buttons
		if (
			(
				event is InputEventMouseButton
				and event.button_index == MOUSE_BUTTON_LEFT
				and event.pressed
				and get_rect().has_point(parent.get_local_mouse_position())
			)
			or is_dragged
		):
			selected_keyframe_buttons = [self]
		else:
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:  # Start dragging.
			is_dragged = true
			drag_mouse_start_pos = parent.get_local_mouse_position().x
			for keyframe_button in selected_keyframe_buttons:
				keyframe_button.drag_pos = keyframe_button.position.x
		else:
			if is_dragged:  # Release.
				is_dragged = false
				# If the button was clicked to drag, while it wasn't selected,
				# then the pressed signal isn't emitted yet (it emits on release),
				# so we have to manually emit it first.
				if not button_pressed and self in selected_keyframe_buttons:
					button_pressed = true
					pressed.emit()
				if drag_pos != position.x:
					updated_position.emit()

	if event is InputEventMouseMotion and is_dragged:
		var track_offset := KeyframeTimeline.TRACK_X_MARGIN
		var mouse_pos: float = parent.get_local_mouse_position().x
		var delta := mouse_pos - drag_mouse_start_pos
		for keyframe_button in selected_keyframe_buttons:
			var new_pos := keyframe_button.drag_pos + delta
			var frame := floori((new_pos + track_offset) / KeyframeTimeline.frame_ui_size)
			keyframe_button.position.x = (frame + track_offset) * KeyframeTimeline.frame_ui_size
			keyframe_button.position.x -= keyframe_button.size.x / 2
			if keyframe_button.position.x < 0:
				keyframe_button.position.x = 0
		(get_parent() as KeyframeAnimationTrack).queue_redraw()


func create_popup_menu(pos: Vector2) -> void:
	var popup_menu := PopupMenu.new()
	popup_menu.add_item("Delete keyframe")

	var value = dict[param_name][frame_index]["value"]
	if AnimatableObject.is_interpolatable_type(value):
		var trans_type = dict[param_name][frame_index]["trans"]
		var ease_type = dict[param_name][frame_index]["ease"]
		var trans_type_options := PopupMenu.new()
		trans_type_options.add_radio_check_item("Linear", Tween.TRANS_LINEAR)
		trans_type_options.add_radio_check_item("Quadratic (power of 2)", Tween.TRANS_QUAD)
		trans_type_options.add_radio_check_item("Cubic (power of 3)", Tween.TRANS_CUBIC)
		trans_type_options.add_radio_check_item("Quartic (power of 4)", Tween.TRANS_QUART)
		trans_type_options.add_radio_check_item("Quintic (power of 5)", Tween.TRANS_QUINT)
		trans_type_options.add_radio_check_item("Exponential (power of x)", Tween.TRANS_EXPO)
		trans_type_options.add_radio_check_item("Square root", Tween.TRANS_CIRC)
		trans_type_options.add_radio_check_item("Sine", Tween.TRANS_SINE)
		trans_type_options.add_radio_check_item("Wiggling around the edges", Tween.TRANS_ELASTIC)
		trans_type_options.add_radio_check_item("Bouncing at the end", Tween.TRANS_BOUNCE)
		trans_type_options.add_radio_check_item("Backing out at ends", Tween.TRANS_BACK)
		trans_type_options.add_radio_check_item("Spring towards the end", Tween.TRANS_SPRING)
		trans_type_options.add_radio_check_item("Constant", AnimatableObject.TRANS_CONSTANT)
		trans_type_options.set_item_checked(trans_type_options.get_item_index(trans_type), true)
		trans_type_options.id_pressed.connect(
			keyframe_timeline.on_keyframe_property_changed.bind("trans")
		)
		popup_menu.add_submenu_node_item("Interpolation", trans_type_options)

		var ease_type_options := PopupMenu.new()
		ease_type_options.add_radio_check_item("Ease in", Tween.EASE_IN)
		ease_type_options.add_radio_check_item("Ease out", Tween.EASE_OUT)
		ease_type_options.add_radio_check_item("Ease in out", Tween.EASE_IN_OUT)
		ease_type_options.add_radio_check_item("Ease out in", Tween.EASE_OUT_IN)
		ease_type_options.set_item_checked(ease_type_options.get_item_index(ease_type), true)
		ease_type_options.id_pressed.connect(
			keyframe_timeline.on_keyframe_property_changed.bind("ease")
		)
		popup_menu.add_submenu_node_item("Ease type", ease_type_options)

	popup_menu.id_pressed.connect(_on_popup_menu_id_pressed)
	add_child(popup_menu)
	var rect := Rect2()
	rect.position = pos
	rect.size = Vector2.ZERO
	popup_menu.popup_on_parent(rect)
	popup_menu.visibility_changed.connect(popup_menu.queue_free)


func _on_popup_menu_id_pressed(id: int) -> void:
	if id == 0:
		deleted.emit(keyframe_id)
