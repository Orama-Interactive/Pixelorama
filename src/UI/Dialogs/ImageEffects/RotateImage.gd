extends ImageEffect

var live_preview: bool = true
var shader: Shader = preload("res://src/Shaders/Rotation.shader")

onready var type_option_button: OptionButton = $VBoxContainer/HBoxContainer2/TypeOptionButton
onready var angle_hslider: HSlider = $VBoxContainer/AngleOptions/AngleHSlider
onready var angle_spinbox: SpinBox = $VBoxContainer/AngleOptions/AngleSpinBox
onready var wait_apply_timer = $WaitApply
onready var wait_time_spinbox = $VBoxContainer/WaitSettings/WaitTime

var pivot := Vector2.ZERO


func _ready() -> void:
	type_option_button.add_item("Rotxel")
	type_option_button.add_item("Upscale, Rotate and Downscale")
	type_option_button.add_item("Nearest neighbour")
	type_option_button.add_item("Nearest neighbour (Shader)")


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func _about_to_show() -> void:
	$VBoxContainer/Pivot/Options.visible = false
	$VBoxContainer/Pivot/TogglePivot.pressed = false
	decide_pivot()
	confirmed = false
	._about_to_show()
	wait_apply_timer.wait_time = wait_time_spinbox.value / 1000.0
	angle_hslider.value = 0


func decide_pivot():
	var size := Global.current_project.size
	pivot = Vector2(size.x / 2, size.y / 2)

	# Pivot correction in case of even size
	if type_option_button.text != "Nearest neighbour (Shader)":
		if int(size.x) % 2 == 0:
			pivot.x -= 0.5
		if int(size.y) % 2 == 0:
			pivot.y -= 0.5

	if Global.current_project.has_selection and selection_checkbox.pressed:
		var selection_rectangle: Rect2 = Global.current_project.get_selection_rectangle()
		pivot = (
			selection_rectangle.position
			+ ((selection_rectangle.end - selection_rectangle.position) / 2)
		)
		if type_option_button.text != "Nearest neighbour (Shader)":
			# Pivot correction in case of even size
			if int(selection_rectangle.end.x - selection_rectangle.position.x) % 2 == 0:
				pivot.x -= 0.5
			if int(selection_rectangle.end.y - selection_rectangle.position.y) % 2 == 0:
				pivot.y -= 0.5


func commit_action(_cel: Image, _project: Project = Global.current_project) -> void:
	var angle: float = deg2rad(angle_hslider.value)
# warning-ignore:integer_division
# warning-ignore:integer_division

	var selection_size := _cel.get_size()
	var selection_tex := ImageTexture.new()

	var image := Image.new()
	image.copy_from(_cel)
	if _project.has_selection and selection_checkbox.pressed:
		var selection_rectangle: Rect2 = _project.get_selection_rectangle()
		selection_size = selection_rectangle.size

		var selection: Image = _project.bitmap_to_image(_project.selection_bitmap)
		selection_tex.create_from_image(selection, 0)

		if type_option_button.text != "Nearest neighbour (Shader)":
			image.lock()
			_cel.lock()
			for x in _project.size.x:
				for y in _project.size.y:
					var pos := Vector2(x, y)
					if !_project.can_pixel_get_drawn(pos):
						image.set_pixelv(pos, Color(0, 0, 0, 0))
					else:
						_cel.set_pixelv(pos, Color(0, 0, 0, 0))
			image.unlock()
			_cel.unlock()
	match type_option_button.text:
		"Rotxel":
			DrawingAlgos.rotxel(image, angle, pivot)
		"Nearest neighbour":
			DrawingAlgos.nn_rotate(image, angle, pivot)
		"Upscale, Rotate and Downscale":
			DrawingAlgos.fake_rotsprite(image, angle, pivot)
		"Nearest neighbour (Shader)":
			if !confirmed:
				preview.material.set_shader_param("angle", angle)
				preview.material.set_shader_param("selection_tex", selection_tex)
				preview.material.set_shader_param("selection_pivot", pivot)
				preview.material.set_shader_param("selection_size", selection_size)
			else:
				var params = {
					"angle": angle,
					"selection_tex": selection_tex,
					"selection_pivot": pivot,
					"selection_size": selection_size
				}
				var gen := ShaderImageEffect.new()
				gen.generate_image(_cel, shader, params, _project.size)
				yield(gen, "done")

	if (
		_project.has_selection
		and selection_checkbox.pressed
		and type_option_button.text != "Nearest neighbour (Shader)"
	):
		_cel.blend_rect(image, Rect2(Vector2.ZERO, image.get_size()), Vector2.ZERO)
	else:
		_cel.blit_rect(image, Rect2(Vector2.ZERO, image.get_size()), Vector2.ZERO)


func _on_HSlider_value_changed(_value: float) -> void:
	angle_spinbox.value = angle_hslider.value
	if live_preview:
		update_preview()
	else:
		wait_apply_timer.start()


func _on_SpinBox_value_changed(_value: float) -> void:
	angle_hslider.value = angle_spinbox.value


func _on_TypeOptionButton_item_selected(_id: int) -> void:
	if type_option_button.text == "Nearest neighbour (Shader)":
		var sm = ShaderMaterial.new()
		sm.shader = shader
		preview.set_material(sm)
	else:
		preview.set_material(null)
	update_preview()


func _on_WaitApply_timeout() -> void:
	update_preview()


func _on_WaitTime_value_changed(value: float) -> void:
	wait_apply_timer.wait_time = value / 1000.0


func _on_LiveCheckbox_toggled(button_pressed: bool) -> void:
	live_preview = button_pressed
	wait_time_spinbox.editable = !live_preview
	wait_time_spinbox.get_parent().visible = !live_preview
	if !button_pressed:
		rect_size.y += 1  # Reset rect_size of dialog


func _on_quick_change_angle_pressed(change_type: String) -> void:
	var current_angle = angle_hslider.value
	var new_angle = current_angle
	match change_type:
		"-90":
			new_angle = current_angle - 90
		"-45":
			new_angle = current_angle - 45
		"0":
			new_angle = 0
		"+45":
			new_angle = current_angle + 45
		"+90":
			new_angle = current_angle + 90

	if new_angle < 0:
		new_angle = new_angle + 360
	elif new_angle >= 360:
		new_angle = new_angle - 360
	angle_hslider.value = new_angle


func _on_TogglePivot_toggled(button_pressed: bool) -> void:
	$VBoxContainer/Pivot/Options.visible = button_pressed
	if button_pressed:
		$VBoxContainer/Pivot/TogglePivot.text = "Pivot Options: (v)"
		$VBoxContainer/Pivot/TogglePivot.focus_mode = 0
		$VBoxContainer/Pivot/Options/X/XPivot.value = pivot.x
		$VBoxContainer/Pivot/Options/Y/YPivot.value = pivot.y
	else:
		$VBoxContainer/Pivot/TogglePivot.text = "Pivot Options: (>)"
		$VBoxContainer/Pivot/TogglePivot.focus_mode = 0
	rect_size.y += 1  # Reset rect_size of dialog


func _on_Pivot_value_changed(value: float, is_x: bool) -> void:
	if is_x:
		pivot.x = value
	else:
		pivot.y = value
	# Refresh the indicator
	$VBoxContainer/AspectRatioContainer/Indicator.update()
	update_preview()


func _on_Indicator_draw() -> void:
	var pivot_indicator = $VBoxContainer/AspectRatioContainer/Indicator
	var img_size := preview_image.get_size()
	# find the scale using the larger measurement
	var ratio = pivot_indicator.rect_size / img_size
	# we need to set the scale according to the larger side
	var conversion_scale: float
	if img_size.x > img_size.y:
		conversion_scale = ratio.x
	else:
		conversion_scale = ratio.y
	var pivot_position = pivot * conversion_scale
	pivot_indicator.draw_arc(pivot_position, 2, 0, 360, 360, Color.yellow, 0.5)
	pivot_indicator.draw_arc(pivot_position, 6, 0, 360, 360, Color.white, 0.5)
	pivot_indicator.draw_line(
		pivot_position - Vector2.UP * 10, pivot_position - Vector2.DOWN * 10, Color.white, 0.5
	)
	pivot_indicator.draw_line(
		pivot_position - Vector2.RIGHT * 10, pivot_position - Vector2.LEFT * 10, Color.white, 0.5
	)


func _on_Indicator_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.pressure == 1.0:
			var pivot_indicator = $VBoxContainer/AspectRatioContainer/Indicator
			var x_pivot = $VBoxContainer/Pivot/Options/X/XPivot
			var y_pivot = $VBoxContainer/Pivot/Options/Y/YPivot
			var img_size := preview_image.get_size()
			var mouse_pos = get_local_mouse_position() - pivot_indicator.rect_position
			var ratio = img_size / pivot_indicator.rect_size
			# we need to set the scale according to the larger side
			var conversion_scale: float
			if img_size.x > img_size.y:
				conversion_scale = ratio.x
			else:
				conversion_scale = ratio.y
			var new_pos = mouse_pos * conversion_scale
			x_pivot.value = new_pos.x
			y_pivot.value = new_pos.y
			pivot_indicator.update()
