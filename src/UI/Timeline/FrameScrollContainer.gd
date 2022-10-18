extends Container

export var h_scroll_bar_node_path: NodePath
onready var h_scroll_bar: HScrollBar = get_node_or_null(h_scroll_bar_node_path)

func _ready():
	rect_clip_content = true
	if is_instance_valid(h_scroll_bar):
		h_scroll_bar.connect("resized", self, "_update_scroll")
		h_scroll_bar.connect("value_changed", self, "_on_scroll_bar_value_changed")


func _clips_input() -> bool:
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		if get_child_count():
			get_child(0).rect_size = get_child(0).get_combined_minimum_size()
			_update_scroll()


func _on_scroll_bar_value_changed(_value: float) -> void:
	print("Value changed!  ", _value)
	_update_scroll()


func _update_scroll() -> void:
	print("update scroll")
	if get_child_count():
		if is_instance_valid(h_scroll_bar):
			h_scroll_bar.max_value = get_child(0).rect_size.x
			h_scroll_bar.page = rect_size.x
#			h_scroll_bar.value = get_child(0).rect_position.x
			h_scroll_bar.visible = h_scroll_bar.page < h_scroll_bar.max_value
			get_child(0).rect_position.x = -h_scroll_bar.value

# TODO: New scroll behavior
# TODO: Nees _clips_input, so will probably need to move FrameScrollArea into a seperate class...
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.shift:
		if is_instance_valid(h_scroll_bar):
			print("Factor = ", event.factor)
			if event.button_index == BUTTON_WHEEL_UP:
				print("UP")
				h_scroll_bar.value -= event.factor * 20
				accept_event()
			elif event.button_index == BUTTON_WHEEL_DOWN:
				print("DOWN")
				h_scroll_bar.value += event.factor * 20
				accept_event()
