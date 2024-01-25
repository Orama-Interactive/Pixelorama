extends ImageEffect

enum { ROTXEL_SMEAR, CLEANEDGE, OMNISCALE, NNS, NN, ROTXEL, URD }
enum Animate { ANGLE, INITIAL_ANGLE }

var live_preview := true
var rotxel_shader := preload("res://src/Shaders/Effects/Rotation/SmearRotxel.gdshader")
var nn_shader := preload("res://src/Shaders/Effects/Rotation/NearestNeighbour.gdshader")
var pivot := Vector2.INF
var drag_pivot := false

@onready var type_option_button: OptionButton = $VBoxContainer/HBoxContainer2/TypeOptionButton
@onready var pivot_indicator: Control = $VBoxContainer/AspectRatioContainer/Indicator
@onready var pivot_sliders := $VBoxContainer/PivotOptions/Pivot as ValueSliderV2
@onready var angle_slider: ValueSlider = $VBoxContainer/AngleSlider
@onready var smear_options: Container = $VBoxContainer/SmearOptions
@onready var init_angle_slider: ValueSlider = smear_options.get_node("InitialAngleSlider")
@onready var tolerance_slider: ValueSlider = smear_options.get_node("ToleranceSlider")
@onready var wait_apply_timer: Timer = $WaitApply
@onready var wait_time_slider: ValueSlider = $VBoxContainer/WaitTime


func _ready() -> void:
	super._ready()
	# Set as in the Animate enum
	animate_panel.add_float_property("Angle", angle_slider)
	animate_panel.add_float_property("Initial Angle", init_angle_slider)
	type_option_button.add_item("Rotxel with Smear", ROTXEL_SMEAR)
	type_option_button.add_item("cleanEdge", CLEANEDGE)
	type_option_button.add_item("OmniScale", OMNISCALE)
	type_option_button.add_item("Nearest neighbour (Shader)", NNS)
	type_option_button.add_item("Nearest neighbour", NN)
	type_option_button.add_item("Rotxel", ROTXEL)
	type_option_button.add_item("Upscale, Rotate and Downscale", URD)
	type_option_button.item_selected.emit(0)


func _about_to_popup() -> void:
	if DrawingAlgos.clean_edge_shader == null:
		DrawingAlgos.clean_edge_shader = load(
			"res://src/Shaders/Effects/Rotation/cleanEdge.gdshader"
		)
	drag_pivot = false
	if pivot == Vector2.INF:
		_calculate_pivot()
	has_been_confirmed = false
	super._about_to_popup()
	wait_apply_timer.wait_time = wait_time_slider.value / 1000.0


func _calculate_pivot() -> void:
	var project_size := Global.current_project.size
	pivot = project_size / 2.0

	# Pivot correction in case of even size
	if (
		type_option_button.get_selected_id() != NNS
		and type_option_button.get_selected_id() != CLEANEDGE
		and type_option_button.get_selected_id() != OMNISCALE
	):
		if project_size.x % 2 == 0:
			pivot.x -= 0.5
		if project_size.y % 2 == 0:
			pivot.y -= 0.5

	if Global.current_project.has_selection and selection_checkbox.button_pressed:
		var selection_rectangle := Global.current_project.selection_map.get_used_rect()
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
			if (selection_rectangle.end.x - selection_rectangle.position.x) % 2 == 0:
				pivot.x -= 0.5
			if (selection_rectangle.end.y - selection_rectangle.position.y) % 2 == 0:
				pivot.y -= 0.5

	pivot_sliders.value = pivot
	_on_Pivot_value_changed(pivot)


func commit_action(cel: Image, _project := Global.current_project) -> void:
	var angle := deg_to_rad(animate_panel.get_animated_value(commit_idx, Animate.ANGLE))
	var init_angle := animate_panel.get_animated_value(commit_idx, Animate.INITIAL_ANGLE)

	var selection_tex: ImageTexture
	var image := Image.new()
	image.copy_from(cel)
	if _project.has_selection and selection_checkbox.button_pressed:
		var selection := _project.selection_map
		selection_tex = ImageTexture.create_from_image(selection)

		if !_type_is_shader():
			for x in _project.size.x:
				for y in _project.size.y:
					var pos := Vector2i(x, y)
					if !_project.can_pixel_get_drawn(pos):
						image.set_pixelv(pos, Color(0, 0, 0, 0))
					else:
						cel.set_pixelv(pos, Color(0, 0, 0, 0))
	if _type_is_shader():
		var shader := rotxel_shader
		var params := {
			"angle": angle, "selection_tex": selection_tex, "pivot_pixel": pivot, "preview": true
		}
		match type_option_button.get_selected_id():
			ROTXEL_SMEAR:
				params = {
					"initial_angle": init_angle,
					"ending_angle": rad_to_deg(angle),
					"tolerance": tolerance_slider.value,
					"selection_tex": selection_tex,
					"origin": pivot / Vector2(cel.get_size()),
				}
			CLEANEDGE:
				shader = DrawingAlgos.clean_edge_shader
			OMNISCALE:
				shader = DrawingAlgos.omniscale_shader
			NNS:
				shader = nn_shader
		if !has_been_confirmed:
			for param in params:
				preview.material.set_shader_parameter(param, params[param])
		else:
			params["preview"] = false
			var gen := ShaderImageEffect.new()
			gen.generate_image(cel, shader, params, _project.size)
	else:
		match type_option_button.get_selected_id():
			ROTXEL:
				DrawingAlgos.rotxel(image, angle, pivot)
			NN:
				DrawingAlgos.nn_rotate(image, angle, pivot)
			URD:
				DrawingAlgos.fake_rotsprite(image, angle, pivot)

		if _project.has_selection and selection_checkbox.button_pressed:
			cel.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		else:
			cel.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)


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
			sm.shader = DrawingAlgos.clean_edge_shader
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
		size.y += 1  # Reset size of dialog


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


func _on_Pivot_value_changed(value: Vector2) -> void:
	pivot = value
	# Refresh the indicator
	pivot_indicator.queue_redraw()
	if angle_slider.value != 0:
		update_preview()


func _on_Indicator_draw() -> void:
	var img_size := preview_image.get_size()
	# find the scale using the larger measurement
	var ratio := pivot_indicator.size / Vector2(img_size)
	# we need to set the scale according to the larger side
	var conversion_scale: float
	if img_size.x > img_size.y:
		conversion_scale = ratio.x
	else:
		conversion_scale = ratio.y
	var pivot_position := pivot * conversion_scale
	pivot_indicator.draw_arc(pivot_position, 2, 0, 360, 360, Color.YELLOW)
	pivot_indicator.draw_arc(pivot_position, 6, 0, 360, 360, Color.WHITE)
	pivot_indicator.draw_line(
		pivot_position - Vector2.UP * 10, pivot_position - Vector2.DOWN * 10, Color.WHITE
	)
	pivot_indicator.draw_line(
		pivot_position - Vector2.RIGHT * 10, pivot_position - Vector2.LEFT * 10, Color.WHITE
	)


func _on_Indicator_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse"):
		drag_pivot = true
	if event.is_action_released("left_mouse"):
		drag_pivot = false
	if drag_pivot:
		var img_size := preview_image.get_size()
		var mouse_pos := pivot_indicator.get_local_mouse_position()
		var ratio := Vector2(img_size) / pivot_indicator.size
		# we need to set the scale according to the larger side
		var conversion_scale: float
		if img_size.x > img_size.y:
			conversion_scale = ratio.x
		else:
			conversion_scale = ratio.y
		var new_pos := mouse_pos * conversion_scale
		pivot_sliders.value = new_pos
		_on_Pivot_value_changed(new_pos)
