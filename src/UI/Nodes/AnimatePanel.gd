class_name AnimatePanel
extends PanelContainer

var image_effect_node: ConfirmationDialog
var frames := []  ## Set this value before calling "get_animated_value"
var properties := []  ## Contains dictionary of properties
var resetter_values := []  ## Contains the Original properties without any change
var _current_id := 0  ## The property currently selected in "property_list"

@onready var can_animate_button: CheckBox = $"%CanAnimate"
@onready var property_list: ItemList = $"%PropertyList"
@onready var initial_value: ValueSlider = $"%Initial"
@onready var final_value: ValueSlider = $"%Final"
@onready var preview_slider: TextureProgressBar = $"%PreviewSlider"


func _ready() -> void:
	_populate_ease_type()
	_populate_transition_type()
	$"%Options".visible = false


func re_calibrate_preview_slider():
	preview_slider.visible = false
	preview_slider.max_value = frames[-1] + 1
	preview_slider.min_value = frames[0] + 1
	preview_slider.value = image_effect_node.commit_idx + 1
	preview_slider.visible = true


func add_float_property(prop_name: String, property_node: Range):
	var info := {
		"range_node": property_node,
		"can_animate": false,
		"initial_value": property_node.value,
		"transition_type": Tween.TRANS_LINEAR,
		"ease_type": Tween.EASE_IN,
	}
	properties.append(info)
	resetter_values.append(property_node.value)
	property_list.add_item(prop_name)
	property_node.value_changed.connect(_on_range_node_value_changed)


func get_animated_value(frame_idx: int, property_idx := 0) -> float:
	if property_idx <= 0 or property_idx < properties.size():
		if frame_idx in frames:
			if properties[property_idx]["can_animate"] and frames.size() > 1:
				var duration := frames.size() - 1
				var elapsed := frames.find(frame_idx)
				var initial = properties[property_idx]["initial_value"]
				var delta = properties[property_idx]["range_node"].value - initial
				var transition_type = properties[property_idx]["transition_type"]
				var ease_type = properties[property_idx]["ease_type"]
				var value = Tween.interpolate_value(
					initial, delta, elapsed, duration, transition_type, ease_type
				)
				return value
			else:
				return properties[property_idx]["range_node"].value
		else:
			return resetter_values[property_idx]
	else:
		printerr("Property index is exceeding the bounds of the number of properties")
		return 0.0


func _on_Initial_value_changed(value) -> void:
	properties[_current_id]["initial_value"] = value
	image_effect_node.update_preview()


func _on_Final_value_changed(value: float) -> void:
	if properties[_current_id]["range_node"].value != value:
		properties[_current_id]["range_node"].value = value


func _on_range_node_value_changed(_value) -> void:
	# Value is changed from outside the Animate Panel
	if properties[_current_id]["range_node"].value != final_value.value:
		if final_value.value_changed.is_connected(_on_Final_value_changed):
			final_value.value_changed.disconnect(_on_Final_value_changed)
		final_value.value = properties[_current_id]["range_node"].value
		final_value.value_changed.connect(_on_Final_value_changed)


func _on_CanAnimate_toggled(button_pressed: bool) -> void:
	properties[_current_id]["can_animate"] = button_pressed
	$"%Initial".editable = button_pressed
	$"%Final".editable = button_pressed
	$"%EaseType".disabled = !button_pressed
	$"%TransitionType".disabled = !button_pressed
	image_effect_node.update_preview()


func _on_PropertyList_item_selected(index: int) -> void:
	_current_id = index
	if not $"%Options".visible:
		$"%Options".visible = true
	$"%Options".visible = true
	_refresh_properties(_current_id)


func _refresh_properties(idx: int):
	if initial_value.value_changed.is_connected(_on_Initial_value_changed):
		initial_value.value_changed.disconnect(_on_Initial_value_changed)
	if final_value.value_changed.is_connected(_on_Final_value_changed):
		final_value.value_changed.disconnect(_on_Final_value_changed)

	# Nodes setup
	var property_node: Range = properties[idx]["range_node"]
	if property_node is ValueSlider:
		final_value.snap_step = property_node.snap_step
		initial_value.snap_step = property_node.snap_step
	final_value.allow_greater = property_node.allow_greater
	final_value.allow_lesser = property_node.allow_lesser
	final_value.max_value = property_node.max_value
	final_value.min_value = property_node.min_value
	final_value.step = property_node.step
	initial_value.allow_greater = property_node.allow_greater
	initial_value.allow_lesser = property_node.allow_lesser
	initial_value.max_value = property_node.max_value
	initial_value.min_value = property_node.min_value
	initial_value.step = property_node.step

	# Update values
	can_animate_button.button_pressed = properties[idx]["can_animate"]
	initial_value.value = properties[idx]["initial_value"]
	if properties[idx]["range_node"].value != final_value.value:
		final_value.value = properties[idx]["range_node"].value
	$"%Name".text = property_list.get_item_text(idx)
	$"%EaseType".select($"%EaseType".get_item_index(properties[idx]["ease_type"]))
	$"%TransitionType".select($"%TransitionType".get_item_index(properties[idx]["transition_type"]))

	initial_value.value_changed.connect(_on_Initial_value_changed)
	final_value.value_changed.connect(_on_Final_value_changed)


func _populate_ease_type():
	$"%EaseType".add_item("Starts slowly and speeds up towards the end", Tween.EASE_IN)
	$"%EaseType".add_item("Starts quickly and slows down towards the end", Tween.EASE_OUT)
	$"%EaseType".add_item("Slowest at both ends, fast at middle", Tween.EASE_IN_OUT)
	$"%EaseType".add_item("Fast at both ends, slow at middle", Tween.EASE_OUT_IN)


func _populate_transition_type():
	$"%TransitionType".add_item("Linear", Tween.TRANS_LINEAR)
	$"%TransitionType".add_item("Quadratic (power of 2)", Tween.TRANS_QUAD)
	$"%TransitionType".add_item("Cubic (power of 3)", Tween.TRANS_CUBIC)
	$"%TransitionType".add_item("Quartic (power of 4)", Tween.TRANS_QUART)
	$"%TransitionType".add_item("Quintic (power of 5)", Tween.TRANS_QUINT)
	$"%TransitionType".add_item("Exponential (power of x)", Tween.TRANS_EXPO)
	$"%TransitionType".add_item("Square root", Tween.TRANS_CIRC)
	$"%TransitionType".add_item("Sine", Tween.TRANS_SINE)
	$"%TransitionType".add_item("Wiggling around the edges", Tween.TRANS_ELASTIC)
	$"%TransitionType".add_item("Bouncing at the end", Tween.TRANS_BOUNCE)
	$"%TransitionType".add_item("Backing out at ends", Tween.TRANS_BACK)
	$"%TransitionType".add_item("Spring towards the end", Tween.TRANS_SPRING)


func _on_EaseType_item_selected(index: int) -> void:
	properties[_current_id]["ease_type"] = $"%EaseType".get_item_id(index)
	image_effect_node.update_preview()


func _on_TransitionType_item_selected(index: int) -> void:
	properties[_current_id]["transition_type"] = $"%TransitionType".get_item_id(index)
	image_effect_node.update_preview()


func _on_PreviewSlider_value_changed(value: float) -> void:
	image_effect_node.set_and_update_preview_image(value - 1)
