extends ImageEffect


var red := true
var green := true
var blue := true
var alpha := false

var shaderPath : String = "res://src/Shaders/Desaturate.shader"

var confirmed: bool = false
func _about_to_show():
	var sm : ShaderMaterial = ShaderMaterial.new()
	sm.shader = load(shaderPath)
	preview.set_material(sm)
	._about_to_show()


func set_nodes() -> void:
	preview = $VBoxContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func _confirmed() -> void:
	confirmed = true
	._confirmed()

func commit_action(_cel : Image, _project : Project = Global.current_project) -> void:
	var selection = _project.bitmap_to_image(_project.selection_bitmap, false)
	var selection_tex = ImageTexture.new()
	selection_tex.create_from_image(selection)

	if !confirmed:
		preview.material.set_shader_param("red", red)
		preview.material.set_shader_param("blue", blue)
		preview.material.set_shader_param("green", green)
		preview.material.set_shader_param("alpha", alpha)
		preview.material.set_shader_param("selection", selection_tex)
		preview.material.set_shader_param("affect_selection", selection_checkbox.pressed)
		preview.material.set_shader_param("has_selection", _project.has_selection)
	else:
		var params = {
			"red": red,
			"blue": blue,
			"green": green,
			"alpha": alpha,
			"selection": selection_tex,
			"affect_selection": selection_checkbox.pressed,
			"has_selection": _project.has_selection
		}
		var gen: ShaderImageEffect = ShaderImageEffect.new()
		gen.generate_image(_cel, shaderPath, params, _project.size)
		yield(gen, "done")


func _on_RButton_toggled(button_pressed : bool) -> void:
	red = button_pressed
	update_preview()


func _on_GButton_toggled(button_pressed : bool) -> void:
	green = button_pressed
	update_preview()


func _on_BButton_toggled(button_pressed : bool) -> void:
	blue = button_pressed
	update_preview()


func _on_AButton_toggled(button_pressed : bool) -> void:
	alpha = button_pressed
	update_preview()
