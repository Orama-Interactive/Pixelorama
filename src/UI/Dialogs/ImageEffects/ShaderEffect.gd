extends ImageEffect

var shader: Shader
var param_names := []  # String[]
var value_slider_tscn := preload("res://src/UI/Nodes/ValueSlider.tscn")

onready var shader_loaded_label: Label = $VBoxContainer/ShaderLoadedLabel
onready var shader_params: BoxContainer = $VBoxContainer/ShaderParams


func _about_to_show() -> void:
	Global.canvas.selection.transform_content_confirm()
	var frame: Frame = Global.current_project.frames[Global.current_project.current_frame]
	Export.blend_selected_cels(selected_cels, frame)

	preview_image.copy_from(selected_cels)
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture
	._about_to_show()


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	if !shader:
		return

	var params := {}
	for param in param_names:
		var param_data = preview.material.get_shader_param(param)
		params[param] = param_data
	var gen := ShaderImageEffect.new()
	gen.generate_image(cel, shader, params, project.size)
	selected_cels.unlock()
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
	preview = $VBoxContainer/AspectRatioContainer/Preview


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
		else:
			uniform_split[0] = uniform_split[0].replace(";", "").strip_edges()

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
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var slider: ValueSlider = value_slider_tscn.instance()
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

				if range_values_array.size() >= 3:
					step = float(range_values_array[2])
				else:
					step = 0.01

				if u_value != "":
					slider.value = float(u_value)
			else:
				if range_values_array.size() >= 1:
					min_value = int(range_values_array[0])

				if range_values_array.size() >= 2:
					max_value = int(range_values_array[1])

				if range_values_array.size() >= 3:
					step = int(range_values_array[2])

				if u_value != "":
					slider.value = int(u_value)
			slider.min_value = min_value
			slider.max_value = max_value
			slider.step = step
			slider.connect("value_changed", self, "set_shader_param", [u_name])
			var hbox := HBoxContainer.new()
			hbox.add_child(label)
			hbox.add_child(slider)
			shader_params.add_child(hbox)
		elif u_type == "vec2":
			var label := Label.new()
			label.text = u_name
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var vector2 := _vec2str_to_vector2(u_value)
			var slider1: ValueSlider = value_slider_tscn.instance()
			slider1.value = vector2.x
			slider1.connect("value_changed", self, "_set_vector2_shader_param", [u_name, true])
			var slider2: ValueSlider = value_slider_tscn.instance()
			slider2.value = vector2.y
			slider2.connect("value_changed", self, "_set_vector2_shader_param", [u_name, false])
			var hbox := HBoxContainer.new()
			hbox.add_child(label)
			hbox.add_child(slider1)
			hbox.add_child(slider2)
			shader_params.add_child(hbox)
		elif u_type == "vec4":
			if "hint_color" in u_hint:
				var label := Label.new()
				label.text = u_name
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var color := _vec4str_to_color(u_value)
				var color_button := ColorPickerButton.new()
				color_button.rect_min_size = Vector2(20, 20)
				color_button.color = color
				color_button.connect("color_changed", self, "set_shader_param", [u_name])
				color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var hbox := HBoxContainer.new()
				hbox.add_child(label)
				hbox.add_child(color_button)
				shader_params.add_child(hbox)
		elif u_type == "sampler2D":
			var label := Label.new()
			label.text = u_name
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var file_dialog := FileDialog.new()
			file_dialog.mode = FileDialog.MODE_OPEN_FILE
			file_dialog.access = FileDialog.ACCESS_FILESYSTEM
			file_dialog.resizable = true
			file_dialog.rect_min_size = Vector2(200, 70)
			file_dialog.rect_size = Vector2(384, 281)
			file_dialog.connect("file_selected", self, "_load_texture", [u_name])
			var button := Button.new()
			button.text = "Load texture"
			button.connect("pressed", file_dialog, "popup_centered")
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var hbox := HBoxContainer.new()
			hbox.add_child(label)
			hbox.add_child(button)
			shader_params.add_child(hbox)
			shader_params.add_child(file_dialog)
		elif u_type == "bool":
			var label := Label.new()
			label.text = u_name
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var checkbox := CheckBox.new()
			checkbox.text = "On"
			if u_value == "true":
				checkbox.pressed = true
			checkbox.connect("toggled", self, "set_shader_param", [u_name])
			checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var hbox := HBoxContainer.new()
			hbox.add_child(label)
			hbox.add_child(checkbox)
			shader_params.add_child(hbox)


#		print("---")
#		print(uniform_split)
#		print(u_type)
#		print(u_name)
#		print(u_hint)
#		print(u_value)
#		print("--")


func set_shader_param(value, param: String) -> void:
	var mat: ShaderMaterial = preview.material
	mat.set_shader_param(param, value)


func _set_vector2_shader_param(value: float, param: String, x: bool) -> void:
	var mat: ShaderMaterial = preview.material
	var vector2: Vector2 = mat.get_shader_param(param)
	if x:
		vector2.x = value
	else:
		vector2.y = value
	set_shader_param(vector2, param)


func _vec2str_to_vector2(vec2: String) -> Vector2:
	vec2 = vec2.replace("vec2(", "")
	vec2 = vec2.replace(")", "")
	var vec_values: PoolStringArray = vec2.split(",")
	if vec_values.size() == 0:
		return Vector2.ZERO
	var y := float(vec_values[0])
	if vec_values.size() == 2:
		y = float(vec_values[1])
	var vector2 := Vector2(float(vec_values[0]), y)
	return vector2


func _vec4str_to_color(vec4: String) -> Color:
	vec4 = vec4.replace("vec4(", "")
	vec4 = vec4.replace(")", "")
	var rgba_values: PoolStringArray = vec4.split(",")
	var red := float(rgba_values[0])

	var green := float(rgba_values[0])
	if rgba_values.size() >= 2:
		green = float(rgba_values[1])

	var blue := float(rgba_values[0])
	if rgba_values.size() >= 3:
		blue = float(rgba_values[2])

	var alpha := float(rgba_values[0])
	if rgba_values.size() == 4:
		alpha = float(rgba_values[3])
	var color: Color = Color(red, green, blue, alpha)
	return color


func _load_texture(path: String, param: String) -> void:
	var image := Image.new()
	image.load(path)
	if !image:
		print("Error loading texture")
		return
	var image_tex := ImageTexture.new()
	image_tex.create_from_image(image, 0)
	image_tex.flags = ImageTexture.FLAG_REPEAT
	set_shader_param(image_tex, param)
