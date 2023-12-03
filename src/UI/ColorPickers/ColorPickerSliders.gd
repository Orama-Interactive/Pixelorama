extends PanelContainer

@onready var color_picker := %ColorPicker as ColorPicker


func _ready() -> void:
	Tools.color_changed.connect(update_color)


func update_color(color: Color, button: int) -> void:
	if Tools.picking_color_for == button:
		color_picker.color = color


func _on_color_picker_color_changed(color: Color) -> void:
	Tools.assign_color(color, Tools.picking_color_for)
