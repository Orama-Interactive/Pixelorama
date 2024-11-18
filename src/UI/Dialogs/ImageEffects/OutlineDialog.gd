extends ImageEffect

enum Animate { THICKNESS }
var color := Color.BLACK
var thickness := 1
var pattern := 0
var inside_image := false
var shader := preload("res://src/Shaders/Effects/OutlineInline.gdshader")

@onready var outline_color := $VBoxContainer/OutlineOptions/OutlineColor as ColorPickerButton


func _ready() -> void:
	super._ready()
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)
	outline_color.get_picker().presets_visible = false
	color = outline_color.color
	# Set in the order of the Animate enum
	animate_panel.add_float_property("Thickness", $VBoxContainer/OutlineOptions/ThickValue)


func commit_action(cel: Image, project := Global.current_project) -> void:
	var anim_thickness := animate_panel.get_animated_value(commit_idx, Animate.THICKNESS)
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	var params := {
		"color": color,
		"width": anim_thickness,
		"brush": pattern,
		"inside": inside_image,
		"selection": selection_tex
	}
	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
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
