extends ImageEffect

onready var options_cont = $VBoxContainer/OptionsContainer
onready var color1: ColorPickerButton = options_cont.get_node("ColorsContainer/ColorPickerButton")
onready var color2: ColorPickerButton = options_cont.get_node("ColorsContainer/ColorPickerButton2")
onready var steps: SpinBox = options_cont.get_node("StepSpinBox")
onready var direction: OptionButton = options_cont.get_node("DirectionOptionButton")


func _ready() -> void:
	color1.get_picker().presets_visible = false
	color1.get_picker().deferred_mode = true
	color2.get_picker().presets_visible = false
	color2.get_picker().deferred_mode = true


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func commit_action(_cel: Image, _project: Project = Global.current_project) -> void:
	DrawingAlgos.generate_gradient(
		_cel,
		[color1.color, color2.color],
		steps.value,
		direction.selected,
		selection_checkbox.pressed,
		_project
	)


func _on_ColorPickerButton_color_changed(_color: Color) -> void:
	update_preview()


func _on_ColorPickerButton2_color_changed(_color: Color) -> void:
	update_preview()


func _on_StepSpinBox_value_changed(_value: int) -> void:
	update_preview()


func _on_DirectionOptionButton_item_selected(_index: int) -> void:
	update_preview()
