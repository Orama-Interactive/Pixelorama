extends ImageEffect

enum {LINEAR, RADIAL, STEP, RADIAL_STEP, DITHERING, RADIAL_DITHERING}
enum {BAYER_2, BAYER_4, BAYER_8, BAYER_16}

var confirmed := false
var shader: Shader = preload("res://src/Shaders/Gradients/Linear.gdshader")
#var shader_type: int = LINEAR;
var dither_texture: Texture = preload("res://assets/bayer-matrices/bayer2.png")

onready var options_cont = $VBoxContainer/OptionsContainer
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


func _ready() -> void:
	color1.get_picker().presets_visible = false
	color1.get_picker().deferred_mode = true
	color2.get_picker().presets_visible = false
	color2.get_picker().deferred_mode = true
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)


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
	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		var selection: Image = project.bitmap_to_image(project.selection_bitmap)
		selection_tex.create_from_image(selection, 0)

	var dither_size: Vector2 = dither_texture.get_size()
	var params := {
		"first_color": color1.color,
		"second_color": color2.color,
		"selection": selection_tex,
		"position": position.value,
		"angle": angle.value,
		"center": Vector2(center_x.value, center_y.value),
		"radius": Vector2(radius_x.value, radius_y.value),
		"size": size.value,
		"steps": steps.value,
		"dither_texture": dither_texture,
		"image_size": project.size,
		"dither_steps": dither_size.x * dither_size.y + 1,
		"pixel_size": dither_size.x,
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
#	shader_type = index
	for child in options_cont.get_children():
		if not child.is_in_group("gradient_common"):
			child.visible = false

	match index:
		LINEAR:
			shader = preload("res://src/Shaders/Gradients/Linear.gdshader")
			get_tree().set_group("gradient_linear", "visible", true)
		RADIAL:
			shader = preload("res://src/Shaders/Gradients/Radial.gdshader")
			get_tree().set_group("gradient_radial", "visible", true)
		STEP:
			shader = preload("res://src/Shaders/Gradients/Step.gdshader")
			get_tree().set_group("gradient_step", "visible", true)
		RADIAL_STEP:
			shader = preload("res://src/Shaders/Gradients/RadialStep.gdshader")
			get_tree().set_group("gradient_radial_step", "visible", true)
		DITHERING:
			shader = preload("res://src/Shaders/Gradients/Dithering.gdshader")
			get_tree().set_group("gradient_dithering", "visible", true)
		RADIAL_DITHERING:
			shader = preload("res://src/Shaders/Gradients/RadialDithering.gdshader")
			get_tree().set_group("gradient_radial_dithering", "visible", true)
	update_preview()


func _color_changed(_color: Color) -> void:
	update_preview()


func _value_changed(_value: float) -> void:
	update_preview()


func _on_DitheringOptionButton_item_selected(index: int) -> void:
	match index:
		BAYER_2:
			dither_texture = preload("res://assets/bayer-matrices/bayer2.png")
		BAYER_4:
			dither_texture = preload("res://assets/bayer-matrices/bayer4.png")
		BAYER_8:
			dither_texture = preload("res://assets/bayer-matrices/bayer8.png")
		BAYER_16:
			dither_texture = preload("res://assets/bayer-matrices/bayer16.png")
	update_preview()
