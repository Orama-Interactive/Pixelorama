extends ImageEffect

enum Animate { OFFSET_X, OFFSET_Y }
var color := Color.BLACK
var shader := preload("res://src/Shaders/Effects/DropShadow.gdshader")

@onready var shadow_color := $VBoxContainer/ShadowOptions/ShadowColor as ColorPickerButton


func _ready() -> void:
	super._ready()
	shadow_color.get_picker().presets_visible = false
	color = shadow_color.color
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)

	# set as in enum
	animate_panel.add_float_property(
		"Offset X", $VBoxContainer/ShadowOptions/OffsetSliders.find_child("X")
	)
	animate_panel.add_float_property(
		"Offset Y", $VBoxContainer/ShadowOptions/OffsetSliders.find_child("Y")
	)


func commit_action(cel: Image, project := Global.current_project) -> void:
	var offset_x := animate_panel.get_animated_value(commit_idx, Animate.OFFSET_X)
	var offset_y := animate_panel.get_animated_value(commit_idx, Animate.OFFSET_Y)
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	var params := {
		"offset": Vector2(offset_x, offset_y), "shadow_color": color, "selection": selection_tex
	}
	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


func _on_OffsetSliders_value_changed(_value: Vector2) -> void:
	update_preview()


func _on_ShadowColor_color_changed(value: Color) -> void:
	color = value
	update_preview()
