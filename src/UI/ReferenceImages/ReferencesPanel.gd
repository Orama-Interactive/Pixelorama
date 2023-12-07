class_name ReferencesPanel
extends VBoxContainer
## Panel for reference image management

var reference_image_button_tscn := preload("res://src/UI/ReferenceImages/ReferenceImageButton.tscn")
@onready var list = $"Scroll/List"


func _ready() -> void:
	Global.project_changed.connect(_update_reference_images)
	OpenSave.reference_image_imported.connect(_update_reference_images)


func _update_reference_images():
	for c in list.get_children():
		c.queue_free()
	# Just do this here because I'm not sure where it's done.
	# By all means, change this!
	for ref in Global.canvas.get_children():
		if ref is ReferenceImage:
			ref.visible = false
	# And update.
	for ref in Global.current_project.reference_images:
		ref.visible = true
		var l = reference_image_button_tscn.instantiate()
		l.element = ref
		list.add_child(l)
