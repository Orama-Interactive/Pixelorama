extends AcceptDialog

@onready var size_value_label := $GridContainer/SizeValueLabel as Label
@onready var color_mode_value_label := $GridContainer/ColorModeValueLabel as Label
@onready var frames_value_label := $GridContainer/FramesValueLabel as Label
@onready var layers_value_label := $GridContainer/LayersValueLabel as Label
@onready var name_line_edit := $GridContainer/NameLineEdit as LineEdit
@onready var user_data_text_edit := $GridContainer/UserDataTextEdit as TextEdit


func _on_visibility_changed() -> void:
	Global.dialog_open(visible)
	size_value_label.text = str(Global.current_project.size)
	if Global.current_project.get_image_format() == Image.FORMAT_RGBA8:
		color_mode_value_label.text = "RGBA8"
	else:
		color_mode_value_label.text = str(Global.current_project.get_image_format())
	if Global.current_project.is_indexed():
		color_mode_value_label.text += " (%s)" % tr("Indexed")
	frames_value_label.text = str(Global.current_project.frames.size())
	layers_value_label.text = str(Global.current_project.layers.size())
	name_line_edit.text = Global.current_project.name
	user_data_text_edit.text = Global.current_project.user_data


func _on_name_line_edit_text_changed(new_text: String) -> void:
	Global.current_project.name = new_text


func _on_user_data_text_edit_text_changed() -> void:
	Global.current_project.user_data = user_data_text_edit.text
