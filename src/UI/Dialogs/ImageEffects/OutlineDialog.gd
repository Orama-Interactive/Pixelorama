extends ImageEffect

enum Animate { THICKNESS }
var color := Color.black
var thickness := 1
var pattern := 0
var inside_image := false
var shader: Shader

onready var outline_color := $VBoxContainer/OutlineOptions/OutlineColor as ColorPickerButton


func _ready() -> void:
	if _is_webgl1():
		$VBoxContainer/OptionsContainer/PatternOptionButton.disabled = true
	else:
		shader = load("res://src/Shaders/OutlineInline.gdshader")
		var sm := ShaderMaterial.new()
		sm.shader = shader
		preview.set_material(sm)
	outline_color.get_picker().presets_visible = false
	color = outline_color.color
	# set as in enum
	animate_panel.add_float_property("Thickness", $VBoxContainer/OutlineOptions/ThickValue)


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var anim_thickness = animate_panel.get_animated_value(commit_idx, Animate.THICKNESS)

	if !shader:  # Web version
		DrawingAlgos.generate_outline(
			cel, selection_checkbox.pressed, project, color, anim_thickness, false, inside_image
		)
		return

	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		selection_tex.create_from_image(project.selection_map.return_cropped_copy(project.size), 0)

	var params := {
		"color": color,
		"width": anim_thickness,
		"pattern": pattern,
		"inside": inside_image,
		"selection": selection_tex
	}
	if !confirmed:
		for param in params:
			preview.material.set_shader_param(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


func _on_ThickValue_value_changed(value: int) -> void:
	thickness = value
	update_preview()


func _on_OutlineColor_color_changed(_color: Color) -> void:
	color = _color
	update_preview()


func _on_InsideImageCheckBox_toggled(button_pressed: bool) -> void:
	inside_image = button_pressed
	update_preview()


func _on_PatternOptionButton_item_selected(index: int) -> void:
	pattern = index
	update_preview()
