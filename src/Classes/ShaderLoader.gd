class_name ShaderLoader
extends RefCounted

const VALUE_SLIDER_V2_TSCN := preload("res://src/UI/Nodes/ValueSliderV2.tscn")
const BASIS_SLIDERS_TSCN := preload("res://src/UI/Nodes/BasisSliders.tscn")
const GRADIENT_EDIT_TSCN := preload("res://src/UI/Nodes/GradientEdit.tscn")


static func create_ui_for_shader_uniforms(
	shader: Shader,
	params: Dictionary,
	parent_node: Control,
	value_changed: Callable,
	file_selected: Callable
) -> void:
	var code := shader.code.split("\n")
	var uniforms: PackedStringArray = []
	for line in code:
		if line.begins_with("uniform"):
			uniforms.append(line)

	for uniform in uniforms:
		# Example uniform:
		# uniform float parameter_name : hint_range(0, 255) = 100.0;
		var uniform_split := uniform.split("=")
		var u_value := ""
		if uniform_split.size() > 1:
			u_value = uniform_split[1].replace(";", "").strip_edges()
		else:
			uniform_split[0] = uniform_split[0].replace(";", "").strip_edges()

		var u_left_side := uniform_split[0].split(":")
		var u_hint := ""
		if u_left_side.size() > 1:
			u_hint = u_left_side[1].strip_edges()
			u_hint = u_hint.replace(";", "")

		var u_init := u_left_side[0].split(" ")
		var u_type := u_init[1]
		var u_name := u_init[2]
		var humanized_u_name := Keychain.humanize_snake_case(u_name) + ":"

		if u_type == "float" or u_type == "int":
			var label := Label.new()
			label.text = humanized_u_name
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var slider := ValueSlider.new()
			slider.allow_greater = true
			slider.allow_lesser = true
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var min_value := 0.0
			var max_value := 255.0
			var step := 1.0
			var range_values_array: PackedStringArray
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
			if params.has(u_name):
				slider.value = params[u_name]
			else:
				params[u_name] = slider.value
			slider.min_value = min_value
			slider.max_value = max_value
			slider.step = step
			slider.value_changed.connect(value_changed.bind(u_name))
			slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var hbox := HBoxContainer.new()
			hbox.add_child(label)
			hbox.add_child(slider)
			parent_node.add_child(hbox)
		elif u_type == "vec2" or u_type == "ivec2" or u_type == "uvec2":
			var label := Label.new()
			label.text = humanized_u_name
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var vector2 := _vec2str_to_vector2(u_value)
			var slider := VALUE_SLIDER_V2_TSCN.instantiate() as ValueSliderV2
			slider.show_ratio = true
			slider.allow_greater = true
			if u_type != "uvec2":
				slider.allow_lesser = true
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.value = vector2
			if params.has(u_name):
				slider.value = params[u_name]
			else:
				params[u_name] = slider.value
			slider.value_changed.connect(value_changed.bind(u_name))
			var hbox := HBoxContainer.new()
			hbox.add_child(label)
			hbox.add_child(slider)
			parent_node.add_child(hbox)
		elif u_type == "vec4":
			if "source_color" in u_hint:
				var label := Label.new()
				label.text = humanized_u_name
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var color := _vec4str_to_color(u_value)
				var color_button := ColorPickerButton.new()
				color_button.custom_minimum_size = Vector2(20, 20)
				color_button.color = color
				if params.has(u_name):
					color_button.color = params[u_name]
				else:
					params[u_name] = color_button.color
				color_button.color_changed.connect(value_changed.bind(u_name))
				color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				color_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				var hbox := HBoxContainer.new()
				hbox.add_child(label)
				hbox.add_child(color_button)
				parent_node.add_child(hbox)
		elif u_type == "mat3":
			var label := Label.new()
			label.text = humanized_u_name
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var basis := _mat3str_to_basis(u_value)
			var sliders := BASIS_SLIDERS_TSCN.instantiate() as BasisSliders
			sliders.allow_greater = true
			sliders.allow_lesser = true
			sliders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sliders.value = basis
			if params.has(u_name):
				sliders.value = params[u_name]
			else:
				params[u_name] = sliders.value
			sliders.value_changed.connect(value_changed.bind(u_name))
			var hbox := HBoxContainer.new()
			hbox.add_child(label)
			hbox.add_child(sliders)
			parent_node.add_child(hbox)
		elif u_type == "sampler2D":
			if u_name == "selection":
				continue
			if u_name == "palette_texture":
				var palette := Palettes.current_palette
				var palette_texture := ImageTexture.create_from_image(palette.convert_to_image())
				value_changed.call(palette_texture, u_name)
				Palettes.palette_selected.connect(
					func(_name): _shader_change_palette(value_changed, u_name)
				)
				palette.data_changed.connect(
					func(): _shader_update_palette_texture(palette, value_changed, u_name)
				)
				continue
			var label := Label.new()
			label.text = humanized_u_name
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var hbox := HBoxContainer.new()
			hbox.add_child(label)
			if u_name.begins_with("gradient_"):
				var gradient_edit := GRADIENT_EDIT_TSCN.instantiate() as GradientEditNode
				gradient_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				if params.has(u_name) and params[u_name] is GradientTexture2D:
					gradient_edit.set_gradient_texture(params[u_name])
				else:
					params[u_name] = gradient_edit.texture
				# This needs to be call_deferred because GradientTexture2D gets updated next frame.
				# Without this, the texture is purple.
				value_changed.call_deferred(gradient_edit.texture, u_name)
				gradient_edit.updated.connect(
					func(_gradient, _cc): value_changed.call(gradient_edit.texture, u_name)
				)
				hbox.add_child(gradient_edit)
			else:
				var file_dialog := FileDialog.new()
				file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
				file_dialog.access = FileDialog.ACCESS_FILESYSTEM
				file_dialog.size = Vector2(384, 281)
				file_dialog.file_selected.connect(file_selected.bind(u_name))
				file_dialog.use_native_dialog = Global.use_native_file_dialogs
				var button := Button.new()
				button.text = "Load texture"
				button.pressed.connect(file_dialog.popup_centered)
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				hbox.add_child(button)
				parent_node.add_child(file_dialog)
			parent_node.add_child(hbox)

		elif u_type == "bool":
			var label := Label.new()
			label.text = humanized_u_name
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var checkbox := CheckBox.new()
			checkbox.text = "On"
			if u_value == "true":
				checkbox.button_pressed = true
			if params.has(u_name):
				checkbox.button_pressed = params[u_name]
			else:
				params[u_name] = checkbox.button_pressed
			checkbox.toggled.connect(value_changed.bind(u_name))
			checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var hbox := HBoxContainer.new()
			hbox.add_child(label)
			hbox.add_child(checkbox)
			parent_node.add_child(hbox)


static func _vec2str_to_vector2(vec2: String) -> Vector2:
	vec2 = vec2.replace("uvec2", "vec2")
	vec2 = vec2.replace("ivec2", "vec2")
	vec2 = vec2.replace("vec2(", "")
	vec2 = vec2.replace(")", "")
	var vec_values := vec2.split(",")
	if vec_values.size() == 0:
		return Vector2.ZERO
	var y := float(vec_values[0])
	if vec_values.size() == 2:
		y = float(vec_values[1])
	var vector2 := Vector2(float(vec_values[0]), y)
	return vector2


static func _vec3str_to_vector3(vec3: String) -> Vector3:
	vec3 = vec3.replace("uvec3", "vec3")
	vec3 = vec3.replace("ivec3", "vec3")
	vec3 = vec3.replace("vec3(", "")
	vec3 = vec3.replace(")", "")
	var vec_values := vec3.split(",")
	if vec_values.size() == 0:
		return Vector3.ZERO
	var y := float(vec_values[0])
	var z := float(vec_values[0])
	if vec_values.size() >= 2:
		y = float(vec_values[1])
	if vec_values.size() == 3:
		z = float(vec_values[2])
	var vector3 := Vector3(float(vec_values[0]), y, z)
	return vector3


static func _vec4str_to_color(vec4: String) -> Color:
	vec4 = vec4.replace("vec4(", "")
	vec4 = vec4.replace(")", "")
	var rgba_values := vec4.split(",")
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
	var color := Color(red, green, blue, alpha)
	return color


static func _mat3str_to_basis(mat3: String) -> Basis:
	mat3 = mat3.replace("mat3(", "")
	mat3 = mat3.replace("))", ")")
	mat3 = mat3.replace("), ", ")")
	var vec3_values := mat3.split("vec3", false)
	var vec3_x := _vec3str_to_vector3(vec3_values[0])

	var vec3_y := _vec3str_to_vector3(vec3_values[0])
	if vec3_values.size() >= 2:
		vec3_y = _vec3str_to_vector3(vec3_values[1])

	var vec3_z := _vec3str_to_vector3(vec3_values[0])
	if vec3_values.size() == 3:
		vec3_z = _vec3str_to_vector3(vec3_values[2])
	var basis := Basis(vec3_x, vec3_y, vec3_z)
	return basis


static func _shader_change_palette(value_changed: Callable, parameter_name: String) -> void:
	var palette := Palettes.current_palette
	_shader_update_palette_texture(palette, value_changed, parameter_name)
	#if not palette.data_changed.is_connected(_shader_update_palette_texture):
	palette.data_changed.connect(
		func(): _shader_update_palette_texture(palette, value_changed, parameter_name)
	)


static func _shader_update_palette_texture(
	palette: Palette, value_changed: Callable, parameter_name: String
) -> void:
	value_changed.call(ImageTexture.create_from_image(palette.convert_to_image()), parameter_name)
