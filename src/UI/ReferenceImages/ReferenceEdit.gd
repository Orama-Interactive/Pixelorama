extends VBoxContainer

@export var references_panel: ReferencesPanel
var undo_data: Dictionary
var _prev_index: int = -1
var _ignore_spinbox_changes: bool = false

@onready var confirm_remove_dialog := $ConfirmRemoveDialog as ConfirmationDialog
@onready var timer := $Timer as Timer
@onready var references_container := Global.canvas.reference_image_container as Node2D


func _ready() -> void:
	references_container.reference_image_changed.connect(_on_reference_image_changed)


func _update_properties() -> void:
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	# This is because otherwise a little dance will occur.
	# This also breaks non-uniform scales (not supported UI-wise, but...)
	_ignore_spinbox_changes = true

	# Image Path
	if OS.get_name() == "Web":
		$ImageOptions/ImagePath.disabled = true
	else:
		$ImageOptions/ImagePath.disabled = false

	if ri.image_path.is_empty():
		$ImageOptions/ImagePath.text = "(No Path)"
		$ImageOptions/ImagePath.tooltip_text = "(No Path)"
	else:
		$ImageOptions/ImagePath.text = ri.image_path
		$ImageOptions/ImagePath.tooltip_text = ri.image_path

	if !ri.texture:
		$ImageOptions/WarningLabel.visible = true
		$ImageOptions/ImagePath.visible = false
	else:
		$ImageOptions/WarningLabel.visible = false
		$ImageOptions/ImagePath.visible = true
	# Transform
	$Options/Position/X.value = ri.position.x
	$Options/Position/Y.value = ri.position.y
	$Options/Position/X.max_value = ri.project.size.x
	$Options/Position/Y.max_value = ri.project.size.y
	$Options/Scale.value = ri.scale.x * 100
	$Options/Rotation.value = ri.rotation_degrees
	# Color
	$Options/Filter.button_pressed = ri.filter
	$Options/Monochrome.button_pressed = ri.monochrome
	$Options/Overlay.color = Color(ri.overlay_color, 1.0)
	$Options/Opacity.value = ri.overlay_color.a * 100
	$Options/ColorClamping.value = ri.color_clamping * 100
	_ignore_spinbox_changes = false

	# Fore update the "gizmo" drawing
	references_container.queue_redraw()


func _reset_properties() -> void:
	# This is because otherwise a little dance will occur.
	# This also breaks non-uniform scales (not supported UI-wise, but...)
	_ignore_spinbox_changes = true
	$ImageOptions/ImagePath.text = "None"
	$ImageOptions/ImagePath.tooltip_text = "None"
	$ImageOptions/ImagePath.disabled = true
	$ImageOptions/WarningLabel.visible = false
	$ImageOptions/ImagePath.visible = true
	# Transform
	$Options/Position/X.value = 0.0
	$Options/Position/Y.value = 0.0
	$Options/Position/X.max_value = 0.0
	$Options/Position/Y.max_value = 0.0
	$Options/Scale.value = 0.0
	$Options/Rotation.value = 0.0
	# Color
	$Options/Filter.button_pressed = false
	$Options/Monochrome.button_pressed = false
	$Options/Overlay.color = Color.WHITE
	$Options/Opacity.value = 0.0
	$Options/ColorClamping.value = 0.0
	_ignore_spinbox_changes = false
	# Fore update the "gizmo" drawing
	references_container.queue_redraw()


func _on_image_path_pressed() -> void:
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if ri.image_path.is_empty():
		print("No path for this image")
		return
	OS.shell_open(ri.image_path.get_base_dir())


func _on_Monochrome_toggled(pressed: bool) -> void:
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = references_container.get_undo_data()
	timer.start()
	ri.monochrome = pressed


func _on_Filter_toggled(pressed: bool) -> void:
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = references_container.get_undo_data()
	timer.start()
	ri.filter = pressed


func _on_Reset_pressed() -> void:
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	var undo_data_tmp = references_container.get_undo_data()
	ri.position_reset()
	references_container.commit_undo("Reset Reference Image Position", undo_data_tmp)


func _on_Remove_pressed() -> void:
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	var index: int = Global.current_project.reference_index
	if index > -1:
		# If shift is pressed we just remove it without a dialog
		if Input.is_action_pressed("shift"):
			references_container.remove_reference_image(index)
			references_panel._on_references_changed()
		else:
			var popup_position := Global.control.get_global_mouse_position()
			confirm_remove_dialog.popup_on_parent(Rect2i(popup_position, Vector2i.ONE))
			Global.dialog_open(true)


func _on_X_value_changed(value: float) -> void:
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = references_container.get_undo_data()
	timer.start()
	ri.position.x = value


func _on_Y_value_changed(value: float) -> void:
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = references_container.get_undo_data()
	timer.start()
	ri.position.y = value


func _on_Scale_value_changed(value: float) -> void:
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = references_container.get_undo_data()
	timer.start()
	ri.scale.x = value / 100
	ri.scale.y = value / 100


func _on_Rotation_value_changed(value: float) -> void:
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = references_container.get_undo_data()
	timer.start()
	ri.rotation_degrees = value


func _on_Overlay_color_changed(color: Color) -> void:
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = references_container.get_undo_data()
	timer.start()
	ri.overlay_color = Color(color, ri.overlay_color.a)


func _on_Opacity_value_changed(value: float) -> void:
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = references_container.get_undo_data()
	timer.start()
	ri.overlay_color.a = value / 100


func _on_ColorClamping_value_changed(value: float) -> void:
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = references_container.get_undo_data()
	timer.start()
	ri.color_clamping = value / 100


func _on_timer_timeout() -> void:
	references_container.commit_undo("Reference Image Changed", undo_data)


func _on_confirm_remove_dialog_confirmed() -> void:
	var index: int = Global.current_project.reference_index
	if index > -1:
		references_container.remove_reference_image(index)
		references_panel._on_references_changed()
		Global.dialog_open(false)


func _on_confirm_remove_dialog_canceled() -> void:
	Global.dialog_open(false)


func _on_reference_image_porperties_changed() -> void:
	_update_properties()


func _on_reference_image_changed(index: int) -> void:
	# This is a check to make sure that the index is not more than the amount of references
	if _prev_index > Global.current_project.reference_images.size() - 1:
		return
	# Disconnect the previously selected one
	if _prev_index > -1:
		var prev_ri: ReferenceImage = Global.current_project.get_reference_image(_prev_index)
		if prev_ri.properties_changed.is_connected(_on_reference_image_porperties_changed):
			prev_ri.properties_changed.disconnect(_on_reference_image_porperties_changed)
	# Connect the new Reference image (if it is one)
	if index > -1:
		Global.current_project.reference_images[index].properties_changed.connect(
			_on_reference_image_porperties_changed
		)

	_prev_index = index

	if index < 0:
		_reset_properties()
	else:
		_update_properties()
