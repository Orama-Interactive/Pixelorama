extends ImageEffect


onready var color1 : ColorPickerButton = $VBoxContainer/OptionsContainer/ColorsContainer/ColorPickerButton
onready var color2 : ColorPickerButton = $VBoxContainer/OptionsContainer/ColorsContainer/ColorPickerButton2
onready var steps : SpinBox = $VBoxContainer/OptionsContainer/StepSpinBox
onready var direction : OptionButton = $VBoxContainer/OptionsContainer/DirectionOptionButton


func _ready() -> void:
	color1.get_picker().presets_visible = false
	color2.get_picker().presets_visible = false


func set_nodes() -> void:
	preview = $VBoxContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func commit_action(_cel : Image, _project : Project = Global.current_project) -> void:
	DrawingAlgos.generate_gradient(_cel, [color1.color, color2.color], steps.value, direction.selected, selection_checkbox.pressed, _project)


func _on_ColorPickerButton_color_changed(_color : Color) -> void:
	update_preview()


func _on_ColorPickerButton2_color_changed(_color : Color) -> void:
	update_preview()


func _on_StepSpinBox_value_changed(_value : int) -> void:
	update_preview()


func _on_DirectionOptionButton_item_selected(_index : int) -> void:
	update_preview()
