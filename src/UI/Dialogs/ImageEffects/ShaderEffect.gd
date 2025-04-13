extends ImageEffect

var shader: Shader
var params := {}

@onready var shader_params := $VBoxContainer/ShaderParams as VBoxContainer


func _about_to_popup() -> void:
	Global.canvas.selection.transform_content_confirm()
	var frame := Global.current_project.frames[Global.current_project.current_frame]
	DrawingAlgos.blend_layers(selected_cels, frame, Vector2i.ZERO, Global.current_project, true)

	preview_image.copy_from(selected_cels)
	preview.texture = ImageTexture.create_from_image(preview_image)
	super._about_to_popup()


func set_nodes() -> void:
	aspect_ratio_container = $VBoxContainer/AspectRatioContainer
	preview = $VBoxContainer/AspectRatioContainer/Preview


func commit_action(cel: Image, project := Global.current_project) -> void:
	if not is_instance_valid(shader):
		return
	var gen := ShaderImageEffect.new()
	gen.generate_image(cel, shader, params, project.size)


func change_shader(shader_tmp: Shader, shader_name: String) -> void:
	shader = shader_tmp
	preview.material.shader = shader_tmp
	title = shader_name
	params.clear()
	for child in shader_params.get_children():
		child.queue_free()

	ShaderLoader.create_ui_for_shader_uniforms(
		shader_tmp, params, shader_params, _set_shader_parameter, _load_texture
	)


func _set_shader_parameter(value, param: String) -> void:
	var mat: ShaderMaterial = preview.material
	mat.set_shader_parameter(param, value)
	params[param] = value


func _load_texture(path: String, param: String) -> void:
	var image := Image.new()
	image.load(path)
	if !image:
		print("Error loading texture")
		return
	var image_tex := ImageTexture.create_from_image(image)
	_set_shader_parameter(image_tex, param)
