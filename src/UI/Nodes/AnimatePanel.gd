class_name AnimatePanel
extends PanelContainer


onready var can_animate_button: CheckButton = $"%CanAnimate"
onready var property_list: ItemList = $"%PropertyList"
onready var initial_value: ValueSlider = $"%Initial"
onready var final_value: ValueSlider = $"%Final"

var _current_id: int = 0
var properties := [] # contains dictionary of properties


func _ready() -> void:
	_populate_ease_type()
	_populate_transition_type()
	$"%Options".visible = false


func add_float_property(name: String, property_node: Range):
	var id = properties.size()
	property_node.connect("value_changed", self, "_update_final", [id])

	var info = {
		"range_node": property_node,
		"can_animate": false,
		"initial_value": property_node.value,
		"transition_type": Tween.TRANS_LINEAR,
		"ease_type": Tween.EASE_IN,
	}
	properties.append(info)
	property_list.add_item(name)


func get_animated_values(selected_idx: int, animation_allowed := true) -> Dictionary:
	var selected_cels = Global.current_project.selected_cels
	var frames = []
	for x_y in selected_cels:
		if not x_y[0] in frames:
			frames.append(x_y[0])
	frames.sort()  # To always start animating from left side of the timeline

	var animated = {}
	var tween = SceneTreeTween.new()
	for property_idx in properties.size():
		if properties[property_idx]["can_animate"] and animation_allowed and frames.size() > 1:
			var duration = frames.size() - 1
			var elapsed = frames.find(selected_cels[selected_idx][0])
			var initial = properties[property_idx]["initial_value"]
			var delta = properties[property_idx]["range_node"].value - initial
			var transition_type = properties[property_idx]["transition_type"]
			var ease_type = properties[property_idx]["ease_type"]
			animated[property_idx] = tween.interpolate_value(initial, delta, elapsed, duration, transition_type, ease_type)
		else:
			animated[property_idx] = properties[property_idx]["range_node"].value
	return animated


func _set_initial_float_value(_value, id: int):
	if id < properties.size():  # will always be true
		if id == _current_id:
			properties[id]["initial_value"] = initial_value.value


func _update_final(_value, id: int) -> void:
	if id == _current_id:
		_display_properties(_current_id)


func _on_CanAnimate_toggled(button_pressed: bool) -> void:
	properties[_current_id]["can_animate"] = button_pressed


func _on_PropertyList_item_selected(index: int) -> void:
	_current_id = index
	if not $"%Options".visible:
		$"%Options".visible = true
	$"%Options".visible = true
	_display_properties(_current_id)


func _display_properties(idx):
	can_animate_button.pressed = properties[idx]["can_animate"]
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

	if initial_value.is_connected("value_changed", self, "_set_initial_float_value"):
		initial_value.disconnect("value_changed", self, "_set_initial_float_value")
	initial_value.value = properties[idx]["initial_value"]
	initial_value.connect("value_changed", self, "_set_initial_float_value", [idx])
	final_value.value = properties[idx]["range_node"].value
	$"%Name".text = property_list.get_item_text(idx)


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
