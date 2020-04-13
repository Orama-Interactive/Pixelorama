extends WindowDialog

onready var hue_slider = $ HBoxContainer/Sliders/Hue
onready var sat_slider = $ HBoxContainer/Sliders/Saturation
onready var val_slider = $ HBoxContainer/Sliders/Value

onready var hue_spinbox = $ HBoxContainer/TextBoxes/Hue
onready var sat_spinbox = $ HBoxContainer/TextBoxes/Saturation
onready var val_spinbox = $ HBoxContainer/TextBoxes/Value

onready var hue_text = $ HBoxContainer/TextBoxes/Hue.get_line_edit()
onready var sat_text = $ HBoxContainer/TextBoxes/Saturation.get_line_edit()
onready var val_text = $ HBoxContainer/TextBoxes/Value.get_line_edit()

var oldHue = 180
var oldSat = 50
var oldVal = 50

func _ready():
	get_close_button().connect("pressed",self,"_on_Cancel_pressed")

func _on_Cancel_pressed():
	Global.undo_redo.undo() 
	visible = false
	reset()

func _on_Apply_pressed():
	Global.canvas.handle_redo("Draw")
	reset()
	visible = false


func reset():
	disconnect_signals()
	hue_slider.value = 180
	sat_slider.value = 50
	val_slider.value = 50
	hue_text.text = str(180)
	sat_text.text = str(50)
	val_text.text = str(50)
	reconnect_signals()

func disconnect_signals():
	hue_slider.disconnect("value_changed",self,"_on_Hue_value_changed")
	sat_slider.disconnect("value_changed",self,"_on_Saturation_value_changed")
	val_slider.disconnect("value_changed",self,"_on_Value_value_changed")
	hue_spinbox.disconnect("value_changed",self,"_on_Hue_value_changed")
	sat_spinbox.disconnect("value_changed",self,"_on_Saturation_value_changed")
	val_spinbox.disconnect("value_changed",self,"_on_Value_value_changed")

func reconnect_signals():
	hue_slider.connect("value_changed",self,"_on_Hue_value_changed")
	sat_slider.connect("value_changed",self,"_on_Saturation_value_changed")
	val_slider.connect("value_changed",self,"_on_Value_value_changed")
	hue_spinbox.connect("value_changed",self,"_on_Hue_value_changed")
	sat_spinbox.connect("value_changed",self,"_on_Saturation_value_changed")
	val_spinbox.connect("value_changed",self,"_on_Value_value_changed")


func _on_HSVDialog_about_to_show():
	Global.canvas.handle_undo("Draw")

func _on_Hue_value_changed(value):
	hue_text.text = str(value)
	hue_slider.value = int(value)
	var delta = value - oldHue
	oldHue = value
	Global.canvas.adjust_hsv(0,delta)

func _on_Saturation_value_changed(value):
	sat_text.text = str(value)
	sat_slider.value = int(value)
	var delta = value - oldSat
	oldSat = value
	Global.canvas.adjust_hsv(1,delta)


func _on_Value_value_changed(value):
	val_text.text = str(value)
	val_slider.value = int(value)
	var delta = value - oldVal
	oldVal = value
	Global.canvas.adjust_hsv(2,delta)








