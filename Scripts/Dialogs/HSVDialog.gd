extends WindowDialog

onready var hue_slider = $MarginContainer/VBoxContainer/HBoxContainer/Sliders/Hue
onready var sat_slider = $MarginContainer/VBoxContainer/HBoxContainer/Sliders/Saturation
onready var val_slider = $MarginContainer/VBoxContainer/HBoxContainer/Sliders/Value

onready var hue_spinbox = $MarginContainer/VBoxContainer/HBoxContainer/TextBoxes/Hue
onready var sat_spinbox = $MarginContainer/VBoxContainer/HBoxContainer/TextBoxes/Saturation
onready var val_spinbox = $MarginContainer/VBoxContainer/HBoxContainer/TextBoxes/Value

onready var preview = $MarginContainer/VBoxContainer/TextureRect

var current_layer:Image
var preview_image:Image
var preview_texture:ImageTexture

func _ready():
	current_layer = Image.new()
	preview_image = Image.new()
	preview_texture = ImageTexture.new()
	preview_texture.flags = 0

func _on_HSVDialog_about_to_show():
	current_layer = Global.canvas.layers[Global.current_layer][0]
	preview_image.copy_from(current_layer)
	update_preview()

func _on_Cancel_pressed():
	visible = false
	reset()

func _on_Apply_pressed():
	Global.canvas.handle_undo("Draw")
	Global.canvas.adjust_hsv(current_layer,0,hue_slider.value)
	Global.canvas.adjust_hsv(current_layer,1,sat_slider.value)
	Global.canvas.adjust_hsv(current_layer,2,val_slider.value)
	Global.canvas.update_texture(Global.current_layer)
	Global.canvas.handle_redo("Draw")
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
	preview_image.copy_from(current_layer)
	Global.canvas.adjust_hsv(preview_image,0,hue_slider.value)
	Global.canvas.adjust_hsv(preview_image,1,sat_slider.value)
	Global.canvas.adjust_hsv(preview_image,2,val_slider.value)
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

func _on_Hue_value_changed(value):
	hue_spinbox.value = value
	hue_slider.value = value
	update_preview()

func _on_Saturation_value_changed(value):
	sat_spinbox.value = value
	sat_slider.value = value
	update_preview()

func _on_Value_value_changed(value):
	val_spinbox.value = value
	val_slider.value = value
	update_preview()







