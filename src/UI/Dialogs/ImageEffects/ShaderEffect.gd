extends ImageEffect

var shader: Shader
var param_names := []  # String[]

onready var shader_loaded_label: Label = $VBoxContainer/ShaderLoadedLabel
onready var shader_params: BoxContainer = $VBoxContainer/ShaderParams


func _about_to_show() -> void:
	Global.canvas.selection.transform_content_confirm()
	var frame: Frame = Global.current_project.frames[Global.current_project.current_frame]
	current_cel = frame.cels[Global.current_project.current_layer].image

	preview_image.copy_from(current_cel)
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	if !shader:
		return

	var params := {}
	for param in param_names:
		var param_data = preview.material.get_shader_param(param)
		params[param] = param_data
	var gen := ShaderImageEffect.new()
	gen.generate_image(cel, shader, params, project.size)
	current_cel.unlock()
	yield(gen, "done")


func _on_ChooseShader_pressed() -> void:
	if OS.get_name() == "HTML5":
		Html5FileExchange.load_shader()
	else:
		$FileDialog.popup_centered(Vector2(300, 340))


func _on_FileDialog_file_selected(path: String) -> void:
	var shader_tmp = load(path)
	if !shader_tmp is Shader:
		return
	change_shader(shader_tmp, path.get_file().get_basename())


func set_nodes() -> void:
	preview = $VBoxContainer/Preview


func change_shader(shader_tmp: Shader, name: String) -> void:
	shader = shader_tmp
	preview.material.shader = shader_tmp
	shader_loaded_label.text = tr("Shader loaded:") + " " + name
	param_names.clear()
	for child in shader_params.get_children():
		child.queue_free()

	var code := shader.code.split("\n")
	var uniforms := []
	for line in code:
		if line.begins_with("uniform"):
			uniforms.append(line)

	for uniform in uniforms:
		# Example uniform:
		# uniform float parameter_name : hint_range(0, 255) = 100.0;
		var uniform_split: PoolStringArray = uniform.split("=")
		var u_value := ""
		if uniform_split.size() > 1:
			u_value = uniform_split[1].replace(";", "").strip_edges()

		var u_left_side: PoolStringArray = uniform_split[0].split(":")
		var u_hint := ""
		if u_left_side.size() > 1:
			u_hint = u_left_side[1].strip_edges()
			u_hint = u_hint.replace(";", "")

		var u_init: PoolStringArray = u_left_side[0].split(" ")
		var u_type: String = u_init[1]
		var u_name: String = u_init[2]
		param_names.append(u_name)

		if u_type == "float" or u_type == "int":
			var label := Label.new()
			label.text = u_name
			var spinbox := SpinBox.new()
			var min_value := 0.0
			var max_value := 255.0
			var step := 1.0
			var range_values_array: PoolStringArray
			if "hint_range" in u_hint:
				var range_values: String = u_hint.replace("hint_range(", "")
				range_values = range_values.replace(")", "").strip_edges()
				range_values_array = range_values.split(",")

			if u_type == "float":
				if range_values_array.size() >= 1:
					min_value = float(range_values_array[0])
				else:
					min_value = 0.01

				if range_values_array.size() >= 2:
					max_value = float(range_values_array[1])
				else:
					max_value = 255

				if range_values_array.size() >= 3:
					step = float(range_values_array[2])
				else:
					step = 0.01

				if u_value != "":
					spinbox.value = float(u_value)
			else:
				if range_values_array.size() >= 1:
					min_value = int(range_values_array[0])

				if range_values_array.size() >= 2:
					max_value = int(range_values_array[1])

				if range_values_array.size() >= 3:
					step = int(range_values_array[2])

				if u_value != "":
					spinbox.value = int(u_value)
			spinbox.min_value = min_value
			spinbox.max_value = max_value
			spinbox.step = step
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


func set_shader_param(value, param: String) -> void:
	preview.material.set_shader_param(param, value)
