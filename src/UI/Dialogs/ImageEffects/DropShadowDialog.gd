extends ImageEffect

var offset := Vector2(5, 5)
var color := Color.black
var confirmed := false
var shader: Shader = load("res://src/Shaders/DropShadow.tres")

onready var x_spinbox: SpinBox = $VBoxContainer/OptionsContainer/XSpinBox
onready var y_spinbox: SpinBox = $VBoxContainer/OptionsContainer/YSpinBox
onready var shadow_color = $VBoxContainer/OptionsContainer/ShadowColor


func _ready() -> void:
	shadow_color.get_picker().presets_visible = false
	color = shadow_color.color


func _about_to_show() -> void:
	confirmed = false
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)
	._about_to_show()


func _confirmed() -> void:
	confirmed = true
	._confirmed()


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		var selection: Image = project.bitmap_to_image(project.selection_bitmap)
		selection_tex.create_from_image(selection, 0)

	if !confirmed:
		preview.material.set_shader_param("shadow_offset", offset)
		preview.material.set_shader_param("shadow_color", color)
		preview.material.set_shader_param("selection", selection_tex)
	else:
		var params := {
			"shadow_offset": offset,
			"shadow_color": color,
			"selection": selection_tex,
		}
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		yield(gen, "done")


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
