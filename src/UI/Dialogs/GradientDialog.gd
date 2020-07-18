extends ConfirmationDialog


var current_cel : Image
var preview_image : Image
var preview_texture : ImageTexture

onready var preview : TextureRect = $VBoxContainer/Preview
onready var color1 : ColorPickerButton = $VBoxContainer/ColorsContainer/ColorPickerButton
onready var color2 : ColorPickerButton = $VBoxContainer/ColorsContainer/ColorPickerButton2
onready var steps : SpinBox = $VBoxContainer/StepsContainer/StepSpinBox


func _ready() -> void:
	current_cel = Image.new()
	preview_image = Image.new()
	preview_texture = ImageTexture.new()
	preview_texture.flags = 0


func _on_GradientDialog_about_to_show() -> void:
	current_cel = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	update_preview()


func update_preview() -> void:
	preview_image.copy_from(current_cel)
	DrawingAlgos.generate_gradient(preview_image, [color1.color, color2.color], steps.value)
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


func _on_ColorPickerButton_color_changed(_color : Color) -> void:
	update_preview()


func _on_ColorPickerButton2_color_changed(_color : Color) -> void:
	update_preview()


func _on_StepSpinBox_value_changed(_value : int) -> void:
	update_preview()


func _on_GradientDialog_confirmed() -> void:
	Global.canvas.handle_undo("Draw")
	DrawingAlgos.generate_gradient(current_cel, [color1.color, color2.color], steps.value)
	Global.canvas.update_texture(Global.current_project.current_layer)
	Global.canvas.handle_redo("Draw")
