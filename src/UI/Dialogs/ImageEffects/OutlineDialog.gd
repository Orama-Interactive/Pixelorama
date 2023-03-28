extends ImageEffect

enum Animate { THICKNESS }
var color := Color.red
var thickness := 1
var pattern := 0
var inside_image := false
var shader: Shader

onready var outline_color = $VBoxContainer/OptionsContainer/OutlineColor


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


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton
	animate_options_container = $VBoxContainer/AnimationOptions
	animate_menu = $"%AnimateMenu".get_popup()
	initial_button = $"%InitalButton"


func set_animate_menu(_elements) -> void:
	# set as in enum
	animate_menu.add_check_item("Thickness", Animate.THICKNESS)
	.set_animate_menu(Animate.size())


func set_initial_values() -> void:
	initial_values[Animate.THICKNESS] = thickness


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	.commit_action(cel, project)
	var anim_thickness = get_animated_value(project, thickness, Animate.THICKNESS)

	if !shader:  # Web version
		DrawingAlgos.generate_outline(
			cel, selection_checkbox.pressed, project, color, anim_thickness, false, inside_image
		)
		return

	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		selection_tex.create_from_image(project.selection_map, 0)

	var params := {
		"color": color,
		"width": anim_thickness,
		"pattern": pattern,
		"inside": inside_image,
		"selection": selection_tex,
		"affect_selection": selection_checkbox.pressed,
		"has_selection": project.has_selection
	}
	if !confirmed:
		for param in params:
			preview.material.set_shader_param(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		yield(gen, "done")


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
