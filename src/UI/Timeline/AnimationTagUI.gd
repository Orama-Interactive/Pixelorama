extends Control

enum Drag { NONE, FROM, TO }

var tag: AnimationTag
var dragging_tag: AnimationTag
var dragged_initial := 0
var is_dragging := Drag.NONE
@onready var tag_properties := Global.control.find_child("TagProperties") as ConfirmationDialog


func _ready() -> void:
	if not is_instance_valid(tag):
		return
	$Button.text = tag.name
	$Button.modulate = tag.color
	$Line2D.default_color = tag.color
	update_position_and_size()


func update_position_and_size(from_tag := tag) -> void:
	position = from_tag.get_position()
	custom_minimum_size.x = from_tag.get_minimum_size()
	size.x = custom_minimum_size.x
	$Line2D.points[2].x = custom_minimum_size.x
	$Line2D.points[3].x = custom_minimum_size.x


func _on_button_pressed() -> void:
	var tag_id := Global.current_project.animation_tags.find(tag)
	tag_properties.show_dialog(Rect2i(), tag_id, true)


func _resize_tag(resize: Drag, value: int) -> void:
	var new_animation_tags: Array[AnimationTag] = []
	# Loop through the tags to create new classes for them, so that they won't be the same
	# as Global.current_project.animation_tags's classes. Needed for undo/redo to work properly.
	for frame_tag in Global.current_project.animation_tags:
		new_animation_tags.append(frame_tag.duplicate())

	var tag_id := Global.current_project.animation_tags.find(tag)
	if resize == Drag.FROM:
		if new_animation_tags[tag_id].from == value:
			return
		new_animation_tags[tag_id].from = value
	elif resize == Drag.TO:
		if new_animation_tags[tag_id].to == value:
			return
		new_animation_tags[tag_id].to = value

	# Handle Undo/Redo
	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Resize Frame Tag")
	Global.current_project.undo_redo.add_do_method(Global.general_redo)
	Global.current_project.undo_redo.add_undo_method(Global.general_undo)
	Global.current_project.undo_redo.add_do_property(
		Global.current_project, &"animation_tags", new_animation_tags
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, &"animation_tags", Global.current_project.animation_tags
	)
	Global.current_project.undo_redo.commit_action()


func _on_resize_from_gui_input(event: InputEvent) -> void:
	var cel_size: int = Global.animation_timeline.cel_size
	if event is InputEventMouseButton:
		if event.pressed:
			is_dragging = Drag.FROM
			dragging_tag = tag.duplicate()
			dragged_initial = global_position.x
		else:
			_resize_tag(is_dragging, dragging_tag.from)
			is_dragging = Drag.NONE
			dragging_tag = null
	elif event is InputEventMouseMotion:
		if is_dragging == Drag.FROM:
			var dragged_offset := snappedi(event.global_position.x, cel_size)
			var diff := roundi(float(dragged_offset - dragged_initial) / cel_size)
			dragging_tag.from = clampi(tag.from + diff, 1, tag.to)
			update_position_and_size(dragging_tag)


func _on_resize_to_gui_input(event: InputEvent) -> void:
	var cel_size: int = Global.animation_timeline.cel_size
	if event is InputEventMouseButton:
		if event.pressed:
			is_dragging = Drag.TO
			dragging_tag = tag.duplicate()
			dragged_initial = global_position.x + size.x
		else:
			_resize_tag(is_dragging, dragging_tag.to)
			is_dragging = Drag.NONE
			dragging_tag = null
	elif event is InputEventMouseMotion:
		if is_dragging == Drag.TO:
			var dragged_offset := snappedi(event.global_position.x, cel_size)
			var diff := roundi(float(dragged_offset - dragged_initial) / cel_size)
			dragging_tag.to = clampi(tag.to + diff, tag.from, Global.current_project.frames.size())
			update_position_and_size(dragging_tag)
