class_name LayerButton
extends BaseLayerButton

onready var linked_button: BaseButton = find_node("LinkButton")

func _ready() -> void:
	if Global.current_project.layers[layer].new_cels_linked:  # If new layers will be linked
		Global.change_button_texturerect(linked_button.get_child(0), "linked_layer.png")
	else:
		Global.change_button_texturerect(linked_button.get_child(0), "unlinked_layer.png")


func _on_LinkButton_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	var layer_class: Layer = Global.current_project.layers[layer]
	layer_class.new_cels_linked = !layer_class.new_cels_linked
	if layer_class.new_cels_linked && !layer_class.linked_cels:
		# If button is pressed and there are no linked cels in the layer
		layer_class.linked_cels.append(
			Global.current_project.frames[Global.current_project.current_frame]
		)
		var container = Global.frames_container.get_child(Global.current_project.current_layer)
		container.get_child(Global.current_project.current_frame).button_setup()

	Global.current_project.layers = Global.current_project.layers  # Call the setter
