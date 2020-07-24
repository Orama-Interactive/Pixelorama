extends WindowDialog


enum {CEL, FRAME, ALL_FRAMES, ALL_PROJECTS}

var affect : int = CEL
var pixels := []
var current_cel : Image
var preview_image : Image
var preview_texture : ImageTexture

onready var hue_slider = $MarginContainer/VBoxContainer/HBoxContainer/Sliders/Hue
onready var sat_slider = $MarginContainer/VBoxContainer/HBoxContainer/Sliders/Saturation
onready var val_slider = $MarginContainer/VBoxContainer/HBoxContainer/Sliders/Value

onready var hue_spinbox = $MarginContainer/VBoxContainer/HBoxContainer/TextBoxes/Hue
onready var sat_spinbox = $MarginContainer/VBoxContainer/HBoxContainer/TextBoxes/Saturation
onready var val_spinbox = $MarginContainer/VBoxContainer/HBoxContainer/TextBoxes/Value

onready var preview = $MarginContainer/VBoxContainer/TextureRect
onready var selection_checkbox : CheckBox = $MarginContainer/VBoxContainer/AffectHBoxContainer/SelectionCheckBox


func _ready() -> void:
	current_cel = Image.new()
	preview_image = Image.new()
	preview_texture = ImageTexture.new()
	preview_texture.flags = 0


func _on_HSVDialog_about_to_show() -> void:
	current_cel = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	preview_image.copy_from(current_cel)
	_on_SelectionCheckBox_toggled(selection_checkbox.pressed)
	update_preview()


func _on_Cancel_pressed() -> void:
	visible = false
	reset()


func _on_Apply_pressed() -> void:
	if affect == CEL:
		Global.canvas.handle_undo("Draw")
		DrawingAlgos.adjust_hsv(current_cel, hue_slider.value, sat_slider.value, val_slider.value, pixels)
		Global.canvas.handle_redo("Draw")
	elif affect == FRAME:
		Global.canvas.handle_undo("Draw", Global.current_project, -1)
		for cel in Global.current_project.frames[Global.current_project.current_frame].cels:
			DrawingAlgos.adjust_hsv(cel.image, hue_slider.value, sat_slider.value, val_slider.value, pixels)
		Global.canvas.handle_redo("Draw", Global.current_project, -1)
	reset()
	visible = false


func reset() -> void:
	disconnect_signals()
	hue_slider.value = 0
	sat_slider.value = 0
	val_slider.value = 0
	hue_spinbox.value = 0
	sat_spinbox.value = 0
	val_spinbox.value = 0
	reconnect_signals()


func update_preview() -> void:
	preview_image.copy_from(current_cel)
	DrawingAlgos.adjust_hsv(preview_image, hue_slider.value, sat_slider.value, val_slider.value, pixels)
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


func disconnect_signals() -> void:
	hue_slider.disconnect("value_changed",self,"_on_Hue_value_changed")
	sat_slider.disconnect("value_changed",self,"_on_Saturation_value_changed")
	val_slider.disconnect("value_changed",self,"_on_Value_value_changed")
	hue_spinbox.disconnect("value_changed",self,"_on_Hue_value_changed")
	sat_spinbox.disconnect("value_changed",self,"_on_Saturation_value_changed")
	val_spinbox.disconnect("value_changed",self,"_on_Value_value_changed")


func reconnect_signals() -> void:
	hue_slider.connect("value_changed",self,"_on_Hue_value_changed")
	sat_slider.connect("value_changed",self,"_on_Saturation_value_changed")
	val_slider.connect("value_changed",self,"_on_Value_value_changed")
	hue_spinbox.connect("value_changed",self,"_on_Hue_value_changed")
	sat_spinbox.connect("value_changed",self,"_on_Saturation_value_changed")
	val_spinbox.connect("value_changed",self,"_on_Value_value_changed")


func _on_Hue_value_changed(value : float) -> void:
	hue_spinbox.value = value
	hue_slider.value = value
	update_preview()


func _on_Saturation_value_changed(value : float) -> void:
	sat_spinbox.value = value
	sat_slider.value = value
	update_preview()


func _on_Value_value_changed(value : float) -> void:
	val_spinbox.value = value
	val_slider.value = value
	update_preview()


func _on_SelectionCheckBox_toggled(button_pressed : bool) -> void:
	pixels.clear()
	if button_pressed:
		pixels = Global.current_project.selected_pixels.duplicate()
	else:
		for x in Global.current_project.size.x:
			for y in Global.current_project.size.y:
				pixels.append(Vector2(x, y))

	update_preview()


func _on_AffectOptionButton_item_selected(index : int) -> void:
	affect = index
