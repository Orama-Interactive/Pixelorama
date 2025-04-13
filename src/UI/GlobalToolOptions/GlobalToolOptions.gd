extends PanelContainer

@onready var grid_container: GridContainer = find_child("GridContainer")
@onready var horizontal_mirror: BaseButton = grid_container.get_node("Horizontal")
@onready var vertical_mirror: BaseButton = grid_container.get_node("Vertical")
@onready var diagonal_xy_mirror: BaseButton = grid_container.get_node("DiagonalXY")
@onready var diagonal_x_minus_y_mirror: BaseButton = grid_container.get_node("DiagonalXMinusY")
@onready var pixel_perfect: BaseButton = grid_container.get_node("PixelPerfect")
@onready var alpha_lock: BaseButton = grid_container.get_node("AlphaLock")
@onready var dynamics: Button = $"%Dynamics"
@onready var dynamics_panel: PopupPanel = $DynamicsPanel


func _ready() -> void:
	Tools.options_reset.connect(reset_options)
	%HorizontalMirrorOptions.get_popup().id_pressed.connect(
		_on_horizontal_mirror_options_id_pressed
	)
	%VerticalMirrorOptions.get_popup().id_pressed.connect(_on_vertical_mirror_options_id_pressed)
	# Resize tools panel when window gets resized
	get_tree().get_root().size_changed.connect(_on_resized)
	horizontal_mirror.button_pressed = Tools.horizontal_mirror
	vertical_mirror.button_pressed = Tools.vertical_mirror
	pixel_perfect.button_pressed = Tools.pixel_perfect
	alpha_lock.button_pressed = Tools.alpha_locked


func reset_options() -> void:
	horizontal_mirror.button_pressed = false
	vertical_mirror.button_pressed = false
	pixel_perfect.button_pressed = false
	alpha_lock.button_pressed = false


func _on_resized() -> void:
	var tool_panel_size := size
	var column_n := tool_panel_size.x / 36.5

	if column_n < 1:
		column_n = 1
	grid_container.columns = column_n


func _on_Horizontal_toggled(toggled_on: bool) -> void:
	Tools.horizontal_mirror = toggled_on
	Global.config_cache.set_value("tools", "horizontal_mirror", toggled_on)
	Global.show_y_symmetry_axis = toggled_on
	Global.current_project.y_symmetry_axis.visible = (
		Global.show_y_symmetry_axis and Global.show_guides
	)

	var texture_button: TextureRect = horizontal_mirror.get_node("TextureRect")
	var file_name := "horizontal_mirror_on.png"
	if not toggled_on:
		file_name = "horizontal_mirror_off.png"
	Global.change_button_texturerect(texture_button, file_name)


func _on_Vertical_toggled(toggled_on: bool) -> void:
	Tools.vertical_mirror = toggled_on
	Global.config_cache.set_value("tools", "vertical_mirror", toggled_on)
	Global.show_x_symmetry_axis = toggled_on
	# If the button is not pressed but another button is, keep the symmetry guide visible
	Global.current_project.x_symmetry_axis.visible = (
		Global.show_x_symmetry_axis and Global.show_guides
	)

	var texture_button: TextureRect = vertical_mirror.get_node("TextureRect")
	var file_name := "vertical_mirror_on.png"
	if not toggled_on:
		file_name = "vertical_mirror_off.png"
	Global.change_button_texturerect(texture_button, file_name)


func _on_diagonal_xy_toggled(toggled_on: bool) -> void:
	Tools.diagonal_xy_mirror = toggled_on
	Global.config_cache.set_value("tools", "diagonal_xy_mirror", toggled_on)
	Global.show_xy_symmetry_axis = toggled_on
	# If the button is not pressed but another button is, keep the symmetry guide visible
	Global.current_project.diagonal_xy_symmetry_axis.visible = (
		Global.show_xy_symmetry_axis and Global.show_guides
	)

	var texture_button: TextureRect = diagonal_xy_mirror.get_node("TextureRect")
	var file_name := "xy_mirror_on.png"
	if not toggled_on:
		file_name = "xy_mirror_off.png"
	Global.change_button_texturerect(texture_button, file_name)


func _on_diagonal_x_minus_y_toggled(toggled_on: bool) -> void:
	Tools.diagonal_x_minus_y_mirror = toggled_on
	Global.config_cache.set_value("tools", "diagonal_x_minus_y_mirror", toggled_on)
	Global.show_x_minus_y_symmetry_axis = toggled_on
	# If the button is not pressed but another button is, keep the symmetry guide visible
	Global.current_project.diagonal_x_minus_y_symmetry_axis.visible = (
		Global.show_x_minus_y_symmetry_axis and Global.show_guides
	)

	var texture_button: TextureRect = diagonal_x_minus_y_mirror.get_node("TextureRect")
	var file_name := "x_minus_y_mirror_on.png"
	if not toggled_on:
		file_name = "x_minus_y_mirror_off.png"
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
	dynamics_panel.popup_on_parent(Rect2(pos, dynamics_panel.size))


func _on_horizontal_mirror_options_id_pressed(id: int) -> void:
	var project := Global.current_project
	if id == 0:
		project.x_symmetry_point = project.size.x - 1
	elif id == 1:
		project.x_symmetry_point = Global.camera.camera_screen_center.x * 2
	project.y_symmetry_axis.points[0].x = project.x_symmetry_point / 2 + 0.5
	project.y_symmetry_axis.points[1].x = project.x_symmetry_point / 2 + 0.5


func _on_vertical_mirror_options_id_pressed(id: int) -> void:
	var project := Global.current_project
	if id == 0:
		project.y_symmetry_point = project.size.y - 1
	elif id == 1:
		project.y_symmetry_point = Global.camera.camera_screen_center.y * 2
	project.x_symmetry_axis.points[0].y = project.y_symmetry_point / 2 + 0.5
	project.x_symmetry_axis.points[1].y = project.y_symmetry_point / 2 + 0.5
