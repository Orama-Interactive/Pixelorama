extends AcceptDialog

var cel: BaseCel

@onready var opacity_slider := $GridContainer/OpacitySlider as ValueSlider
@onready var z_index_slider := $GridContainer/ZIndexSlider as ValueSlider


func _on_visibility_changed() -> void:
	Global.dialog_open(visible)
	if visible:
		opacity_slider.value = cel.opacity * 100.0
		z_index_slider.value = cel.z_index
	else:
		cel = null


func _on_opacity_slider_value_changed(value: float) -> void:
	if not is_instance_valid(cel):
		return
	cel.opacity = value / 100.0
	Global.canvas.queue_redraw()


func _on_z_index_slider_value_changed(value: float) -> void:
	if not is_instance_valid(cel):
		return
	cel.z_index = value
	Global.current_project.order_layers()
	Global.canvas.update_all_layers = true
	Global.canvas.queue_redraw()
