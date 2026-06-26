extends Control

const LINE_WIDTH := -1
const X_OFFSET := 8

var layer_index := 0:
	set(value):
		layer_index = value
		var hierarchy_depth := Global.current_project.layers[layer_index].get_hierarchy_depth()
		custom_minimum_size.x = hierarchy_depth * hierarchy_depth_pixel_shift
var hierarchy_depth_pixel_shift := 16
var is_line_reaching_bottom := false
var link_to_child := false


func _ready() -> void:
	Themes.theme_switched.connect(queue_redraw)
	Global.project_about_to_switch.connect(_on_project_about_to_switch)
	Global.project_switched.connect(_on_project_switched)
	_on_project_switched()


func _draw() -> void:
	var current_layer := Global.current_project.layers[layer_index]
	var self_and_ancestors := current_layer.get_ancestors()
	if self_and_ancestors.is_empty():  # Layer has no parents.
		return
	var color := Global.control.theme.get_color(&"font_color", &"Label")
	var half_size := size / 2
	var xx: int
	var center: Vector2
	self_and_ancestors.pop_back()
	self_and_ancestors.reverse()
	self_and_ancestors.append(current_layer)
	for i in self_and_ancestors.size():
		var layer := self_and_ancestors[i]
		xx = i * hierarchy_depth_pixel_shift + X_OFFSET
		var center_top := Vector2(xx, 0)
		var center_bottom := Vector2(xx, size.y)
		center = Vector2(xx, half_size.y)
		var line_reaching_bottom := false
		if is_instance_valid(layer.parent) and layer.parent.get_child_count(false) > 0:
			var first_child := layer.parent.get_children(false)[0]
			line_reaching_bottom = layer != first_child
		var horizontal_line_end := center_bottom if line_reaching_bottom else center
		draw_line(center_top, horizontal_line_end, color, LINE_WIDTH)

	var center_right := Vector2(size.x, half_size.y)
	draw_line(center, center_right, color, LINE_WIDTH)


func _on_project_about_to_switch() -> void:
	var project := Global.current_project
	project.layers_updated.disconnect(queue_redraw)


func _on_project_switched() -> void:
	var project := Global.current_project
	if not project.layers_updated.is_connected(queue_redraw):
		project.layers_updated.connect(queue_redraw)
