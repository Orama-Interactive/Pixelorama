class_name GroupLayerButton
extends BaseLayerButton

onready var expand_button: BaseButton = find_node("ExpandButton")

func _ready() -> void:
	if Global.current_project.layers[layer].expanded:  # If the group is expanded
		Global.change_button_texturerect(expand_button.get_child(0), "group_expanded.png")
	else:
		Global.change_button_texturerect(expand_button.get_child(0), "group_collapsed.png")



func _on_ExpandButton_pressed():
	Global.current_project.layers[layer].expanded = !Global.current_project.layers[layer].expanded
