extends Container
# UI to handle reference image editing.

var element: ReferenceImage
var _ignore_spinbox_changes = false


func _ready():
	$Interior/Path.text = element.image_path
	element.connect("properties_changed", self, "_update_properties")
	_update_properties()


func _update_properties():
	# This is because otherwise a little dance will occur.
	# This also breaks non-uniform scales (not supported UI-wise, but...)
	_ignore_spinbox_changes = true
	$Interior/Options/Scale.value = element.scale.x * 100
	$Interior/Options/X.value = element.position.x
	$Interior/Options/Y.value = element.position.y
	$Interior/Options/X.max_value = element.project.size.x
	$Interior/Options/Y.max_value = element.project.size.y
	$Interior/Options2/Opacity.value = element.modulate.a * 100
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
