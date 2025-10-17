extends ConfirmationDialog

var current_tag_id := 0
var old_duration: float = 0
@onready var delete_tag_button := add_button("Delete", true, "delete_tag")
@onready var name_line_edit := $GridContainer/NameLineEdit as LineEdit
@onready var color_picker_button := $GridContainer/ColorPickerButton as ColorPickerButton
@onready var duration_slider := $GridContainer/DurationSlider as ValueSlider
@onready var from_spinbox := $GridContainer/FromSlider as ValueSlider
@onready var to_spinbox := $GridContainer/ToSlider as ValueSlider
@onready var user_data_text_edit := $GridContainer/UserDataTextEdit as TextEdit


func _ready() -> void:
	color_picker_button.get_picker().presets_visible = false


func show_dialog(
	popup_rect: Rect2i, tag_id: int, is_editing: bool, selected_frames := PackedInt32Array()
) -> void:
	current_tag_id = tag_id
	$GridContainer/DurationLabel.visible = is_editing
	duration_slider.visible = is_editing
	old_duration = 0
	duration_slider.value = 0
	if is_editing:
		var animation_tag := Global.current_project.animation_tags[tag_id]
		name_line_edit.text = animation_tag.name
		color_picker_button.color = animation_tag.color
		for i in range(animation_tag.from - 1, animation_tag.to):
			var frame: Frame = Global.current_project.frames[i]
			old_duration += frame.get_duration_in_seconds(Global.current_project.fps)
			duration_slider.value = old_duration

		from_spinbox.value = animation_tag.from
		to_spinbox.value = animation_tag.to
		user_data_text_edit.text = animation_tag.user_data
		delete_tag_button.visible = true
	else:
		from_spinbox.value = (selected_frames[0] + 1)
		to_spinbox.value = (selected_frames[-1] + 1)
		color_picker_button.color = Color(randf(), randf(), randf())
		user_data_text_edit.text = ""
		delete_tag_button.visible = false
	if popup_rect == Rect2i():
		popup_centered()
	else:
		popup(popup_rect)
	name_line_edit.grab_focus()


func _on_confirmed() -> void:
	var tag_name := name_line_edit.text
	var tag_color := color_picker_button.color
	var tag_to := clampi(to_spinbox.value, 0, Global.current_project.frames.size())
	var tag_from := clampi(from_spinbox.value, 0, tag_to)
	if not is_equal_approx(old_duration, duration_slider.value):
		# Spread the new duration weighted by their individual duration
		var ratio = duration_slider.value / old_duration
		for i in range(tag_from - 1, tag_to):
			var frame: Frame = Global.current_project.frames[i]
			frame.duration *= snappedf(ratio * frame.duration, 0.01)
	var user_data := user_data_text_edit.text
	var new_animation_tags: Array[AnimationTag] = []
	# Loop through the tags to create new classes for them, so that they won't be the same
	# as Global.current_project.animation_tags's classes. Needed for undo/redo to work properly.
	for tag in Global.current_project.animation_tags:
		new_animation_tags.append(tag.duplicate())

	if current_tag_id == Global.current_project.animation_tags.size():
		var new_tag := AnimationTag.new(tag_name, tag_color, tag_from, tag_to)
		new_tag.user_data = user_data
		new_animation_tags.append(new_tag)
	else:
		new_animation_tags[current_tag_id].name = tag_name
		new_animation_tags[current_tag_id].color = tag_color
		new_animation_tags[current_tag_id].from = tag_from
		new_animation_tags[current_tag_id].to = tag_to
		new_animation_tags[current_tag_id].user_data = user_data

	# Handle Undo/Redo
	Global.current_project.undo_redo.create_action("Modify Frame Tag")
	Global.current_project.undo_redo.add_do_method(Global.general_redo)
	Global.current_project.undo_redo.add_undo_method(Global.general_undo)
	Global.current_project.undo_redo.add_do_property(
		Global.current_project, &"animation_tags", new_animation_tags
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, &"animation_tags", Global.current_project.animation_tags
	)
	Global.current_project.undo_redo.commit_action()


func _on_custom_action(action: StringName) -> void:
	if action != &"delete_tag":
		return
	var new_animation_tags := Global.current_project.animation_tags.duplicate()
	new_animation_tags.remove_at(current_tag_id)
	# Handle Undo/Redo
	Global.current_project.undo_redo.create_action("Delete Frame Tag")
	Global.current_project.undo_redo.add_do_method(Global.general_redo)
	Global.current_project.undo_redo.add_undo_method(Global.general_undo)
	Global.current_project.undo_redo.add_do_property(
		Global.current_project, &"animation_tags", new_animation_tags
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, &"animation_tags", Global.current_project.animation_tags
	)
	Global.current_project.undo_redo.commit_action()

	hide()


func _on_visibility_changed() -> void:
	Global.dialog_open(visible)
