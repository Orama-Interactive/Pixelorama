extends ConfirmationDialog


var aspect_ratio := 1.0

onready var width_value : SpinBox = find_node("WidthValue")
onready var height_value : SpinBox = find_node("HeightValue")
onready var width_value_perc : SpinBox = find_node("WidthValuePerc")
onready var height_value_perc : SpinBox = find_node("HeightValuePerc")
onready var interpolation_type : OptionButton = find_node("InterpolationType")
onready var ratio_box : BaseButton = find_node("AspectRatioButton")


func _on_ScaleImage_about_to_show() -> void:
	Global.canvas.selection.transform_content_confirm()
	width_value.value = Global.current_project.size.x
	height_value.value = Global.current_project.size.y
	width_value_perc.value = 100
	height_value_perc.value = 100
	aspect_ratio = width_value.value / height_value.value


func _on_ScaleImage_confirmed() -> void:
	var width : int = width_value.value
	var height : int = height_value.value
	var interpolation : int = interpolation_type.selected
	DrawingAlgos.scale_image(width, height, interpolation)


func _on_ScaleImage_popup_hide() -> void:
	Global.dialog_open(false)


func _on_WidthValue_value_changed(value : float) -> void:
	if ratio_box.pressed:
		height_value.value = width_value.value / aspect_ratio
	width_value_perc.value = (value * 100) / Global.current_project.size.x


func _on_HeightValue_value_changed(value : float) -> void:
	if ratio_box.pressed:
		width_value.value = height_value.value * aspect_ratio
	height_value_perc.value = (value * 100) / Global.current_project.size.y


func _on_WidthValuePerc_value_changed(value : float) -> void:
	width_value.value = (Global.current_project.size.x * value) / 100


func _on_HeightValuePerc_value_changed(value : float) -> void:
	height_value.value = (Global.current_project.size.y * value) / 100


func _on_AspectRatioButton_toggled(button_pressed : bool) -> void:
	if button_pressed:
		height_value.value = width_value.value / aspect_ratio
