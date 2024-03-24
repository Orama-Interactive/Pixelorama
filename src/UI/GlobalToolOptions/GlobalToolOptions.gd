extends PanelContainer

signal dynamics_changed

enum { ALPHA, SIZE }

@onready var grid_container: GridContainer = find_child("GridContainer")
@onready var horizontal_mirror: BaseButton = grid_container.get_node("Horizontal")
@onready var vertical_mirror: BaseButton = grid_container.get_node("Vertical")
@onready var pixel_perfect: BaseButton = grid_container.get_node("PixelPerfect")
@onready var alpha_lock: BaseButton = grid_container.get_node("AlphaLock")
@onready var dynamics: Button = $"%Dynamics"

@onready var dynamics_panel: PopupPanel = $DynamicsPanel
@onready var alpha_pressure_button: Button = $"%AlphaPressureButton"
@onready var alpha_velocity_button: Button = $"%AlphaVelocityButton"
@onready var size_pressure_button: Button = $"%SizePressureButton"
@onready var size_velocity_button: Button = $"%SizeVelocityButton"
@onready var pressure_preview: ProgressBar = $"%PressurePreview"
@onready var velocity_preview: ProgressBar = $"%VelocityPreview"
@onready var limits_header: HBoxContainer = %LimitsHeader
@onready var thresholds_header: HBoxContainer = %ThresholdsHeader
@onready var alpha_group := alpha_pressure_button.button_group
@onready var size_group := size_pressure_button.button_group


func _ready() -> void:
	# Resize tools panel when window gets resized
	get_tree().get_root().size_changed.connect(_on_resized)
	horizontal_mirror.button_pressed = Tools.horizontal_mirror
	vertical_mirror.button_pressed = Tools.vertical_mirror
	pixel_perfect.button_pressed = Tools.pixel_perfect

	alpha_pressure_button.toggled.connect(
		_on_Dynamics_toggled.bind(alpha_pressure_button, ALPHA, Tools.Dynamics.PRESSURE)
	)
	alpha_velocity_button.toggled.connect(
		_on_Dynamics_toggled.bind(alpha_velocity_button, ALPHA, Tools.Dynamics.VELOCITY)
	)
	size_pressure_button.toggled.connect(
		_on_Dynamics_toggled.bind(size_pressure_button, SIZE, Tools.Dynamics.PRESSURE)
	)
	size_velocity_button.toggled.connect(
		_on_Dynamics_toggled.bind(size_velocity_button, SIZE, Tools.Dynamics.VELOCITY)
	)


func _input(event: InputEvent) -> void:
	pressure_preview.value = 0
	velocity_preview.value = 0
	if event is InputEventMouseMotion:
		pressure_preview.value = event.pressure
		velocity_preview.value = event.velocity.length() / Tools.mouse_velocity_max


func _on_resized() -> void:
	var tool_panel_size := size
	var column_n := tool_panel_size.x / 36.5

	if column_n < 1:
		column_n = 1
	grid_container.columns = column_n


func _on_Horizontal_toggled(button_pressed: bool) -> void:
	Tools.horizontal_mirror = button_pressed
	Global.config_cache.set_value("tools", "horizontal_mirror", button_pressed)
	Global.show_y_symmetry_axis = button_pressed
	Global.current_project.y_symmetry_axis.visible = (
		Global.show_y_symmetry_axis and Global.show_guides
	)

	var texture_button: TextureRect = horizontal_mirror.get_node("TextureRect")
	var file_name := "horizontal_mirror_on.png"
	if !button_pressed:
		file_name = "horizontal_mirror_off.png"
	Global.change_button_texturerect(texture_button, file_name)


func _on_Vertical_toggled(button_pressed: bool) -> void:
	Tools.vertical_mirror = button_pressed
	Global.config_cache.set_value("tools", "vertical_mirror", button_pressed)
	Global.show_x_symmetry_axis = button_pressed
	# If the button is not pressed but another button is, keep the symmetry guide visible
	Global.current_project.x_symmetry_axis.visible = (
		Global.show_x_symmetry_axis and Global.show_guides
	)

	var texture_button: TextureRect = vertical_mirror.get_node("TextureRect")
	var file_name := "vertical_mirror_on.png"
	if !button_pressed:
		file_name = "vertical_mirror_off.png"
	Global.change_button_texturerect(texture_button, file_name)


func _on_PixelPerfect_toggled(button_pressed: bool) -> void:
	Tools.pixel_perfect = button_pressed
	Global.config_cache.set_value("tools", "pixel_perfect", button_pressed)
	var texture_button: TextureRect = pixel_perfect.get_node("TextureRect")
	var file_name := "pixel_perfect_on.png"
	if !button_pressed:
		file_name = "pixel_perfect_off.png"
	Global.change_button_texturerect(texture_button, file_name)


func _on_alpha_lock_toggled(toggled_on: bool) -> void:
	Tools.alpha_locked = toggled_on
	Global.config_cache.set_value("tools", "alpha_locked", toggled_on)
	var texture_button: TextureRect = alpha_lock.get_node("TextureRect")
	var file_name := "alpha_lock_on.png"
	if not toggled_on:
		file_name = "alpha_lock_off.png"
	Global.change_button_texturerect(texture_button, file_name)


func _on_Dynamics_pressed() -> void:
	var pos := dynamics.global_position + Vector2(0, 32)
	dynamics_panel.popup(Rect2(pos, dynamics_panel.size))


func _on_Dynamics_toggled(
	button_pressed: bool, button: BaseButton, property: int, dynamic: Tools.Dynamics
) -> void:
	var final_dynamic := dynamic
	if not button.button_pressed:
		final_dynamic = Tools.Dynamics.NONE
	match property:
		ALPHA:
			Tools.dynamics_alpha = final_dynamic
		SIZE:
			Tools.dynamics_size = final_dynamic
	var has_alpha_dynamic := Tools.dynamics_alpha != Tools.Dynamics.NONE
	var has_size_dynamic := Tools.dynamics_size != Tools.Dynamics.NONE
	var has_pressure_dynamic := (
		Tools.dynamics_alpha == Tools.Dynamics.PRESSURE
		or Tools.dynamics_size == Tools.Dynamics.PRESSURE
	)
	var has_velocity_dynamic := (
		Tools.dynamics_alpha == Tools.Dynamics.VELOCITY
		or Tools.dynamics_size == Tools.Dynamics.VELOCITY
	)
	limits_header.visible = has_alpha_dynamic or has_size_dynamic
	thresholds_header.visible = limits_header.visible
	get_tree().set_group(&"VisibleOnAlpha", "visible", has_alpha_dynamic)
	get_tree().set_group(&"VisibleOnSize", "visible", has_size_dynamic)
	get_tree().set_group(&"VisibleOnPressure", "visible", has_pressure_dynamic)
	get_tree().set_group(&"VisibleOnVelocity", "visible", has_velocity_dynamic)
	var texture_button: TextureRect = button.get_node("TextureRect")
	var file_name := "check.png"
	if !button.button_pressed:
		file_name = "uncheck.png"
	Global.change_button_texturerect(texture_button, file_name)
	dynamics_changed.emit()


func _on_ThresholdPressure_updated(value_1: float, value_2: float) -> void:
	Tools.pen_pressure_min = minf(value_1, value_2)
	Tools.pen_pressure_max = maxf(value_1, value_2)


func _on_ThresholdVelocity_updated(value_1: float, value_2: float) -> void:
	Tools.mouse_velocity_min_thres = minf(value_1, value_2)
	Tools.mouse_velocity_max_thres = maxf(value_1, value_2)


func _on_AlphaMin_value_changed(value: float) -> void:
	Tools.alpha_min = value
	dynamics_changed.emit()


func _on_AlphaMax_value_changed(value: float) -> void:
	Tools.alpha_max = value
	dynamics_changed.emit()


func _on_SizeMin_value_changed(value: float) -> void:
	Tools.brush_size_min = int(value)
	dynamics_changed.emit()


func _on_SizeMax_value_changed(value: float) -> void:
	Tools.brush_size_max = int(value)
	dynamics_changed.emit()


func _on_enable_stabilizer_toggled(toggled_on: bool) -> void:
	Tools.stabilizer_enabled = toggled_on


func _on_stabilizer_value_value_changed(value: float) -> void:
	Tools.stabilizer_value = value
