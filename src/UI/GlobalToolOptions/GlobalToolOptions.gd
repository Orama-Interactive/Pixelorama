extends PanelContainer

signal dynamics_changed

enum { ALPHA, SIZE }

var alpha_last_pressed: BaseButton = null
var size_last_pressed: BaseButton = null

onready var grid_container: GridContainer = find_node("GridContainer")
onready var horizontal_mirror: BaseButton = grid_container.get_node("Horizontal")
onready var vertical_mirror: BaseButton = grid_container.get_node("Vertical")
onready var pixel_perfect: BaseButton = grid_container.get_node("PixelPerfect")
onready var dynamics: Button = $"%Dynamics"

onready var dynamics_panel: PopupPanel = $DynamicsPanel
onready var alpha_pressure_button: Button = $"%AlphaPressureButton"
onready var alpha_velocity_button: Button = $"%AlphaVelocityButton"
onready var size_pressure_button: Button = $"%SizePressureButton"
onready var size_velocity_button: Button = $"%SizeVelocityButton"
onready var pressure_preview: ProgressBar = $"%PressurePreview"
onready var velocity_preview: ProgressBar = $"%VelocityPreview"
onready var alpha_group: ButtonGroup = alpha_pressure_button.group
onready var size_group: ButtonGroup = size_pressure_button.group


func _ready() -> void:
	# Resize tools panel when window gets resized
	get_tree().get_root().connect("size_changed", self, "_on_resized")
	horizontal_mirror.pressed = Tools.horizontal_mirror
	vertical_mirror.pressed = Tools.vertical_mirror
	pixel_perfect.pressed = Tools.pixel_perfect

	alpha_pressure_button.connect(
		"toggled",
		self,
		"_on_Dynamics_toggled",
		[alpha_pressure_button, ALPHA, Tools.Dynamics.PRESSURE]
	)
	alpha_velocity_button.connect(
		"toggled",
		self,
		"_on_Dynamics_toggled",
		[alpha_velocity_button, ALPHA, Tools.Dynamics.VELOCITY]
	)
	size_pressure_button.connect(
		"toggled",
		self,
		"_on_Dynamics_toggled",
		[size_pressure_button, SIZE, Tools.Dynamics.PRESSURE]
	)
	size_velocity_button.connect(
		"toggled",
		self,
		"_on_Dynamics_toggled",
		[size_velocity_button, SIZE, Tools.Dynamics.VELOCITY]
	)


func _input(event: InputEvent) -> void:
	pressure_preview.value = 0
	velocity_preview.value = 0
	if event is InputEventMouseMotion:
		pressure_preview.value = event.pressure
		velocity_preview.value = event.speed.length() / Tools.mouse_velocity_max


func _on_resized() -> void:
	var tool_panel_size := rect_size
	var column_n := tool_panel_size.x / 36.5

	if column_n < 1:
		column_n = 1
	grid_container.columns = column_n


func _on_Horizontal_toggled(button_pressed: bool) -> void:
	Tools.horizontal_mirror = button_pressed
	Global.config_cache.set_value("preferences", "horizontal_mirror", button_pressed)
	Global.show_y_symmetry_axis = button_pressed
	Global.current_project.y_symmetry_axis.visible = (
		Global.show_y_symmetry_axis
		and Global.show_guides
	)

	var texture_button: TextureRect = horizontal_mirror.get_node("TextureRect")
	var file_name := "horizontal_mirror_on.png"
	if !button_pressed:
		file_name = "horizontal_mirror_off.png"
	Global.change_button_texturerect(texture_button, file_name)


func _on_Vertical_toggled(button_pressed: bool) -> void:
	Tools.vertical_mirror = button_pressed
	Global.config_cache.set_value("preferences", "vertical_mirror", button_pressed)
	Global.show_x_symmetry_axis = button_pressed
	# If the button is not pressed but another button is, keep the symmetry guide visible
	Global.current_project.x_symmetry_axis.visible = (
		Global.show_x_symmetry_axis
		and Global.show_guides
	)

	var texture_button: TextureRect = vertical_mirror.get_node("TextureRect")
	var file_name := "vertical_mirror_on.png"
	if !button_pressed:
		file_name = "vertical_mirror_off.png"
	Global.change_button_texturerect(texture_button, file_name)


func _on_PixelPerfect_toggled(button_pressed: bool) -> void:
	Tools.pixel_perfect = button_pressed
	Global.config_cache.set_value("preferences", "pixel_perfect", button_pressed)
	var texture_button: TextureRect = pixel_perfect.get_node("TextureRect")
	var file_name := "pixel_perfect_on.png"
	if !button_pressed:
		file_name = "pixel_perfect_off.png"
	Global.change_button_texturerect(texture_button, file_name)


func _on_Dynamics_pressed() -> void:
	var pos := dynamics.rect_global_position + Vector2(0, 32)
	dynamics_panel.popup(Rect2(pos, dynamics_panel.rect_size))


func _on_Dynamics_toggled(
	button_pressed: bool, button: BaseButton, property: int, dynamic: int
) -> void:
	if button_pressed:
		var last_pressed: BaseButton
		# The button calling this method is the one that was just selected
#		var pressed_button: BaseButton
		match property:
			ALPHA:
				last_pressed = alpha_last_pressed
#				pressed_button = alpha_group.get_pressed_button()
			SIZE:
				last_pressed = size_last_pressed
#				pressed_button = size_group.get_pressed_button()
		if last_pressed == button:
			# The button calling the method was the last one that was selected (we clicked it twice in a row)
			# Toggle it off and set last_pressed to null so we can click it a third time to toggle it back on
			button.pressed = false
			_set_last_pressed_button(property, null)
		# Update the last button pressed if we clicked something different
		else:
			_set_last_pressed_button(property, button)
	var final_dynamic := dynamic
	if not button.pressed:
		final_dynamic = Tools.Dynamics.NONE
	match property:
		ALPHA:
			Tools.dynamics_alpha = final_dynamic
		SIZE:
			Tools.dynamics_size = final_dynamic

	var texture_button: TextureRect = button.get_node("TextureRect")
	var file_name := "check.png"
	if !button.pressed:
		file_name = "uncheck.png"
	Global.change_button_texturerect(texture_button, file_name)
	emit_signal("dynamics_changed")


func _set_last_pressed_button(prop: int, value: BaseButton) -> void:
	match prop:
		ALPHA:
			alpha_last_pressed = value
		SIZE:
			size_last_pressed = value


func _on_ThresholdPressure_updated(value_1, value_2) -> void:
	Tools.pen_pressure_min = min(value_1, value_2)
	Tools.pen_pressure_max = max(value_1, value_2)


func _on_ThresholdVelocity_updated(value_1, value_2) -> void:
	Tools.mouse_velocity_min_thres = min(value_1, value_2)
	Tools.mouse_velocity_max_thres = max(value_1, value_2)


func _on_AlphaMin_value_changed(value: float) -> void:
	Tools.alpha_min = value
	emit_signal("dynamics_changed")


func _on_AlphaMax_value_changed(value: float) -> void:
	Tools.alpha_max = value
	emit_signal("dynamics_changed")


func _on_SizeMin_value_changed(value: float) -> void:
	Tools.brush_size_min = int(value)
	emit_signal("dynamics_changed")


func _on_SizeMax_value_changed(value: float) -> void:
	Tools.brush_size_max = int(value)
	emit_signal("dynamics_changed")
