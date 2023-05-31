extends ImageEffect

var color := Color.RED
var thickness := 1
var pattern := 0
var inside_image := false
var shader: Shader

@onready var outline_color = $VBoxContainer/OptionsContainer/OutlineColor


func _ready() -> void:
	super._ready()
	# Disabled by Variable (Cause: no OS.get_current_video_driver())
#	if _is_webgl1():
#		$VBoxContainer/OptionsContainer/PatternOptionButton.disabled = true
#	else:
#		shader = load("res://src/Shaders/OutlineInline.gdshader")
#		var sm := ShaderMaterial.new()
#		sm.gdshader = shader
#		preview.set_material(sm)

	outline_color.get_picker().presets_visible = false
	color = outline_color.color


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	if !shader:  # Web version
		DrawingAlgos.generate_outline(
			cel, selection_checkbox.button_pressed, project, color, thickness, false, inside_image
		)
		return

	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		selection_tex = ImageTexture.create_from_image(project.selection_map)

	var params := {
		"color": color,
		"width": thickness,
		"pattern": pattern,
		"inside": inside_image,
		"selection": selection_tex,
		"affect_selection": selection_checkbox.button_pressed,
		"has_selection": project.has_selection
	}
	if !is_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		await gen.done


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
