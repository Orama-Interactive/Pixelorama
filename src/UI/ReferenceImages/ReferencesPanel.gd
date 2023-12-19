class_name ReferencesPanel
extends VBoxContainer
## Panel for reference image management

var list_btn_group := ButtonGroup.new()
@onready var list = $"ReferenceImages/List"


func _ready() -> void:
	list_btn_group.pressed.connect(_on_reference_image_button_pressed)
	Global.canvas.reference_image_container.reference_image_changed.connect(
		_on_reference_image_changed
	)
	OpenSave.reference_image_imported.connect(_on_references_changed)
	# We call this function to update the buttons
	_on_references_changed()


func _on_reference_image_button_pressed(button: Button) -> void:
	# We subtract 1 because we already have a default button to "select no reference image
	Global.current_project.set_reference_image_index(button.get_index() - 1)


# In case the signal is emitted for another node and not from a pressed button
func _on_reference_image_changed(index: int) -> void:
	if list_btn_group.get_buttons().size() > 0:
		# First we loop through the buttons to "unpress them all"
		# There is a visual bug with BaseButton.set_pressed_no_signal()
		for b: Button in list_btn_group.get_buttons():
			if (index + 1) == b.get_index():
				b.set_pressed_no_signal(true)
			else:
				b.set_pressed_no_signal(false)


func _on_references_changed():
	# When we change the project we set the default
	Global.current_project.set_reference_image_index(-1)

	for c in list.get_children():
		if c is Button:
			c.button_group = null
		c.queue_free()
	# Made it only look in the ReferenceImages Node for reference images
	for ref in Global.canvas.reference_image_container.get_children():
		if ref is ReferenceImage:
			ref.visible = false

	# The default button
	var default = Button.new()
	default.button_group = list_btn_group
	default.text = "none"
	default.custom_minimum_size = Vector2(64, 64)
	default.toggle_mode = true
	default.button_pressed = true
	list.add_child(default)

	# And update.
	for ref in Global.current_project.reference_images:
		ref.visible = true
		var l = Button.new()
		l.button_group = list_btn_group
		if ref.texture:
			l.icon = ref.texture
		l.expand_icon = true
		l.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(64, 64)
		l.toggle_mode = true
		list.add_child(l)
