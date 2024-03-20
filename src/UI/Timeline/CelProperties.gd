extends AcceptDialog

var cel_indices: Array

@onready var frame_num := $GridContainer/FrameNum as Label
@onready var layer_num := $GridContainer/LayerNum as Label
@onready var opacity_slider := $GridContainer/OpacitySlider as ValueSlider
@onready var z_index_slider := $GridContainer/ZIndexSlider as ValueSlider


func _on_visibility_changed() -> void:
	if cel_indices.size() == 0:
		return
	Global.dialog_open(visible)
	var first_cel := Global.current_project.frames[cel_indices[0][0]].cels[cel_indices[0][1]]
	if visible:
		if cel_indices.size() == 1:
			var layer := Global.current_project.layers[cel_indices[0][1]]
			frame_num.text = str(cel_indices[0][0] + 1)
			layer_num.text = layer.name
		else:
			var first_layer := Global.current_project.layers[cel_indices[0][1]]
			var last_layer := Global.current_project.layers[cel_indices[-1][1]]
			frame_num.text = "[%s...%s]" % [cel_indices[0][0] + 1, cel_indices[-1][0] + 1]
			layer_num.text = "[%s...%s]" % [first_layer.name, last_layer.name]
		opacity_slider.value = first_cel.opacity * 100.0
		z_index_slider.value = first_cel.z_index
	else:
		cel_indices = []


func _on_opacity_slider_value_changed(value: float) -> void:
	if cel_indices.size() == 0:
		return
	for cel_index in cel_indices:
		var cel := Global.current_project.frames[cel_index[0]].cels[cel_index[1]]
		cel.opacity = value / 100.0
	Global.canvas.queue_redraw()


func _on_z_index_slider_value_changed(value: float) -> void:
	if cel_indices.size() == 0:
		return
	for cel_index in cel_indices:
		var cel := Global.current_project.frames[cel_index[0]].cels[cel_index[1]]
		cel.z_index = value
	Global.current_project.order_layers()
	Global.canvas.update_all_layers = true
	Global.canvas.queue_redraw()
