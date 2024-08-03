extends PanelContainer

@onready var grid_container: GridContainer = find_child("GridContainer")
@onready var horizontal_mirror: BaseButton = grid_container.get_node("Horizontal")
@onready var vertical_mirror: BaseButton = grid_container.get_node("Vertical")
@onready var pixel_perfect: BaseButton = grid_container.get_node("PixelPerfect")
@onready var alpha_lock: BaseButton = grid_container.get_node("AlphaLock")
@onready var dynamics: Button = $"%Dynamics"
@onready var dynamics_panel: PopupPanel = $DynamicsPanel


func _ready() -> void:
	# Resize tools panel when window gets resized
	get_tree().get_root().size_changed.connect(_on_resized)
	horizontal_mirror.button_pressed = Tools.horizontal_mirror
	vertical_mirror.button_pressed = Tools.vertical_mirror
	pixel_perfect.button_pressed = Tools.pixel_perfect


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
	dynamics_panel.popup_on_parent(Rect2(pos, dynamics_panel.size))
