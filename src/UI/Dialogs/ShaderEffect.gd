extends ConfirmationDialog


var current_cel : Image

onready var viewport : Viewport = $VBoxContainer/ViewportContainer/Viewport
onready var preview : TextureRect = viewport.get_node("Preview")
onready var shader_loaded_label : Label = $VBoxContainer/ShaderLoadedLabel
onready var shader_params : BoxContainer = $VBoxContainer/ShaderParams


func _on_ShaderEffect_about_to_show() -> void:
	current_cel = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	current_cel.unlock()
	viewport.size = Global.current_project.size
#	var viewport_texture = viewport.get_texture().get_data()
#	viewport_texture.convert(Image.FORMAT_RGBA8)

	var preview_image := Image.new()
	preview_image.copy_from(current_cel)
	var preview_texture = ImageTexture.new()
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


func _on_ShaderEffect_confirmed() -> void:
	var viewport_texture := Image.new()
	viewport_texture.copy_from(viewport.get_texture().get_data())
	var viewport_texture_size = viewport_texture.get_size()
	if viewport_texture_size == Vector2.ZERO:
		return
	viewport_texture.flip_y()
	viewport_texture.convert(Image.FORMAT_RGBA8)
	print(viewport_texture.get_size())
	Global.canvas.handle_undo("Draw")
	current_cel.copy_from(viewport_texture)
	Global.canvas.handle_redo("Draw")


func _on_ShaderEffect_popup_hide() -> void:
	current_cel.lock()
	Global.dialog_open(false)
	yield(get_tree().create_timer(0.2), "timeout")
	preview.texture = null
	viewport.size = Vector2.ONE
	rect_size = Vector2.ONE


func _on_ChooseShader_pressed() -> void:
	if OS.get_name() == "HTML5":
		Html5FileExchange.load_shader()
	else:
		$FileDialog.popup_centered(Vector2(300, 340))


func _on_FileDialog_file_selected(path : String) -> void:
	var shader = load(path)
	if !shader is Shader:
		return
	change_shader(shader, path.get_file().get_basename())


func change_shader(shader : Shader, name : String) -> void:
	preview.material.shader = shader
	shader_loaded_label.text = tr("Shader loaded:") + " " + name
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
		var u_hint := ""
		if u_left_side.size() > 1:
			u_hint = u_left_side[1].strip_edges()

		var u_init = u_left_side[0].split(" ")
		var u_type = u_init[1]
		var u_name = u_init[2]

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
