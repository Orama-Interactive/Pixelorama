extends ImageEffect

enum Animate { OFFSET_X, OFFSET_Y }
var offset := Vector2(5, 5)
var color := Color.black
var shader: Shader = load("res://src/Shaders/DropShadow.tres")

onready var shadow_color := $VBoxContainer/OptionsContainer/ShadowColor as ColorPickerButton


func _ready() -> void:
	shadow_color.get_picker().presets_visible = false
	color = shadow_color.color
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton
	animate_options_container = $VBoxContainer/AnimationOptions
	animate_menu = $"%AnimateMenu".get_popup()
	initial_button = $"%InitalButton"


func set_animate_menu(_elements) -> void:
	# set as in enum
	animate_menu.add_check_item("Offset X", Animate.OFFSET_X)
	animate_menu.add_check_item("Offset Y", Animate.OFFSET_Y)
	.set_animate_menu(Animate.size())


func set_initial_values() -> void:
	initial_values[Animate.OFFSET_X] = offset.x
	initial_values[Animate.OFFSET_Y] = offset.y


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	.commit_action(cel, project)
	var offset_x = get_animated_value(project, offset.x, Animate.OFFSET_X)
	var offset_y = get_animated_value(project, offset.y, Animate.OFFSET_Y)
	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		selection_tex.create_from_image(project.selection_map, 0)

	var params := {
		"shadow_offset": Vector2(offset_x, offset_y),
		"shadow_color": color,
		"selection": selection_tex,
	}
	if !confirmed:
		for param in params:
			preview.material.set_shader_param(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		yield(gen, "done")


func _on_OffsetSliders_value_changed(value: Vector2) -> void:
	offset = value
	update_preview()


func _on_OutlineColor_color_changed(value: Color) -> void:
	color = value
	update_preview()
