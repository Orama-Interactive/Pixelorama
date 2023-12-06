extends PanelContainer

var _ignore_spinbox_changes : bool = false
var _current_index : int = -1

func _ready() -> void:
	get_parent().reference_image_clicked.connect(_on_reference_image_clicked)


func _update_properties():
	var element: ReferenceImage = _get_selected_element()
	if element == null:
		return
	# This is because otherwise a little dance will occur.
	# This also breaks non-uniform scales (not supported UI-wise, but...)
	_ignore_spinbox_changes = true
	# Tools
	$ReferenceEdit/ImagePath.text = element.image_path
	$ReferenceEdit/ImagePath.tooltip_text = element.image_path
	$ReferenceEdit/Tools/Monochrome.button_pressed = element.monochrome
	$ReferenceEdit/Tools/Filter.button_pressed = element.filter
	# Transform
	$ReferenceEdit/Options/Position/X.value = element.position.x
	$ReferenceEdit/Options/Position/Y.value = element.position.y
	$ReferenceEdit/Options/Position/X.max_value = element.project.size.x
	$ReferenceEdit/Options/Position/Y.max_value = element.project.size.y
	$ReferenceEdit/Options/Scale.value = element.scale.x * 100
	$ReferenceEdit/Options/Rotation.value = element.rotation_degrees
	
	# Color
	$ReferenceEdit/Options/Opacity.value = element.modulate.a * 100
	$ReferenceEdit/Options/Modulate.color = Color(element.modulate, 1.0)
	$ReferenceEdit/Options/ColorClamping.value = element.color_clamping * 100
	_ignore_spinbox_changes = false
	
	# Fore update the "gizmo" drawing
	Global.canvas.reference_images.update()

func _reset_properties() -> void:
	# This is because otherwise a little dance will occur.
	# This also breaks non-uniform scales (not supported UI-wise, but...)
	_ignore_spinbox_changes = true
	# Tools
	$ReferenceEdit/ImagePath.text = "None"
	$ReferenceEdit/ImagePath.tooltip_text = "None"
	$ReferenceEdit/Tools/Monochrome.button_pressed = false
	$ReferenceEdit/Tools/Filter.button_pressed = false
	# Transform
	$ReferenceEdit/Options/Position/X.value = 0.0
	$ReferenceEdit/Options/Position/Y.value = 0.0
	$ReferenceEdit/Options/Position/X.max_value = 0.0
	$ReferenceEdit/Options/Position/Y.max_value = 0.0
	$ReferenceEdit/Options/Scale.value = 0.0
	$ReferenceEdit/Options/Rotation.value = 0.0
	# Color
	$ReferenceEdit/Options/Opacity.value = 0.0
	$ReferenceEdit/Options/Modulate.color = Color.BLACK
	$ReferenceEdit/Options/ColorClamping.value = 0.0
	_ignore_spinbox_changes = false
	
	# Fore update the "gizmo" drawing
	Global.canvas.reference_images.update()

func _on_Monochrome_toggled(pressed: bool) -> void:
	var element: ReferenceImage = _get_selected_element()
	if element == null:
		return
	element.monochrome = pressed
	element.get_material().set_shader_parameter("monochrome", pressed)
	element.change_properties()

func _on_Filter_toggled(pressed: bool) -> void:
	var element: ReferenceImage = _get_selected_element()
	if element == null:
		return
	element.filter = pressed
	if element.texture:
		if element.filter:
			element.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		else:
			element.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	element.change_properties()

func _on_Reset_pressed():
	var element: ReferenceImage = _get_selected_element()
	if element == null:
		return
	element.position_reset()
	element.change_properties()
	_update_properties()


func _on_Remove_pressed():
	var element : ReferenceImage = _get_selected_element()
	if element == null:
		return
	var index : int = get_parent().list_btn_group.get_pressed_button().get_index() - 1
	if index > -1:
		get_parent().reference_image_clicked.emit(-1)
		element.queue_free()
		Global.current_project.reference_images.remove_at(index)
		Global.current_project.change_project()

func _on_X_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var element : ReferenceImage = _get_selected_element()
	if element == null:
		return
	element.position.x = value
	element.change_properties()


func _on_Y_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var element : ReferenceImage = _get_selected_element()
	if element == null:
		return
	element.position.y = value
	element.change_properties()

func _on_Scale_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var element : ReferenceImage = _get_selected_element()
	if element == null:
		return
	element.scale.x = value / 100
	element.scale.y = value / 100
	element.change_properties()

func _on_Rotation_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var element : ReferenceImage = _get_selected_element()
	if element == null:
		return
	element.rotation_degrees = value
	element.change_properties()

# TODO: Make a uniform in the shader to also allow it to modulate the monochrome
func _on_Modulate_color_changed(color: Color):
	if _ignore_spinbox_changes:
		return
	var element : ReferenceImage = _get_selected_element()
	if element == null:
		return
	element.modulate = Color(color, element.modulate.a)
	element.get_material().set_shader_parameter("monchrome_color", element.modulate)
	element.change_properties()

func _on_Opacity_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var element : ReferenceImage = _get_selected_element()
	if element == null:
		return
	element.modulate.a = value / 100
	element.change_properties()

func _on_ColorClamping_value_changed(value: float):
	if _ignore_spinbox_changes:
		return
	var element : ReferenceImage = _get_selected_element()
	if element == null:
		return
	element.color_clamping = value / 100
	element.get_material().set_shader_parameter("clamping", value / 100)
	element.change_properties()


## Gets the currently selected [ReferenceImage] based on what button is pressed
func _get_selected_element() -> ReferenceImage:
	if _current_index < 0:
		return null
	return Global.current_project.reference_images[_current_index]

func _on_reference_image_porperties_changed() -> void:
	_update_properties()


func _on_reference_image_clicked(index: int) -> void:
	# Disconnect the previously selected one
	if _current_index > -1:
		Global.current_project.reference_images[_current_index].properties_changed.disconnect(
			_on_reference_image_porperties_changed)
	_current_index = index
	# Connect the new Reference image (if it is one)
	if _current_index > -1:
		Global.current_project.reference_images[_current_index].properties_changed.connect(
			_on_reference_image_porperties_changed)
			
	if index < 0:
		_reset_properties()
	else:
		_update_properties()
	
	Global.canvas.reference_images.update_index(index)
