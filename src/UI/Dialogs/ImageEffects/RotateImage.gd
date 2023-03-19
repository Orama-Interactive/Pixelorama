extends ImageEffect

enum { ROTXEL_SMEAR, CLEANEDGE, OMNISCALE, NNS, NN, ROTXEL, URD }
enum Animate { ANGLE, INITIAL_ANGLE }

var live_preview: bool = true
var rotxel_shader: Shader
var nn_shader: Shader = preload("res://src/Shaders/Rotation/NearestNeighbour.shader")
var clean_edge_shader: Shader = DrawingAlgos.clean_edge_shader
var pivot := Vector2.INF
var drag_pivot := false

onready var type_option_button: OptionButton = $VBoxContainer/HBoxContainer2/TypeOptionButton
onready var pivot_indicator: Control = $VBoxContainer/AspectRatioContainer/Indicator
onready var x_pivot: ValueSlider = $VBoxContainer/PivotOptions/XPivot
onready var y_pivot: ValueSlider = $VBoxContainer/PivotOptions/YPivot
onready var angle_slider: ValueSlider = $VBoxContainer/AngleSlider
onready var smear_options: Container = $VBoxContainer/SmearOptions
onready var init_angle_slider: ValueSlider = smear_options.get_node("InitialAngleSlider")
onready var tolerance_slider: ValueSlider = smear_options.get_node("ToleranceSlider")
onready var wait_apply_timer: Timer = $WaitApply
onready var wait_time_slider: ValueSlider = $VBoxContainer/WaitTime


func _ready() -> void:
	if not _is_webgl1():
		type_option_button.add_item("Rotxel with Smear", ROTXEL_SMEAR)
		rotxel_shader = load("res://src/Shaders/Rotation/SmearRotxel.shader")
	type_option_button.add_item("cleanEdge", CLEANEDGE)
	type_option_button.add_item("OmniScale", OMNISCALE)
	type_option_button.set_item_disabled(OMNISCALE, not DrawingAlgos.omniscale_shader)
	type_option_button.add_item("Nearest neighbour (Shader)", NNS)
	type_option_button.add_item("Nearest neighbour", NN)
	type_option_button.add_item("Rotxel", ROTXEL)
	type_option_button.add_item("Upscale, Rotate and Downscale", URD)
	type_option_button.emit_signal("item_selected", 0)


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton
	animate_options_container = $VBoxContainer/AnimationOptions
	animate_menu = $"%AnimateMenu".get_popup()
	initial_button = $"%InitalButton"


func set_animate_menu(_elements) -> void:
	# set as in enum
	animate_menu.add_check_item("Angle", Animate.ANGLE)
	animate_menu.add_check_item("Initial Angle", Animate.INITIAL_ANGLE)
	.set_animate_menu(Animate.size())


func set_initial_values() -> void:
	initial_values[Animate.ANGLE] = deg2rad(angle_slider.value)
	initial_values[Animate.INITIAL_ANGLE] = init_angle_slider.value


func _about_to_show() -> void:
	drag_pivot = false
	if pivot == Vector2.INF:
		_calculate_pivot()
	confirmed = false
	._about_to_show()
	wait_apply_timer.wait_time = wait_time_slider.value / 1000.0


func _calculate_pivot() -> void:
	var size := Global.current_project.size
	pivot = size / 2

	# Pivot correction in case of even size
	if (
		type_option_button.get_selected_id() != NNS
		and type_option_button.get_selected_id() != CLEANEDGE
		and type_option_button.get_selected_id() != OMNISCALE
	):
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
		if (
			type_option_button.get_selected_id() != NNS
			and type_option_button.get_selected_id() != CLEANEDGE
			and type_option_button.get_selected_id() != OMNISCALE
		):
			# Pivot correction in case of even size
			if int(selection_rectangle.end.x - selection_rectangle.position.x) % 2 == 0:
				pivot.x -= 0.5
			if int(selection_rectangle.end.y - selection_rectangle.position.y) % 2 == 0:
				pivot.y -= 0.5

	x_pivot.value = pivot.x
	y_pivot.value = pivot.y


func commit_action(cel: Image, _project: Project = Global.current_project) -> void:
	.commit_action(cel, _project)
	var angle: float = get_animated_value(_project, deg2rad(angle_slider.value), Animate.ANGLE)
	var init_angle: float = get_animated_value(
		_project, init_angle_slider.value, Animate.INITIAL_ANGLE
	)

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
	match type_option_button.get_selected_id():
		ROTXEL_SMEAR:
			var params := {
				"initial_angle": init_angle,
				"ending_angle": rad2deg(angle),
				"tolerance": tolerance_slider.value,
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

		CLEANEDGE:
			var params := {
				"angle": angle,
				"selection_tex": selection_tex,
				"selection_pivot": pivot,
				"selection_size": selection_size,
				"slope": true,
				"cleanup": false,
				"preview": true
			}
			if !confirmed:
				for param in params:
					preview.material.set_shader_param(param, params[param])
			else:
				params["preview"] = false
				var gen := ShaderImageEffect.new()
				gen.generate_image(cel, clean_edge_shader, params, _project.size)
				yield(gen, "done")
		OMNISCALE:
			var params := {
				"angle": angle,
				"selection_tex": selection_tex,
				"selection_pivot": pivot,
				"selection_size": selection_size,
				"preview": true
			}
			if !confirmed:
				for param in params:
					preview.material.set_shader_param(param, params[param])
			else:
				params["preview"] = false
				var gen := ShaderImageEffect.new()
				gen.generate_image(cel, DrawingAlgos.omniscale_shader, params, _project.size)
				yield(gen, "done")
		NNS:
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
		ROTXEL:
			DrawingAlgos.rotxel(image, angle, pivot)
		NN:
			DrawingAlgos.nn_rotate(image, angle, pivot)
		URD:
			DrawingAlgos.fake_rotsprite(image, angle, pivot)

	if _project.has_selection and selection_checkbox.pressed and !_type_is_shader():
		cel.blend_rect(image, Rect2(Vector2.ZERO, image.get_size()), Vector2.ZERO)
	else:
		cel.blit_rect(image, Rect2(Vector2.ZERO, image.get_size()), Vector2.ZERO)


func _type_is_shader() -> bool:
	return type_option_button.get_selected_id() <= NNS


func _on_TypeOptionButton_item_selected(_id: int) -> void:
	match type_option_button.get_selected_id():
		ROTXEL_SMEAR:
			var sm := ShaderMaterial.new()
			sm.shader = rotxel_shader
			preview.set_material(sm)
			smear_options.visible = true
		CLEANEDGE:
			var sm := ShaderMaterial.new()
			sm.shader = clean_edge_shader
			preview.set_material(sm)
			smear_options.visible = false
		OMNISCALE:
			var sm := ShaderMaterial.new()
			sm.shader = DrawingAlgos.omniscale_shader
			preview.set_material(sm)
			smear_options.visible = false
		NNS:
			var sm := ShaderMaterial.new()
			sm.shader = nn_shader
			preview.set_material(sm)
			smear_options.visible = false
		_:
			preview.set_material(null)
			smear_options.visible = false
	update_preview()


func _on_AngleSlider_value_changed(_value: float) -> void:
	if live_preview:
		update_preview()
	else:
		wait_apply_timer.start()


func _on_InitialAngleSlider_value_changed(_value: float) -> void:
	if live_preview:
		update_preview()
	else:
		wait_apply_timer.start()


func _on_ToleranceSlider_value_changed(_value: float) -> void:
	if live_preview:
		update_preview()
	else:
		wait_apply_timer.start()


func _on_WaitApply_timeout() -> void:
	update_preview()


func _on_WaitTime_value_changed(value: float) -> void:
	wait_apply_timer.wait_time = value / 1000.0


func _on_LiveCheckbox_toggled(button_pressed: bool) -> void:
	live_preview = button_pressed
	wait_time_slider.editable = !live_preview
	wait_time_slider.visible = !live_preview
	if !button_pressed:
		rect_size.y += 1  # Reset rect_size of dialog


func _on_quick_change_angle_pressed(angle_value: int) -> void:
	var current_angle := angle_slider.value
	var new_angle := current_angle + angle_value
	if angle_value == 0:
		new_angle = 0

	if new_angle < 0:
		new_angle = new_angle + 360
	elif new_angle >= 360:
		new_angle = new_angle - 360
	angle_slider.value = new_angle


func _on_Centre_pressed() -> void:
	_calculate_pivot()


func _on_Pivot_value_changed(value: float, is_x: bool) -> void:
	if is_x:
		pivot.x = value
	else:
		pivot.y = value
	# Refresh the indicator
	pivot_indicator.update()
	if angle_slider.value != 0:
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
