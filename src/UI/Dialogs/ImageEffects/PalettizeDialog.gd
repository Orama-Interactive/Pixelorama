extends ImageEffect

var shader_inc := load("uid://c5t0262v2fi4v")
var shader: Shader


func _ready() -> void:
	shader = ShaderLoader.generate_texture_blit_shader(shader_inc)
	super()
	var sm := ShaderMaterial.new()
	sm.shader = ShaderLoader.generate_canvas_item_shader(shader_inc)
	preview.set_material(sm)


func commit_action(cel: Image, project := Global.current_project) -> void:
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project, project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	if not is_instance_valid(Palettes.current_palette):
		return
	var palette_image := Palettes.current_palette.convert_to_image()
	var palette_texture := ImageTexture.create_from_image(palette_image)

	var params := {"palette_texture": palette_texture, "selection": selection_tex}
	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
