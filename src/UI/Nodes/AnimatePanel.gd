class_name AnimatePanel
extends PanelContainer


onready var can_animate_button: CheckBox = $"%CanAnimate"
onready var property_list: ItemList = $"%PropertyList"
onready var initial_value: ValueSlider = $"%Initial"
onready var final_value: ValueSlider = $"%Final"
var image_effect_node :ConfirmationDialog

var frames := []  # Set this value before calling "get_animated_values"
var _current_id: int = 0  # The property currently selected in "property_list"
var properties := []  # Contains dictionary of properties
var zero_properties := []  # Contains the Original properties without any change

func _ready() -> void:
	_populate_ease_type()
	_populate_transition_type()
	$"%Options".visible = false


func add_float_property(name: String, property_node: Range):
	var info = {
		"range_node": property_node,
		"can_animate": false,
		"initial_value": property_node.value,
		"transition_type": Tween.TRANS_LINEAR,
		"ease_type": Tween.EASE_IN,
	}
	var info_2 = {
		properties.size(): property_node.value
	}
	properties.append(info)
	zero_properties.append(info_2)
	property_list.add_item(name)
	property_node.connect("value_changed", self, "_on_range_node_value_changed")


func get_animated_values(frame_idx: int, animation_allowed := true) -> Dictionary:
	var animated = {}
	if frame_idx in frames:
		var tween = SceneTreeTween.new()
		for property_idx in properties.size():
			if properties[property_idx]["can_animate"] and animation_allowed and frames.size() > 1:
				var duration = frames.size() - 1
				var elapsed = frames.find(frame_idx)
				var initial = properties[property_idx]["initial_value"]
				var delta = properties[property_idx]["range_node"].value - initial
				var transition_type = properties[property_idx]["transition_type"]
				var ease_type = properties[property_idx]["ease_type"]
				animated[property_idx] = tween.interpolate_value(initial, delta, elapsed, duration, transition_type, ease_type)
			else:
				animated[property_idx] = properties[property_idx]["range_node"].value
	else:
		# the frame isn't meant for the effect to be apploed to
		for property_idx in zero_properties.size():
			animated[property_idx] = zero_properties[property_idx]
	return animated


func _on_Initial_value_changed(value) -> void:
	properties[_current_id]["initial_value"] = value


func _on_Final_value_changed(value: float) -> void:
	if properties[_current_id]["range_node"].value != value:
		properties[_current_id]["range_node"].value = value


func _on_range_node_value_changed(_value) -> void:
	# Value is changed from outside the Animate Panel
	_refresh_properties(_current_id)


func _on_CanAnimate_toggled(button_pressed: bool) -> void:
	properties[_current_id]["can_animate"] = button_pressed


func _on_PropertyList_item_selected(index: int) -> void:
	_current_id = index
	if not $"%Options".visible:
		$"%Options".visible = true
	$"%Options".visible = true
	_refresh_properties(_current_id)


func _refresh_properties(idx):
	if initial_value.is_connected("value_changed", self, "_on_Initial_value_changed"):
		initial_value.disconnect("value_changed", self, "_on_Initial_value_changed")
	if final_value.is_connected("value_changed", self, "_on_Final_value_changed"):
		final_value.disconnect("value_changed", self, "_on_Final_value_changed")

	# nodes setup
	var property_node = properties[idx]["range_node"]
	if property_node is ValueSlider:
		final_value.snap_step = property_node.snap_step
		initial_value.snap_step = property_node.snap_step
	final_value.max_value = property_node.max_value
	final_value.min_value = property_node.min_value
	final_value.step = property_node.step
	initial_value.max_value = property_node.max_value
	initial_value.min_value = property_node.min_value
	initial_value.step = property_node.step

	# now update values
	can_animate_button.pressed = properties[idx]["can_animate"]
	initial_value.value = properties[idx]["initial_value"]
	if properties[_current_id]["range_node"].value != final_value.value:
		final_value.value = properties[idx]["range_node"].value
	$"%Name".text = property_list.get_item_text(idx)

	initial_value.connect("value_changed", self, "_on_Initial_value_changed")
	final_value.connect("value_changed", self, "_on_Final_value_changed")


func _populate_ease_type():
	$"%EaseType".add_item("Start slowly and speeds up towards the end", Tween.EASE_IN)
	$"%EaseType".add_item("Starts quickly and slows down towards the end.", Tween.EASE_OUT)
	$"%EaseType".add_item("Slowest at both ends fast at middle", Tween.EASE_IN_OUT)
	$"%EaseType".add_item("Fast at both ends slow at middle", Tween.EASE_OUT_IN)


func _populate_transition_type():
	$"%TransitionType".add_item("Linear", Tween.TRANS_LINEAR)
	$"%TransitionType".add_item("Quadratic (to the power of 2)", Tween.TRANS_QUAD)
	$"%TransitionType".add_item("Cubic (to the power of 3)", Tween.TRANS_CUBIC)
	$"%TransitionType".add_item("Quartic (to the power of 4)", Tween.TRANS_QUART)
	$"%TransitionType".add_item("Quintic (to the power of 5)", Tween.TRANS_QUINT)
	$"%TransitionType".add_item("Exponential (to the power of x)", Tween.TRANS_EXPO)
	$"%TransitionType".add_item("Square Root", Tween.TRANS_CIRC)
	$"%TransitionType".add_item("Sine", Tween.TRANS_SINE)
	$"%TransitionType".add_item("Wiggling around the edges", Tween.TRANS_ELASTIC)
	$"%TransitionType".add_item("Bouncing at the end", Tween.TRANS_BOUNCE)
	$"%TransitionType".add_item("Backing out at ends", Tween.TRANS_BACK)


func _on_EaseType_item_selected(index: int) -> void:
	properties[_current_id]["ease_type"] = $"%EaseType".get_item_id(index)


func _on_TransitionType_item_selected(index: int) -> void:
	properties[_current_id]["transition_type"] = $"%TransitionType".get_item_id(index)
