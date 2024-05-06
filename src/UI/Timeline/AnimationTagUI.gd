extends VBoxContainer

var tag: AnimationTag


func _ready() -> void:
	if not is_instance_valid(tag):
		return
	$Label.text = tag.name
	$Line2D.default_color = tag.color
	$Label.modulate = tag.color
	update_position_and_size()


func update_position_and_size() -> void:
	position = tag.get_position()
	custom_minimum_size.x = tag.get_minimum_size()
	size.x = custom_minimum_size.x
	$Line2D.points[2] = Vector2(custom_minimum_size.x, 0)
	$Line2D.points[3] = Vector2(custom_minimum_size.x, 32)
