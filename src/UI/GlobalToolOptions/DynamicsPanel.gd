extends PopupPanel

signal dynamics_changed

enum { ALPHA, SIZE }

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
	alpha_pressure_button.toggled.connect(
		_on_dynamics_toggled.bind(alpha_pressure_button, ALPHA, Tools.Dynamics.PRESSURE)
	)
	alpha_velocity_button.toggled.connect(
		_on_dynamics_toggled.bind(alpha_velocity_button, ALPHA, Tools.Dynamics.VELOCITY)
	)
	size_pressure_button.toggled.connect(
		_on_dynamics_toggled.bind(size_pressure_button, SIZE, Tools.Dynamics.PRESSURE)
	)
	size_velocity_button.toggled.connect(
		_on_dynamics_toggled.bind(size_velocity_button, SIZE, Tools.Dynamics.VELOCITY)
	)
	for child: Control in $VBoxContainer.get_children():
		## Resets the y-size to an appropriate value
		child.visibility_changed.connect(_recalculate_size)


func _recalculate_size():
	await get_tree().process_frame
	set_size(Vector2i(size.x, 0))
	set_size(Vector2i(size.x, size.y + 10))


func _input(event: InputEvent) -> void:
	pressure_preview.value = 0
	velocity_preview.value = 0
	if event is InputEventMouseMotion:
		pressure_preview.value = event.pressure
		velocity_preview.value = event.velocity.length() / Tools.mouse_velocity_max


func _on_dynamics_toggled(
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


func _on_threshold_pressure_updated(value_1: float, value_2: float) -> void:
	Tools.pen_pressure_min = minf(value_1, value_2)
	Tools.pen_pressure_max = maxf(value_1, value_2)


func _on_threshold_velocity_updated(value_1: float, value_2: float) -> void:
	Tools.mouse_velocity_min_thres = minf(value_1, value_2)
	Tools.mouse_velocity_max_thres = maxf(value_1, value_2)


func _on_alpha_min_value_changed(value: float) -> void:
	Tools.alpha_min = value
	dynamics_changed.emit()


func _on_alpha_max_value_changed(value: float) -> void:
	Tools.alpha_max = value
	dynamics_changed.emit()


func _on_size_min_value_changed(value: float) -> void:
	Tools.brush_size_min = int(value)
	dynamics_changed.emit()


func _on_size_max_value_changed(value: float) -> void:
	Tools.brush_size_max = int(value)
	dynamics_changed.emit()


func _on_enable_stabilizer_toggled(toggled_on: bool) -> void:
	Tools.stabilizer_enabled = toggled_on


func _on_stabilizer_value_value_changed(value: float) -> void:
	Tools.stabilizer_value = value
