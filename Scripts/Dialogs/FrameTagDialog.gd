extends AcceptDialog


var current_tag_id := 0
var tag_vboxes := []
var delete_tag_button : Button

onready var main_vbox_cont : VBoxContainer = $VBoxContainer/ScrollContainer/VBoxTagContainer
onready var add_tag_button : TextureButton = $VBoxContainer/ScrollContainer/VBoxTagContainer/AddTag
onready var options_dialog = $TagOptions


func _on_FrameTagDialog_about_to_show() -> void:
	Global.can_draw = false
	for vbox in tag_vboxes:
		vbox.queue_free()
	tag_vboxes.clear()

	var i := 0
	for tag in Global.animation_tags:
		var vbox_cont := VBoxContainer.new()
		var hbox_cont := HBoxContainer.new()
		var tag_label := Label.new()
		if tag[2] == tag[3]:
			tag_label.text = "Tag %s (Frame %s)" % [i + 1, tag[2]]
		else:
			tag_label.text = "Tag %s (Frames %s-%s)" % [i + 1, tag[2], tag[3]]
		hbox_cont.add_child(tag_label)

		var edit_button := Button.new()
		edit_button.text = "Edit"
		edit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		edit_button.connect("pressed", self, "_on_EditButton_pressed", [i])
		hbox_cont.add_child(edit_button)
		vbox_cont.add_child(hbox_cont)

		var name_label := Label.new()
		name_label.text = tag[0]
		name_label.modulate = tag[1]
		vbox_cont.add_child(name_label)

		var hsep := HSeparator.new()
		hsep.size_flags_horizontal = SIZE_EXPAND_FILL
		vbox_cont.add_child(hsep)

		main_vbox_cont.add_child(vbox_cont)
		tag_vboxes.append(vbox_cont)

		i += 1

	add_tag_button.visible = true
	main_vbox_cont.move_child(add_tag_button, main_vbox_cont.get_child_count() - 1)


func _on_FrameTagDialog_popup_hide() -> void:
	Global.can_draw = true


func _on_AddTag_pressed() -> void:
	options_dialog.popup_centered()
	current_tag_id = Global.animation_tags.size()


func _on_EditButton_pressed(_tag_id : int) -> void:
	options_dialog.popup_centered()
	current_tag_id = _tag_id
	options_dialog.get_node("GridContainer/NameLineEdit").text = Global.animation_tags[_tag_id][0]
	options_dialog.get_node("GridContainer/ColorPickerButton").color = Global.animation_tags[_tag_id][1]
	options_dialog.get_node("GridContainer/FromSpinBox").value = Global.animation_tags[_tag_id][2]
	options_dialog.get_node("GridContainer/ToSpinBox").value = Global.animation_tags[_tag_id][3]
	if !delete_tag_button:
		delete_tag_button = options_dialog.add_button("Delete Tag", true, "delete_tag")
	else:
		delete_tag_button.visible = true


func _on_TagOptions_confirmed() -> void:
	var tag_name : String = options_dialog.get_node("GridContainer/NameLineEdit").text
	var tag_color : Color = options_dialog.get_node("GridContainer/ColorPickerButton").color
	var tag_from : int = options_dialog.get_node("GridContainer/FromSpinBox").value
	var tag_to : int = options_dialog.get_node("GridContainer/ToSpinBox").value
	if current_tag_id == Global.animation_tags.size():
		Global.animation_tags.append([tag_name, tag_color, tag_from, tag_to])
		Global.animation_tags = Global.animation_tags # To execute animation_tags_changed()
	else:
		Global.animation_tags[current_tag_id][0] = tag_name
		Global.animation_tags[current_tag_id][1] = tag_color
		Global.animation_tags[current_tag_id][2] = tag_from
		Global.animation_tags[current_tag_id][3] = tag_to
	_on_FrameTagDialog_about_to_show()


func _on_TagOptions_custom_action(action : String) -> void:
	if action == "delete_tag":
		Global.animation_tags.remove(current_tag_id)
		Global.animation_tags = Global.animation_tags # To execute animation_tags_changed()
		options_dialog.hide()
		_on_FrameTagDialog_about_to_show()


func _on_TagOptions_popup_hide() -> void:
	if delete_tag_button:
		delete_tag_button.visible = false


func _on_PlayOnlyTags_toggled(button_pressed : bool) -> void:
	Global.play_only_tags = button_pressed
