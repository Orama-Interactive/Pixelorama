extends Button

enum MenuOptions {DELETE, LINK, PROPERTIES}


var frame := 0
var layer := 0
var cel : Cel
var image : Image

onready var popup_menu : PopupMenu = $PopupMenu


func _ready() -> void:
	rect_min_size.x = Global.animation_timeline.cel_size
	rect_min_size.y = Global.animation_timeline.cel_size

	hint_tooltip = tr("Frame: %s, Layer: %s") % [frame + 1, layer]
	if Global.current_project.frames[frame] in Global.current_project.layers[layer].linked_cels:
		get_node("LinkedIndicator").visible = true
		popup_menu.set_item_text(MenuOptions.LINK, "Unlink Cel")
		popup_menu.set_item_metadata(MenuOptions.LINK, "Unlink Cel")
	else:
		get_node("LinkedIndicator").visible = false
		popup_menu.set_item_text(MenuOptions.LINK, "Link Cel")
		popup_menu.set_item_metadata(MenuOptions.LINK, "Link Cel")

	# Reset the checkers size because it assumes you want the same size as the canvas
	var checker = $CelTexture/TransparentChecker
	checker.rect_size = checker.get_parent().rect_size
	cel = Global.current_project.frames[frame].cels[layer]
	image = cel.image


func _on_CelButton_resized() -> void:
	get_node("CelTexture").rect_min_size.x = rect_min_size.x - 4
	get_node("CelTexture").rect_min_size.y = rect_min_size.y - 4

	get_node("LinkedIndicator").polygon[1].x = rect_min_size.x
	get_node("LinkedIndicator").polygon[2].x = rect_min_size.x
	get_node("LinkedIndicator").polygon[2].y = rect_min_size.y
	get_node("LinkedIndicator").polygon[3].y = rect_min_size.y


func _on_CelButton_pressed() -> void:
	var project := Global.current_project
	if Input.is_action_just_released("left_mouse"):
		Global.canvas.selection.transform_content_confirm()
		var change_cel := true
		var prev_curr_frame : int = project.current_frame
		var prev_curr_layer : int = project.current_layer

		if Input.is_action_pressed("shift"):
			var frame_diff_sign = sign(frame - prev_curr_frame)
			if frame_diff_sign == 0:
				frame_diff_sign = 1
			var layer_diff_sign = sign(layer - prev_curr_layer)
			if layer_diff_sign == 0:
				layer_diff_sign = 1
			for i in range(prev_curr_frame, frame + frame_diff_sign, frame_diff_sign):
				for j in range(prev_curr_layer, layer + layer_diff_sign, layer_diff_sign):
					var frame_layer := [i, j]
					if !project.selected_cels.has(frame_layer):
						project.selected_cels.append(frame_layer)
		elif Input.is_action_pressed("ctrl"):
			var frame_layer := [frame, layer]
			if project.selected_cels.has(frame_layer):
				if project.selected_cels.size() > 1:
					project.selected_cels.erase(frame_layer)
					change_cel = false
			else:
				project.selected_cels.append(frame_layer)
		else: # If the button is pressed without Shift or Control
			project.selected_cels.clear()
			var frame_layer := [frame, layer]
			if !project.selected_cels.has(frame_layer):
				project.selected_cels.append(frame_layer)

		if change_cel:
			project.current_frame = frame
			project.current_layer = layer
		else:
			project.current_frame = project.selected_cels[0][0]
			project.current_layer = project.selected_cels[0][1]
			release_focus()

	elif Input.is_action_just_released("right_mouse"):
		popup_menu.popup(Rect2(get_global_mouse_position(), Vector2.ONE))
		pressed = !pressed
	elif Input.is_action_just_released("middle_mouse"):
		pressed = !pressed
		delete_cel_contents()
	else: # An example of this would be Space
		pressed = !pressed


func _on_PopupMenu_id_pressed(ID : int) -> void:
	match ID:
		MenuOptions.DELETE:
			delete_cel_contents()

		MenuOptions.LINK:
			var cel_index : int = Global.current_project.layers[layer].linked_cels.find(Global.current_project.frames[frame])
			var f = Global.current_project.frames[frame]
			var new_layers : Array = Global.current_project.layers.duplicate()
			# Loop through the array to create new classes for each element, so that they
			# won't be the same as the original array's classes. Needed for undo/redo to work properly.
			for i in new_layers.size():
				var new_linked_cels = new_layers[i].linked_cels.duplicate()
				new_layers[i] = Layer.new(new_layers[i].name, new_layers[i].visible, new_layers[i].locked, new_layers[i].frame_container, new_layers[i].new_cels_linked, new_linked_cels)
			var new_cels : Array = f.cels.duplicate()
			for i in new_cels.size():
				new_cels[i] = Cel.new(new_cels[i].image, new_cels[i].opacity)

			if popup_menu.get_item_metadata(MenuOptions.LINK) == "Unlink Cel":
				new_layers[layer].linked_cels.remove(cel_index)
				var sprite := Image.new()
				sprite.copy_from(Global.current_project.frames[frame].cels[layer].image)
				sprite.lock()
				new_cels[layer].image = sprite

				Global.current_project.undo_redo.create_action("Unlink Cel")
				Global.current_project.undo_redo.add_do_property(Global.current_project, "layers", new_layers)
				Global.current_project.undo_redo.add_do_property(f, "cels", new_cels)
				Global.current_project.undo_redo.add_undo_property(Global.current_project, "layers", Global.current_project.layers)
				Global.current_project.undo_redo.add_undo_property(f, "cels", f.cels)

				Global.current_project.undo_redo.add_undo_method(Global, "undo")
				Global.current_project.undo_redo.add_do_method(Global, "redo")
				Global.current_project.undo_redo.commit_action()
			elif popup_menu.get_item_metadata(MenuOptions.LINK) == "Link Cel":
				new_layers[layer].linked_cels.append(Global.current_project.frames[frame])
				Global.current_project.undo_redo.create_action("Link Cel")
				Global.current_project.undo_redo.add_do_property(Global.current_project, "layers", new_layers)
				if new_layers[layer].linked_cels.size() > 1:
					# If there are already linked cels, set the current cel's image
					# to the first linked cel's image
					new_cels[layer].image = new_layers[layer].linked_cels[0].cels[layer].image
					new_cels[layer].image_texture = new_layers[layer].linked_cels[0].cels[layer].image_texture
					Global.current_project.undo_redo.add_do_property(f, "cels", new_cels)
					Global.current_project.undo_redo.add_undo_property(f, "cels", f.cels)

				Global.current_project.undo_redo.add_undo_property(Global.current_project, "layers", Global.current_project.layers)
				Global.current_project.undo_redo.add_undo_method(Global, "undo")
				Global.current_project.undo_redo.add_do_method(Global, "redo")
				Global.current_project.undo_redo.commit_action()


func delete_cel_contents() -> void:
	if image.is_invisible():
		return
	Global.canvas.handle_undo("Draw", Global.current_project, layer, frame)
	image.fill(0)
	Global.canvas.handle_redo("Draw", Global.current_project, layer, frame)


func get_drag_data(_position) -> Array:
	var button := Button.new()
	button.rect_size = rect_size
	button.theme = Global.control.theme
	var texture_rect := TextureRect.new()
	texture_rect.rect_size = $CelTexture.rect_size
	texture_rect.rect_position = $CelTexture.rect_position
	texture_rect.expand = true
	texture_rect.texture = $CelTexture.texture
	button.add_child(texture_rect)
	set_drag_preview(button)

	return ["Cel", frame, layer]


func can_drop_data(_pos, data) -> bool:
	if typeof(data) == TYPE_ARRAY and data[0] == "Cel":
		var new_frame = data[1]
		var new_layer = data[2]
		if Global.current_project.frames[frame] in Global.current_project.layers[layer].linked_cels or Global.current_project.frames[new_frame] in Global.current_project.layers[new_layer].linked_cels:
			# If the cel we're dragging or the cel we are targeting are linked, don't allow dragging
			return false
		else:
			return true
	else:
		return false


func drop_data(_pos, data) -> void:
	var new_frame = data[1]
	var new_layer = data[2]
	if new_frame == frame and new_layer == layer:
		return

	var this_frame_new_cels = Global.current_project.frames[frame].cels.duplicate()
	var new_frame_new_cels
	var temp = this_frame_new_cels[layer]
	this_frame_new_cels[layer] = Global.current_project.frames[new_frame].cels[new_layer]
	if frame == new_frame:
		this_frame_new_cels[new_layer] = temp
	else:
		new_frame_new_cels = Global.current_project.frames[new_frame].cels.duplicate()
		new_frame_new_cels[new_layer] = temp

	Global.current_project.undo_redo.create_action("Move Cels")
	Global.current_project.undo_redo.add_do_property(Global.current_project.frames[frame], "cels", this_frame_new_cels)

	Global.current_project.undo_redo.add_do_property(Global.current_project, "current_layer", layer)
	Global.current_project.undo_redo.add_undo_property(Global.current_project, "current_layer", Global.current_project.current_layer)

	if frame != new_frame: # If the cel moved to a different frame
		Global.current_project.undo_redo.add_do_property(Global.current_project.frames[new_frame], "cels", new_frame_new_cels)

		Global.current_project.undo_redo.add_do_property(Global.current_project, "current_frame", frame)
		Global.current_project.undo_redo.add_undo_property(Global.current_project, "current_frame", Global.current_project.current_frame)

		Global.current_project.undo_redo.add_undo_property(Global.current_project.frames[new_frame], "cels", Global.current_project.frames[new_frame].cels)

	Global.current_project.undo_redo.add_undo_property(Global.current_project.frames[frame], "cels", Global.current_project.frames[frame].cels)

	Global.current_project.undo_redo.add_undo_method(Global, "undo")
	Global.current_project.undo_redo.add_do_method(Global, "redo")
	Global.current_project.undo_redo.commit_action()
