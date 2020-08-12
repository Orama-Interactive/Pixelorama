extends ConfirmationDialog


var current_cel : Image
var shader : Shader
var params := [] # String[]

onready var preview : TextureRect = $VBoxContainer/Preview
onready var shader_loaded_label : Label = $VBoxContainer/ShaderLoadedLabel
onready var shader_params : BoxContainer = $VBoxContainer/ShaderParams


func _on_ShaderEffect_about_to_show() -> void:
	current_cel = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image

	var preview_image := Image.new()
	preview_image.copy_from(current_cel)
	var preview_texture = ImageTexture.new()
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


func _on_ShaderEffect_confirmed() -> void:
	if !shader:
		return
	current_cel.unlock()
	var viewport_texture := Image.new()
	var size : Vector2 = Global.current_project.size
	var vp = VisualServer.viewport_create()
	var canvas = VisualServer.canvas_create()
	VisualServer.viewport_attach_canvas(vp, canvas)
	VisualServer.viewport_set_size(vp, size.x, size.y)
	VisualServer.viewport_set_disable_3d(vp, true)
	VisualServer.viewport_set_usage(vp, VisualServer.VIEWPORT_USAGE_2D)
	VisualServer.viewport_set_hdr(vp, true)
	VisualServer.viewport_set_active(vp, true)
	VisualServer.viewport_set_transparent_background(vp, true)

	var ci_rid = VisualServer.canvas_item_create()
	VisualServer.viewport_set_canvas_transform(vp, canvas, Transform())
	VisualServer.canvas_item_set_parent(ci_rid, canvas)
	var texture = ImageTexture.new()
	texture.create_from_image(current_cel)
	VisualServer.canvas_item_add_texture_rect(ci_rid, Rect2(Vector2(0, 0), size), texture)

	var mat_rid = VisualServer.material_create()
	VisualServer.material_set_shader(mat_rid, shader.get_rid())
	VisualServer.canvas_item_set_material(ci_rid, mat_rid)
	for param in params:
		var param_data = preview.material.get_shader_param(param)
		VisualServer.material_set_param(mat_rid, param, param_data)

	VisualServer.viewport_set_update_mode(vp, VisualServer.VIEWPORT_UPDATE_ONCE)
	VisualServer.viewport_set_vflip(vp, true)
	VisualServer.force_draw(false)
	viewport_texture = VisualServer.texture_get_data(VisualServer.viewport_get_texture(vp))
	VisualServer.free_rid(vp)
	VisualServer.free_rid(canvas)
	VisualServer.free_rid(ci_rid)
	VisualServer.free_rid(mat_rid)
	print(viewport_texture.data)
	viewport_texture.convert(Image.FORMAT_RGBA8)
	Global.canvas.handle_undo("Draw")
	current_cel.copy_from(viewport_texture)
	Global.canvas.handle_redo("Draw")
	current_cel.lock()


func _on_ShaderEffect_popup_hide() -> void:
	Global.dialog_open(false)


func _on_ChooseShader_pressed() -> void:
	if OS.get_name() == "HTML5":
		Html5FileExchange.load_shader()
	else:
		$FileDialog.popup_centered(Vector2(300, 340))


func _on_FileDialog_file_selected(path : String) -> void:
	var _shader = load(path)
	if !_shader is Shader:
		return
	change_shader(_shader, path.get_file().get_basename())


func change_shader(_shader : Shader, name : String) -> void:
	shader = _shader
	preview.material.shader = _shader
	shader_loaded_label.text = tr("Shader loaded:") + " " + name
	params.clear()
	for child in shader_params.get_children():
		child.queue_free()

	var code = shader.code.split("\n")
	var uniforms := []
	for line in code:
		if line.begins_with("uniform"):
			uniforms.append(line)

	for uniform in uniforms:
		# Example uniform:
		# uniform float parameter_name : hint_range(0, 255) = 100.0;
		var uniform_split = uniform.split("=")
		var u_value := ""
		if uniform_split.size() > 1:
			u_value = uniform_split[1].replace(";", "").strip_edges()

		var u_left_side = uniform_split[0].split(":")
		var _u_hint := ""
		if u_left_side.size() > 1:
			_u_hint = u_left_side[1].strip_edges()

		var u_init = u_left_side[0].split(" ")
		var u_type = u_init[1]
		var u_name = u_init[2]
		params.append(u_name)

		if u_type == "float":
			var label := Label.new()
			label.text = u_name
			var spinbox := SpinBox.new()
			spinbox.min_value = 0.01
			spinbox.max_value = 255
			spinbox.step = 0.01
			if u_value != "":
				spinbox.value = float(u_value)
			spinbox.connect("value_changed", self, "set_shader_param", [u_name])
			var hbox := HBoxContainer.new()
			hbox.add_child(label)
			hbox.add_child(spinbox)
			shader_params.add_child(hbox)

#		print("---")
#		print(uniform_split)
#		print(u_type)
#		print(u_name)
#		print(u_hint)
#		print(u_value)
#		print("--")


func set_shader_param(value, param : String) -> void:
	preview.material.set_shader_param(param, value)
