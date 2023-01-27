extends ImageEffect

enum { LINEAR, RADIAL, LINEAR_DITHERING, RADIAL_DITHERING }

var shader_linear: Shader = preload("res://src/Shaders/Gradients/Linear.gdshader")
var shader_radial: Shader = preload("res://src/Shaders/Gradients/Radial.gdshader")
var shader_linear_dither: Shader
var shader_radial_dither: Shader

var shader: Shader = shader_linear
var dither_matrices := [
	DitherMatrix.new(preload("res://assets/dither-matrices/bayer2.png"), "Bayer 2x2"),
	DitherMatrix.new(preload("res://assets/dither-matrices/bayer4.png"), "Bayer 4x4"),
	DitherMatrix.new(preload("res://assets/dither-matrices/bayer8.png"), "Bayer 8x8"),
	DitherMatrix.new(preload("res://assets/dither-matrices/bayer16.png"), "Bayer 16x16"),
]
var selected_dither_matrix: DitherMatrix = dither_matrices[0]

onready var options_cont: Container = $VBoxContainer/OptionsContainer
onready var gradient_edit: GradientEditNode = $VBoxContainer/GradientEdit
onready var type_option_button: OptionButton = options_cont.get_node("TypeOptionButton")
onready var position: ValueSlider = $"%PositionSlider"
onready var angle: ValueSlider = $"%AngleSlider"
onready var center_x: ValueSlider = $"%XCenterSlider"
onready var center_y: ValueSlider = $"%YCenterSlider"
onready var radius_x: ValueSlider = $"%XRadiusSlider"
onready var radius_y: ValueSlider = $"%YRadiusSlider"
onready var dithering_option_button: OptionButton = options_cont.get_node("DitheringOptionButton")


class DitherMatrix:
	var texture: Texture
	var name: String

	func _init(_texture: Texture, _name: String) -> void:
		texture = _texture
		name = _name


func _ready() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)
	if _is_webgl1():
		type_option_button.set_item_disabled(LINEAR_DITHERING, true)
		type_option_button.set_item_disabled(RADIAL_DITHERING, true)
	else:
		shader_linear_dither = load("res://src/Shaders/Gradients/LinearDithering.gdshader")
		shader_radial_dither = load("res://src/Shaders/Gradients/RadialDithering.gdshader")

	for matrix in dither_matrices:
		dithering_option_button.add_item(matrix.name)


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var selection: Image
	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		selection = project.selection_map
	else:  # This is needed to prevent a weird bug with the dithering shaders and GLES2
		selection = Image.new()
		selection.create(project.size.x, project.size.y, false, Image.FORMAT_L8)
	selection_tex.create_from_image(selection, 0)

	var dither_texture: Texture = selected_dither_matrix.texture
	var pixel_size := dither_texture.get_width()
	var gradient: Gradient = gradient_edit.texture.gradient
	var n_of_colors := gradient.offsets.size()
	# Pass the gradient offsets as an array to the shader
	# ...but since Godot 3.x doesn't support uniform arrays, instead we construct
	# a nx1 grayscale texture with each offset stored in each pixel, and pass it to the shader
	var offsets_image := Image.new()
	offsets_image.create(n_of_colors, 1, false, Image.FORMAT_L8)
	offsets_image.lock()
	for i in n_of_colors:
		var c := gradient.offsets[i]
		offsets_image.set_pixel(i, 0, Color(c, c, c, c))
	offsets_image.unlock()
	var offsets_tex := ImageTexture.new()
	offsets_tex.create_from_image(offsets_image, 0)
	var params := {
		"gradient_texture": gradient_edit.texture,
		"offset_texture": offsets_tex,
		"selection": selection_tex,
		"position": (position.value / 100.0) - 0.5,
		"angle": angle.value,
		"center": Vector2(center_x.value / 100.0, center_y.value / 100.0),
		"radius": Vector2(radius_x.value, radius_y.value),
		"dither_texture": dither_texture,
		"image_size": project.size,
		"pixel_size": pixel_size,
		"n_of_colors": n_of_colors
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
		LINEAR_DITHERING:
			shader = shader_linear_dither
			get_tree().set_group("gradient_dithering", "visible", true)
		RADIAL_DITHERING:
			shader = shader_radial_dither
			get_tree().set_group("gradient_radial_dithering", "visible", true)
	update_preview()


func _value_changed(_value: float) -> void:
	update_preview()


func _on_DitheringOptionButton_item_selected(index: int) -> void:
	selected_dither_matrix = dither_matrices[index]
	update_preview()


func _on_GradientEdit_updated(_gradient, _cc) -> void:
	update_preview()
