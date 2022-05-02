extends ImageEffect

enum { LINEAR, RADIAL, LINEAR_STEP, RADIAL_STEP, LINEAR_DITHERING, RADIAL_DITHERING }

var shader_linear: Shader = preload("res://src/Shaders/Gradients/Linear.gdshader")
var shader_radial: Shader = preload("res://src/Shaders/Gradients/Radial.gdshader")
var shader_linear_step: Shader = preload("res://src/Shaders/Gradients/LinearStep.gdshader")
var shader_radial_step: Shader = preload("res://src/Shaders/Gradients/RadialStep.gdshader")
var shader_linear_dither: Shader = preload("res://src/Shaders/Gradients/LinearDithering.gdshader")
var shader_radial_dither: Shader = preload("res://src/Shaders/Gradients/RadialDithering.gdshader")

var confirmed := false
var shader: Shader = shader_linear
var dither_matrices := [
	DitherMatrix.new(preload("res://assets/dither-matrices/bayer2.png"), "Bayer 2x2"),
	DitherMatrix.new(preload("res://assets/dither-matrices/bayer4.png"), "Bayer 4x4", 16),
	DitherMatrix.new(preload("res://assets/dither-matrices/bayer8.png"), "Bayer 8x8", 64),
	DitherMatrix.new(preload("res://assets/dither-matrices/bayer16.png"), "Bayer 16x16", 256),
]
var selected_dither_matrix: DitherMatrix = dither_matrices[0]

onready var options_cont: Container = $VBoxContainer/OptionsContainer
onready var type_option_button: OptionButton = options_cont.get_node("TypeOptionButton")
onready var color1: ColorPickerButton = options_cont.get_node("ColorsContainer/ColorPickerButton")
onready var color2: ColorPickerButton = options_cont.get_node("ColorsContainer/ColorPickerButton2")
onready var position: SpinBox = options_cont.get_node("PositionSpinBox")
onready var angle: SpinBox = options_cont.get_node("AngleSpinBox")
onready var center_x: SpinBox = options_cont.get_node("CenterContainer/CenterXSpinBox")
onready var center_y: SpinBox = options_cont.get_node("CenterContainer/CenterYSpinBox")
onready var radius_x: SpinBox = options_cont.get_node("RadiusContainer/RadiusXSpinBox")
onready var radius_y: SpinBox = options_cont.get_node("RadiusContainer/RadiusYSpinBox")
onready var size: SpinBox = options_cont.get_node("SizeSpinBox")
onready var steps: SpinBox = options_cont.get_node("StepSpinBox")
onready var dithering_option_button: OptionButton = options_cont.get_node("DitheringOptionButton")


class DitherMatrix:
	var texture: Texture
	var name: String
	var n_of_colors: int

	func _init(_texture: Texture, _name: String, _n_of_colors := 4) -> void:
		texture = _texture
		name = _name
		n_of_colors = _n_of_colors


func _ready() -> void:
	color1.get_picker().presets_visible = false
	color2.get_picker().presets_visible = false
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)

	for matrix in dither_matrices:
		dithering_option_button.add_item(matrix.name)


func _about_to_show() -> void:
	confirmed = false
	._about_to_show()


func _confirmed() -> void:
	confirmed = true
	._confirmed()


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var selection: Image
	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		selection = project.bitmap_to_image(project.selection_bitmap)
	else:  # This is needed to prevent a weird bug with the dithering shaders and GLES2
		selection = Image.new()
		selection.create(project.size.x, project.size.y, false, Image.FORMAT_L8)
	selection_tex.create_from_image(selection, 0)

	var dither_texture: Texture = selected_dither_matrix.texture
	var dither_steps: int = selected_dither_matrix.n_of_colors + 1
	var pixel_size: int = dither_texture.get_width()
	var params := {
		"first_color": color1.color,
		"second_color": color2.color,
		"selection": selection_tex,
		"position": (position.value / 100.0) - 0.5,
		"angle": angle.value,
		"center": Vector2(center_x.value / 100.0, center_y.value / 100.0),
		"radius": Vector2(radius_x.value, radius_y.value),
		"size": size.value / 100.0,
		"steps": steps.value,
		"dither_texture": dither_texture,
		"image_size": project.size,
		"dither_steps": dither_steps,
		"pixel_size": pixel_size,
	}

	if !confirmed:
		preview.material.shader = shader
		for param in params:
			preview.material.set_shader_param(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		yield(gen, "done")


func _on_TypeOptionButton_item_selected(index: int) -> void:
	for child in options_cont.get_children():
		if not child.is_in_group("gradient_common"):
			child.visible = false

	match index:
		LINEAR:
			shader = shader_linear
			get_tree().set_group("gradient_linear", "visible", true)
		RADIAL:
			shader = shader_radial
			get_tree().set_group("gradient_radial", "visible", true)
		LINEAR_STEP:
			shader = shader_linear_step
			get_tree().set_group("gradient_step", "visible", true)
		RADIAL_STEP:
			shader = shader_radial_step
			get_tree().set_group("gradient_radial_step", "visible", true)
		LINEAR_DITHERING:
			shader = shader_linear_dither
			get_tree().set_group("gradient_dithering", "visible", true)
		RADIAL_DITHERING:
			shader = shader_radial_dither
			get_tree().set_group("gradient_radial_dithering", "visible", true)
	update_preview()


func _color_changed(_color: Color) -> void:
	update_preview()


func _value_changed(_value: float) -> void:
	update_preview()


func _on_DitheringOptionButton_item_selected(index: int) -> void:
	selected_dither_matrix = dither_matrices[index]
	update_preview()
