extends AcceptDialog

var tag_vboxes := []
var called_tag_properties := false  ## True when tag properties has been shown by this dialog

@onready var main_vbox_cont: VBoxContainer = $VBoxContainer/ScrollContainer/VBoxTagContainer
@onready var add_tag_button: Button = $VBoxContainer/ScrollContainer/VBoxTagContainer/AddTag
@onready var tag_properties := Global.control.find_child("TagProperties") as ConfirmationDialog


func _ready() -> void:
	tag_properties.visibility_changed.connect(_on_tag_options_visibility_changed)


func _on_tag_options_visibility_changed() -> void:
	if called_tag_properties:
		called_tag_properties = false
		popup_centered.call_deferred()


func _on_FrameTagDialog_about_to_show() -> void:
	Global.dialog_open(true)
	for vbox in tag_vboxes:
		vbox.queue_free()
	tag_vboxes.clear()

	var i := 0
	for tag in Global.current_project.animation_tags:
		var vbox_cont := VBoxContainer.new()
		var hbox_cont := HBoxContainer.new()
		var tag_label := Label.new()
		if tag.from == tag.to:
			tag_label.text = tr("Tag %s (Frame %s)") % [i + 1, tag.from]
		else:
			tag_label.text = tr("Tag %s (Frames %s-%s)") % [i + 1, tag.from, tag.to]
		hbox_cont.add_child(tag_label)

		var edit_button := Button.new()
		edit_button.text = "Edit"
		edit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		edit_button.pressed.connect(_on_EditButton_pressed.bind(i, edit_button))
		hbox_cont.add_child(edit_button)
		vbox_cont.add_child(hbox_cont)

		var name_label := Label.new()
		name_label.text = tag.name
		name_label.modulate = tag.color
		vbox_cont.add_child(name_label)

		var hsep := HSeparator.new()
		hsep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox_cont.add_child(hsep)

		main_vbox_cont.add_child(vbox_cont)
		tag_vboxes.append(vbox_cont)

		i += 1

	add_tag_button.visible = true
	main_vbox_cont.move_child(add_tag_button, main_vbox_cont.get_child_count() - 1)


func _on_FrameTagDialog_visibility_changed() -> void:
	if not visible:
		Global.dialog_open(false)


func _on_AddTag_pressed() -> void:
	var x_pos := add_tag_button.global_position.x
	var y_pos := add_tag_button.global_position.y + 2 * add_tag_button.size.y
	var dialog_position := Rect2i(position + Vector2i(x_pos, y_pos), tag_properties.size)
	var current_tag_id := Global.current_project.animation_tags.size()
	# Determine tag values (array sort method)
	var frames := PackedInt32Array([])
	for cel in Global.current_project.selected_cels:
		frames.append(cel[0])
	frames.sort()
	tag_properties.show_dialog(dialog_position, current_tag_id, false, frames)
	called_tag_properties = true


func _on_EditButton_pressed(_tag_id: int, edit_button: Button) -> void:
	var x_pos := edit_button.global_position.x
	var y_pos := edit_button.global_position.y + 2 * edit_button.size.y
	var dialog_position := Rect2i(position + Vector2i(x_pos, y_pos), tag_properties.size)
	tag_properties.show_dialog(dialog_position, _tag_id, true)
	called_tag_properties = true


func _on_PlayOnlyTags_toggled(button_pressed: bool) -> void:
	Global.play_only_tags = button_pressed
