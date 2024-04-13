extends ImageEffect

enum Animate { OFFSET_X, OFFSET_Y }

var shader := preload("res://src/Shaders/Effects/OffsetPixels.gdshader")
var wrap_around := false

@onready var offset_sliders := $VBoxContainer/OffsetOptions/OffsetSliders as ValueSliderV2


func _ready() -> void:
	super._ready()
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)
	# Set in the order of the Animate enum
	animate_panel.add_float_property(
		"Offset X", $VBoxContainer/OffsetOptions/OffsetSliders.get_sliders()[0]
	)
	animate_panel.add_float_property(
		"Offset Y", $VBoxContainer/OffsetOptions/OffsetSliders.get_sliders()[1]
	)


func _about_to_popup() -> void:
	offset_sliders.min_value = -Global.current_project.size
	offset_sliders.max_value = Global.current_project.size
	super._about_to_popup()


func commit_action(cel: Image, project := Global.current_project) -> void:
	var offset_x := animate_panel.get_animated_value(commit_idx, Animate.OFFSET_X)
	var offset_y := animate_panel.get_animated_value(commit_idx, Animate.OFFSET_Y)
	var offset := Vector2(offset_x, offset_y)
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	var params := {"offset": offset, "wrap_around": wrap_around, "selection": selection_tex}
	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


func _on_OffsetSliders_value_changed(_value: Vector2) -> void:
	update_preview()


func _on_WrapCheckBox_toggled(button_pressed: bool) -> void:
	wrap_around = button_pressed
	update_preview()
