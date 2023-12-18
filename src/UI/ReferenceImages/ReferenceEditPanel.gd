extends PanelContainer

var _ignore_spinbox_changes: bool = false
var _prev_index: int = -1

@onready var confirm_remove_dialog := $ConfirmRemoveDialog as ConfirmationDialog

var reference_image_container: Node2D:
	get:
		return Global.canvas.reference_image_container
var undo_data: Dictionary

@onready var timer := $Timer as Timer


func _ready() -> void:
	Global.canvas.reference_image_container.reference_image_changed.connect(
		_on_reference_image_changed
	)


func _update_properties():
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	# This is because otherwise a little dance will occur.
	# This also breaks non-uniform scales (not supported UI-wise, but...)
	_ignore_spinbox_changes = true

	# Image Path
	if OS.get_name() == "Web":
		$ReferenceEdit/ImageOptions/ImagePath.disabled = true
	else:
		$ReferenceEdit/ImageOptions/ImagePath.disabled = false

	$ReferenceEdit/ImageOptions/ImagePath.text = ri.image_path
	$ReferenceEdit/ImageOptions/ImagePath.tooltip_text = ri.image_path

	if !ri.texture:
		$ReferenceEdit/ImageOptions/WarningLabel.visible = true
		$ReferenceEdit/ImageOptions/ImagePath.visible = false
	else:
		$ReferenceEdit/ImageOptions/WarningLabel.visible = false
		$ReferenceEdit/ImageOptions/ImagePath.visible = true
	# Tools
	$ReferenceEdit/Tools/Filter.button_pressed = ri.filter
	# Transform
	$ReferenceEdit/Options/Position/X.value = ri.position.x
	$ReferenceEdit/Options/Position/Y.value = ri.position.y
	$ReferenceEdit/Options/Position/X.max_value = ri.project.size.x
	$ReferenceEdit/Options/Position/Y.max_value = ri.project.size.y
	$ReferenceEdit/Options/Scale.value = ri.scale.x * 100
	$ReferenceEdit/Options/Rotation.value = ri.rotation_degrees

	# Color
	$ReferenceEdit/Options/Monochrome.button_pressed = ri.monochrome
	$ReferenceEdit/Options/Overlay.color = Color(ri.overlay_color, 1.0)
	$ReferenceEdit/Options/Opacity.value = ri.overlay_color.a * 100
	$ReferenceEdit/Options/ColorClamping.value = ri.color_clamping * 100
	_ignore_spinbox_changes = false

	# Fore update the "gizmo" drawing
	Global.canvas.reference_image_container.queue_redraw()


func _reset_properties() -> void:
	# This is because otherwise a little dance will occur.
	# This also breaks non-uniform scales (not supported UI-wise, but...)
	_ignore_spinbox_changes = true
	$ReferenceEdit/ImageOptions/ImagePath.text = "None"
	$ReferenceEdit/ImageOptions/ImagePath.tooltip_text = "None"
	$ReferenceEdit/ImageOptions/ImagePath.disabled = true
	$ReferenceEdit/ImageOptions/WarningLabel.visible = false
	$ReferenceEdit/ImageOptions/ImagePath.visible = true
	# Tools
	$ReferenceEdit/Tools/Filter.button_pressed = false
	# Transform
	$ReferenceEdit/Options/Position/X.value = 0.0
	$ReferenceEdit/Options/Position/Y.value = 0.0
	$ReferenceEdit/Options/Position/X.max_value = 0.0
	$ReferenceEdit/Options/Position/Y.max_value = 0.0
	$ReferenceEdit/Options/Scale.value = 0.0
	$ReferenceEdit/Options/Rotation.value = 0.0
	# Color
	$ReferenceEdit/Options/Monochrome.button_pressed = false
	$ReferenceEdit/Options/Overlay.color = Color.WHITE
	$ReferenceEdit/Options/Opacity.value = 0.0
	$ReferenceEdit/Options/ColorClamping.value = 0.0
	_ignore_spinbox_changes = false
	# Fore update the "gizmo" drawing
	Global.canvas.reference_image_container.queue_redraw()


func _on_Monochrome_toggled(pressed: bool) -> void:
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = reference_image_container.get_undo_data()
	timer.start()
	ri.monochrome = pressed


func _on_Filter_toggled(pressed: bool) -> void:
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = reference_image_container.get_undo_data()
	timer.start()
	ri.filter = pressed


func _on_Reset_pressed():
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	var undo_data_tmp = reference_image_container.get_undo_data()
	ri.position_reset()
	reference_image_container.commit_undo("Reset Reference Image Position", undo_data_tmp)


func _on_Remove_pressed():
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	var index: int = get_parent().list_btn_group.get_pressed_button().get_index() - 1
	if index > -1:
		# If shift is pressed we just remove it without a dialog
		if Input.is_action_pressed("shift"):
			reference_image_container.remove_reference_image(index)
		else:
			confirm_remove_dialog.position = Global.control.get_global_mouse_position()
			confirm_remove_dialog.popup()
			Global.dialog_open(true)


func _on_X_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = reference_image_container.get_undo_data()
	timer.start()
	ri.position.x = value


func _on_Y_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = reference_image_container.get_undo_data()
	timer.start()
	ri.position.y = value


func _on_Scale_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = reference_image_container.get_undo_data()
	timer.start()
	ri.scale.x = value / 100
	ri.scale.y = value / 100


func _on_Rotation_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = reference_image_container.get_undo_data()
	timer.start()
	ri.rotation_degrees = value


func _on_Overlay_color_changed(color: Color):
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = reference_image_container.get_undo_data()
	timer.start()
	ri.overlay_color = Color(color, ri.overlay_color.a)


func _on_Opacity_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = reference_image_container.get_undo_data()
	timer.start()
	ri.overlay_color.a = value / 100


func _on_ColorClamping_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		return
	if timer.is_stopped():
		undo_data = reference_image_container.get_undo_data()
	timer.start()
	ri.color_clamping = value / 100


func _on_timer_timeout() -> void:
	reference_image_container.commit_undo("Reference Image Changed", undo_data)


func _on_remove_confirm_dialog_confirmed() -> void:
	var index: int = get_parent().list_btn_group.get_pressed_button().get_index() - 1
	if index > -1:
		reference_image_container.remove_reference_image(index)
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
