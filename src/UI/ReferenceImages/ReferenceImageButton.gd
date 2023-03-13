extends Container
# UI to handle reference image editing.

var element: ReferenceImage
var _ignore_spinbox_changes = false


func _ready():
	if OS.get_name() == "HTML5":
		$Interior/PathHeader/Path.visible = false
		$Interior/PathHeader/PathHTML.text = element.image_path
	else:
		$Interior/PathHeader/PathHTML.visible = false
		$Interior/PathHeader/Path.text = element.image_path

	if !element.texture:
		$Interior/PreviewAndOptions/PreviewPanel/Warning.text = "Image Not Found!!!"
	else:
		$Interior/PreviewAndOptions/PreviewPanel/Preview.texture = element.texture
	element.connect("properties_changed", self, "_update_properties")
	_update_properties()


func _update_properties():
	# This is because otherwise a little dance will occur.
	# This also breaks non-uniform scales (not supported UI-wise, but...)
	_ignore_spinbox_changes = true
	$Interior/PreviewAndOptions/Options/Scale.value = element.scale.x * 100
	$Interior/PreviewAndOptions/Options/Position/X.value = element.position.x
	$Interior/PreviewAndOptions/Options/Position/Y.value = element.position.y
	$Interior/PreviewAndOptions/Options/Position/X.max_value = element.project.size.x
	$Interior/PreviewAndOptions/Options/Position/Y.max_value = element.project.size.y
	$Interior/PreviewAndOptions/Options/Opacity.value = element.modulate.a * 100
	$Interior/OtherOptions/ApplyFilter.pressed = element.filter
	_ignore_spinbox_changes = false


func _on_Reset_pressed():
	element.position_reset()
	element.change_properties()


func _on_Remove_pressed():
	var index = Global.current_project.reference_images.find(element)
	if index != -1:
		queue_free()
		element.queue_free()
		Global.current_project.reference_images.remove(index)
		Global.current_project.change_project()


func _on_Scale_value_changed(value):
	if _ignore_spinbox_changes:
		return
	element.scale.x = value / 100
	element.scale.y = value / 100
	element.change_properties()


func _on_X_value_changed(value):
	if _ignore_spinbox_changes:
		return
	element.position.x = value
	element.change_properties()


func _on_Y_value_changed(value):
	if _ignore_spinbox_changes:
		return
	element.position.y = value
	element.change_properties()


func _on_Opacity_value_changed(value):
	if _ignore_spinbox_changes:
		return
	element.modulate.a = value / 100
	element.change_properties()


func _on_Path_pressed() -> void:
	OS.shell_open($Interior/PathHeader/Path.text.get_base_dir())


func _on_ApplyFilter_toggled(button_pressed: bool) -> void:
	element.filter = button_pressed
	if element.texture:
		if element.filter:
			element.texture.flags = Texture.FLAG_MIPMAPS | Texture.FLAG_FILTER
		else:
			element.texture.flags = Texture.FLAG_MIPMAPS
	element.change_properties()
