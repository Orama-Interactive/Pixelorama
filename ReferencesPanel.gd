class_name ReferencesPanel
extends VBoxContainer
## Panel for reference image management

signal reference_image_clicked(index: int)

var list_btn_group := ButtonGroup.new()
@onready var list = $"ReferenceImages/List"

func _ready() -> void:
	list_btn_group.pressed.connect(_on_reference_image_button_pressed)
	reference_image_clicked.connect(_on_reference_image_pressed)


func _on_reference_image_button_pressed(button: Button) -> void:
	# We subtract 1 because we already have a default button to "select no reference image
	reference_image_clicked.emit(button.get_index() - 1)

# In case the signal is emited for another node and not froma pressed button
func _on_reference_image_pressed(index: int) -> void:
	var button := list_btn_group.get_buttons()[index + 1]
	button.set_pressed_no_signal(true)


func project_changed():
	for c in list.get_children():
		c.queue_free()
	# Made it only look in the ReferenceImages Node for reference images
	for ref in Global.canvas.reference_images.get_children():
		if ref is ReferenceImage:
			ref.visible = false
	
	# The defualt button
	var defualt = Button.new()
	defualt.button_group = list_btn_group
	defualt.text = "none"
	defualt.custom_minimum_size = Vector2(64, 64)
	defualt.toggle_mode = true
	defualt.button_pressed = true
	list.add_child(defualt)
	
	# And update.
	for ref in Global.current_project.reference_images:
		ref.visible = true
		var l = Button.new()
		l.button_group = list_btn_group
		l.icon = ref.texture
		l.expand_icon = true
		l.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(64, 64)
		l.toggle_mode = true
		list.add_child(l)
