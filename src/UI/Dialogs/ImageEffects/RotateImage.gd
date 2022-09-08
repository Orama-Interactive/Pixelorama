extends ImageEffect

var live_preview: bool = true
var rotxel_shader: Shader
var nn_shader: Shader = preload("res://src/Shaders/Rotation/NearestNeightbour.shader")
var pivot := Vector2.INF
var drag_pivot := false

onready var type_option_button: OptionButton = $VBoxContainer/HBoxContainer2/TypeOptionButton
onready var pivot_indicator: Control = $VBoxContainer/AspectRatioContainer/Indicator
onready var x_pivot: SpinBox = $VBoxContainer/TitleButtons/XPivot
onready var y_pivot: SpinBox = $VBoxContainer/TitleButtons/YPivot
onready var angle_hslider: HSlider = $VBoxContainer/AngleOptions/AngleHSlider
onready var angle_spinbox: SpinBox = $VBoxContainer/AngleOptions/AngleSpinBox
onready var smear_options: Container = $VBoxContainer/SmearOptions
onready var init_angle_hslider: HSlider = smear_options.get_node("AngleOptions/InitialAngleHSlider")
onready var init_angle_spinbox: SpinBox = smear_options.get_node("AngleOptions/InitialAngleSpinBox")
onready var tolerance_hslider: HSlider = smear_options.get_node("Tolerance/ToleranceHSlider")
onready var tolerance_spinbox: SpinBox = smear_options.get_node("Tolerance/ToleranceSpinBox")
onready var wait_apply_timer: Timer = $WaitApply
onready var wait_time_spinbox: SpinBox = $VBoxContainer/WaitSettings/WaitTime


func _ready() -> void:
	# Algorithms are arranged according to their speed
	if OS.get_name() != "HTML5":
		type_option_button.add_item("Rotxel with Smear")
		rotxel_shader = load("res://src/Shaders/Rotation/SmearRotxel.shader")
	type_option_button.add_item("Nearest neighbour (Shader)")
	type_option_button.add_item("Nearest neighbour")
	type_option_button.add_item("Rotxel")
	type_option_button.add_item("Upscale, Rotate and Downscale")
	type_option_button.emit_signal("item_selected", 0)


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func _about_to_show() -> void:
	drag_pivot = false
	if pivot == Vector2.INF:
		decide_pivot()
	confirmed = false
	._about_to_show()
	wait_apply_timer.wait_time = wait_time_spinbox.value / 1000.0
	angle_hslider.value = 0


func decide_pivot() -> void:
	var size := Global.current_project.size
	pivot = size / 2

	# Pivot correction in case of even size
	if type_option_button.text != "Nearest neighbour (Shader)":
		if int(size.x) % 2 == 0:
			pivot.x -= 0.5
		if int(size.y) % 2 == 0:
			pivot.y -= 0.5

	if Global.current_project.has_selection and selection_checkbox.pressed:
		var selection_rectangle: Rect2 = Global.current_project.selection_map.get_used_rect()
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

	x_pivot.value = pivot.x
	y_pivot.value = pivot.y


func commit_action(cel: Image, _project: Project = Global.current_project) -> void:
	var angle: float = deg2rad(angle_hslider.value)

	var selection_size := cel.get_size()
	var selection_tex := ImageTexture.new()

	var image := Image.new()
	image.copy_from(cel)
	if _project.has_selection and selection_checkbox.pressed:
		var selection_rectangle: Rect2 = _project.selection_map.get_used_rect()
		selection_size = selection_rectangle.size

		var selection: Image = _project.selection_map
		selection_tex.create_from_image(selection, 0)

		if !_type_is_shader():
			image.lock()
			cel.lock()
			for x in _project.size.x:
				for y in _project.size.y:
					var pos := Vector2(x, y)
					if !_project.can_pixel_get_drawn(pos):
						image.set_pixelv(pos, Color(0, 0, 0, 0))
					else:
						cel.set_pixelv(pos, Color(0, 0, 0, 0))
			image.unlock()
			cel.unlock()
	match type_option_button.text:
		"Rotxel with Smear":
			var params := {
				"initial_angle": init_angle_hslider.value,
				"ending_angle": angle_hslider.value,
				"tolerance": tolerance_hslider.value,
				"selection_tex": selection_tex,
				"origin": pivot / cel.get_size(),
				"selection_size": selection_size
			}
			if !confirmed:
				for param in params:
					preview.material.set_shader_param(param, params[param])
			else:
				var gen := ShaderImageEffect.new()
				gen.generate_image(cel, rotxel_shader, params, _project.size)
				yield(gen, "done")

		"Nearest neighbour (Shader)":
			var params := {
				"angle": angle,
				"selection_tex": selection_tex,
				"selection_pivot": pivot,
				"selection_size": selection_size
			}
			if !confirmed:
				for param in params:
					preview.material.set_shader_param(param, params[param])
			else:
				var gen := ShaderImageEffect.new()
				gen.generate_image(cel, nn_shader, params, _project.size)
				yield(gen, "done")
		"Rotxel":
			DrawingAlgos.rotxel(image, angle, pivot)
		"Nearest neighbour":
			DrawingAlgos.nn_rotate(image, angle, pivot)
		"Upscale, Rotate and Downscale":
			DrawingAlgos.fake_rotsprite(image, angle, pivot)

	if _project.has_selection and selection_checkbox.pressed and !_type_is_shader():
		cel.blend_rect(image, Rect2(Vector2.ZERO, image.get_size()), Vector2.ZERO)
	else:
		cel.blit_rect(image, Rect2(Vector2.ZERO, image.get_size()), Vector2.ZERO)


func _type_is_shader() -> bool:
	return (
		type_option_button.text == "Nearest neighbour (Shader)"
		or type_option_button.text == "Rotxel with Smear"
	)


func _on_TypeOptionButton_item_selected(_id: int) -> void:
	if type_option_button.text == "Rotxel with Smear":
		var sm := ShaderMaterial.new()
		sm.shader = rotxel_shader
		preview.set_material(sm)
		smear_options.visible = true
	elif type_option_button.text == "Nearest neighbour (Shader)":
		var sm := ShaderMaterial.new()
		sm.shader = nn_shader
		preview.set_material(sm)
		smear_options.visible = false
	else:
		preview.set_material(null)
		smear_options.visible = false
	update_preview()


func _on_AngleHSlider_value_changed(_value: float) -> void:
	angle_spinbox.value = angle_hslider.value
	if live_preview:
		update_preview()
	else:
		wait_apply_timer.start()


func _on_AngleSpinBox_value_changed(_value: float) -> void:
	angle_hslider.value = angle_spinbox.value


func _on_InitialAngleHSlider_value_changed(_value: float) -> void:
	init_angle_spinbox.value = init_angle_hslider.value
	if live_preview:
		update_preview()
	else:
		wait_apply_timer.start()


func _on_InitialAngleSpinBox_value_changed(_value: float) -> void:
	init_angle_hslider.value = init_angle_spinbox.value


func _on_ToleranceHSlider_value_changed(_value: float) -> void:
	tolerance_spinbox.value = tolerance_hslider.value
	if live_preview:
		update_preview()
	else:
		wait_apply_timer.start()


func _on_ToleranceSpinBox_value_changed(_value: float) -> void:
	tolerance_hslider.value = tolerance_spinbox.value


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


func _on_quick_change_angle_pressed(angle_value: int) -> void:
	var current_angle := angle_hslider.value
	var new_angle := current_angle + angle_value
	if angle_value == 0:
		new_angle = 0

	if new_angle < 0:
		new_angle = new_angle + 360
	elif new_angle >= 360:
		new_angle = new_angle - 360
	angle_hslider.value = new_angle


func _on_Centre_pressed() -> void:
	decide_pivot()


func _on_Pivot_value_changed(value: float, is_x: bool) -> void:
	if is_x:
		pivot.x = value
	else:
		pivot.y = value
	# Refresh the indicator
	pivot_indicator.update()
	if angle_hslider.value != 0:
		update_preview()


func _on_Indicator_draw() -> void:
	var img_size := preview_image.get_size()
	# find the scale using the larger measurement
	var ratio := pivot_indicator.rect_size / img_size
	# we need to set the scale according to the larger side
	var conversion_scale: float
	if img_size.x > img_size.y:
		conversion_scale = ratio.x
	else:
		conversion_scale = ratio.y
	var pivot_position := pivot * conversion_scale
	pivot_indicator.draw_arc(pivot_position, 2, 0, 360, 360, Color.yellow, 0.5)
	pivot_indicator.draw_arc(pivot_position, 6, 0, 360, 360, Color.white, 0.5)
	pivot_indicator.draw_line(
		pivot_position - Vector2.UP * 10, pivot_position - Vector2.DOWN * 10, Color.white, 0.5
	)
	pivot_indicator.draw_line(
		pivot_position - Vector2.RIGHT * 10, pivot_position - Vector2.LEFT * 10, Color.white, 0.5
	)


func _on_Indicator_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse"):
		drag_pivot = true
	if event.is_action_released("left_mouse"):
		drag_pivot = false
	if drag_pivot:
		var img_size := preview_image.get_size()
		var mouse_pos := get_local_mouse_position() - pivot_indicator.rect_position
		var ratio := img_size / pivot_indicator.rect_size
		# we need to set the scale according to the larger side
		var conversion_scale: float
		if img_size.x > img_size.y:
			conversion_scale = ratio.x
		else:
			conversion_scale = ratio.y
		var new_pos := mouse_pos * conversion_scale
		x_pivot.value = new_pos.x
		y_pivot.value = new_pos.y
		pivot_indicator.update()
