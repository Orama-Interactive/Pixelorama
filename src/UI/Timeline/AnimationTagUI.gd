extends Control

var tag: AnimationTag
@onready var tag_properties := Global.control.find_child("TagProperties") as ConfirmationDialog


func _ready() -> void:
	if not is_instance_valid(tag):
		return
	$Button.text = tag.name
	$Button.modulate = tag.color
	$Line2D.default_color = tag.color
	update_position_and_size()


func update_position_and_size() -> void:
	position = tag.get_position()
	custom_minimum_size.x = tag.get_minimum_size()
	size.x = custom_minimum_size.x
	$Line2D.points[2].x = custom_minimum_size.x
	$Line2D.points[3].x = custom_minimum_size.x


func _on_button_pressed() -> void:
	var tag_id := Global.current_project.animation_tags.find(tag)
	tag_properties.show_dialog(Rect2i(), tag_id, true)
