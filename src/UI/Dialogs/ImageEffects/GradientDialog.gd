extends ImageEffect

enum { LINEAR, RADIAL, LINEAR_DITHERING, RADIAL_DITHERING }

var shader_linear: Shader = preload("res://src/Shaders/Gradients/Linear.gdshader")
var shader_linear_dither: Shader = preload("res://src/Shaders/Gradients/LinearDithering.gdshader")

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
onready var shape_option_button: OptionButton = $"%ShapeOptionButton"
onready var dithering_label: Label = $"%DitheringLabel"
onready var dithering_option_button: OptionButton = $"%DitheringOptionButton"
onready var repeat_option_button: OptionButton = $"%RepeatOptionButton"
onready var position: ValueSlider = $"%PositionSlider"
onready var size_slider: ValueSlider = $"%SizeSlider"
onready var angle: ValueSlider = $"%AngleSlider"
onready var center_x: ValueSlider = $"%XCenterSlider"
onready var center_y: ValueSlider = $"%YCenterSlider"
onready var radius_x: ValueSlider = $"%XRadiusSlider"
onready var radius_y: ValueSlider = $"%YRadiusSlider"


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
	var gradient: Gradient = gradient_edit.gradient
	var n_of_colors := gradient.offsets.size()
	# Pass the gradient offsets as an array to the shader
	# ...but since Godot 3.x doesn't support uniform arrays, instead we construct
	# a nx1 grayscale texture with each offset stored in each pixel, and pass it to the shader
	var offsets_image := Image.new()
	offsets_image.create(n_of_colors, 1, false, Image.FORMAT_L8)
	# Construct an image that contains the selected colors of the gradient without interpolation
	var gradient_image := Image.new()
	gradient_image.create(n_of_colors, 1, false, Image.FORMAT_RGBA8)
	offsets_image.lock()
	gradient_image.lock()
	for i in n_of_colors:
		var c := gradient.offsets[i]
		offsets_image.set_pixel(i, 0, Color(c, c, c, c))
		gradient_image.set_pixel(i, 0, gradient.colors[i])
	offsets_image.unlock()
	gradient_image.unlock()
	var offsets_tex := ImageTexture.new()
	offsets_tex.create_from_image(offsets_image, 0)
	var gradient_tex: Texture
	if shader == shader_linear:
		gradient_tex = gradient_edit.texture
	else:
		gradient_tex = ImageTexture.new()
		gradient_tex.create_from_image(gradient_image, 0)
	var params := {
		"gradient_texture": gradient_tex,
		"offset_texture": offsets_tex,
		"selection": selection_tex,
		"repeat": repeat_option_button.selected,
		"position": (position.value / 100.0) - 0.5,
		"size": size_slider.value / 100.0,
		"angle": angle.value,
		"center": Vector2(center_x.value / 100.0, center_y.value / 100.0),
		"radius": Vector2(radius_x.value, radius_y.value),
		"dither_texture": dither_texture,
		"image_size": project.size,
		"pixel_size": pixel_size,
		"shape": shape_option_button.selected,
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


func _on_ShapeOptionButton_item_selected(index: int) -> void:
	for child in options_cont.get_children():
		if not child.is_in_group("gradient_common"):
			child.visible = false

	match index:
		LINEAR:
			get_tree().set_group("gradient_linear", "visible", true)
		RADIAL:
			get_tree().set_group("gradient_radial", "visible", true)
	update_preview()


func _value_changed(_value: float) -> void:
	update_preview()


func _on_DitheringOptionButton_item_selected(index: int) -> void:
	if index > 0:
		shader = shader_linear_dither
		selected_dither_matrix = dither_matrices[index - 1]
	else:
		shader = shader_linear
	update_preview()


func _on_GradientEdit_updated(_gradient, _cc) -> void:
	update_preview()


func _on_RepeatOptionButton_item_selected(_index: int) -> void:
	update_preview()
