extends ImageEffect

var shader := preload("res://src/Shaders/Effects/Palettize.gdshader")


func _ready() -> void:
	super._ready()
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)


func commit_action(cel: Image, project := Global.current_project) -> void:
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project.size)
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
