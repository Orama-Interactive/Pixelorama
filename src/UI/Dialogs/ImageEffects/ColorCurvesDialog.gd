extends ImageEffect

enum Channel { RGB, RED, GREEN, BLUE, ALPHA, HUE, SATURATION, VALUE }
const SHADER := preload("res://src/Shaders/Effects/ColorCurves.gdshader")

var curves: Array[Curve]
@onready var channel_option_button := %ChannelOptionButton as OptionButton
@onready var curve_edit := $VBoxContainer/CurveEdit as CurveEdit


func _ready() -> void:
	super._ready()
	var sm := ShaderMaterial.new()
	sm.shader = SHADER
	preview.set_material(sm)
	for i in channel_option_button.item_count:
		var curve := Curve.new()
		curve.add_point(Vector2.ZERO, 0, 1, Curve.TANGENT_LINEAR)
		curve.add_point(Vector2.ONE, 1, 0, Curve.TANGENT_LINEAR)
		curves.append(curve)
	curve_edit.curve = curves[Channel.RGB]


func commit_action(cel: Image, project := Global.current_project) -> void:
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	var params := {
		"curve_rgb": CurveEdit.to_texture(curves[Channel.RGB]),
		"curve_red": CurveEdit.to_texture(curves[Channel.RED]),
		"curve_green": CurveEdit.to_texture(curves[Channel.GREEN]),
		"curve_blue": CurveEdit.to_texture(curves[Channel.BLUE]),
		"curve_alpha": CurveEdit.to_texture(curves[Channel.ALPHA]),
		"curve_hue": CurveEdit.to_texture(curves[Channel.HUE]),
		"curve_sat": CurveEdit.to_texture(curves[Channel.SATURATION]),
		"curve_value": CurveEdit.to_texture(curves[Channel.VALUE]),
		"selection": selection_tex
	}
	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, SHADER, params, project.size)


func _on_channel_option_button_item_selected(index: int) -> void:
	curve_edit.curve = curves[index]
