extends ImageEffect

var offset := Vector2(5, 5)
var color := Color.BLACK
var shader: Shader = load("res://src/Shaders/DropShadow.tres")

@onready var x_spinbox: SpinBox = $VBoxContainer/OptionsContainer/XSpinBox
@onready var y_spinbox: SpinBox = $VBoxContainer/OptionsContainer/YSpinBox
@onready var shadow_color = $VBoxContainer/OptionsContainer/ShadowColor


func _ready() -> void:
	super._ready()
	shadow_color.get_picker().presets_visible = false
	color = shadow_color.color
	var sm := ShaderMaterial.new()
	sm.shader = shader
	if preview:
		preview.set_material(sm)


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		selection_tex = ImageTexture.create_from_image(project.selection_map)

	var params := {
		"shadow_offset": offset,
		"shadow_color": color,
		"selection": selection_tex,
	}
	if !is_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		await gen.done


func _on_XSpinBox_value_changed(value) -> void:
	x_spinbox.max_value = value + 1
	x_spinbox.min_value = value - 1
	offset.x = value
	update_preview()


func _on_YSpinBox_value_changed(value) -> void:
	y_spinbox.max_value = value + 1
	y_spinbox.min_value = value - 1
	offset.y = value
	update_preview()


func _on_OutlineColor_color_changed(_color: Color) -> void:
	color = _color
	update_preview()
