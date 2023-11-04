extends AcceptDialog

var effects: Array[LayerEffect] = [
	LayerEffect.new("Rotate", preload("res://src/Shaders/Rotation/cleanEdge.gdshader")),
	LayerEffect.new("Outline", preload("res://src/Shaders/OutlineInline.gdshader")),
	LayerEffect.new("Drop Shadow", preload("res://src/Shaders/DropShadow.gdshader")),
	LayerEffect.new("Invert Colors", preload("res://src/Shaders/Invert.gdshader")),
	LayerEffect.new("Desaturation", preload("res://src/Shaders/Desaturate.gdshader")),
	LayerEffect.new("Adjust Hue/Saturation/Value", preload("res://src/Shaders/HSV.gdshader")),
	LayerEffect.new("Posterize", preload("res://src/Shaders/Posterize.gdshader")),
	LayerEffect.new("Gradient", preload("res://src/Shaders/Gradients/Linear.gdshader")),
	LayerEffect.new("Gradient Map", preload("res://src/Shaders/GradientMap.gdshader")),
]

@onready var effect_list: MenuButton = $VBoxContainer/EffectList


func _ready() -> void:
	for effect in effects:
		effect_list.get_popup().add_item(effect.name)
	effect_list.get_popup().id_pressed.connect(_on_effect_list_id_pressed)


func _on_effect_list_id_pressed(index: int) -> void:
	var effect := effects[index].duplicate()
	Global.current_project.layers[Global.current_project.current_layer].effects.append(effect)
	Global.canvas.queue_redraw()


func _on_visibility_changed() -> void:
	if not visible:
		Global.dialog_open(false)
