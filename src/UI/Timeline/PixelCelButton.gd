extends Button

enum MenuOptions { DELETE, LINK, PROPERTIES }

var frame := 0
var layer := 0
var cel: PixelCel
var image: Image

onready var popup_menu: PopupMenu = $PopupMenu


func _ready() -> void:
	button_setup()


func button_setup() -> void:
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
	var project = Global.current_project
	if Input.is_action_just_released("left_mouse"):
		Global.canvas.selection.transform_content_confirm()
		var change_cel := true
		var prev_curr_frame: int = project.current_frame
		var prev_curr_layer: int = project.current_layer

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
		else:  # If the button is pressed without Shift or Control
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
		_delete_cel_content()
	else:  # An example of this would be Space
		pressed = !pressed


func _on_PopupMenu_id_pressed(id: int) -> void:
	match id:
		MenuOptions.DELETE:
			_delete_cel_content()

		MenuOptions.LINK:
			# TODO: See if there is any refactoring to do here:
			var f: Frame = Global.current_project.frames[frame]
			var cel_index: int = Global.current_project.layers[layer].linked_cels.find(f)
			var new_layers: Array = Global.current_project.duplicate_layers()
			var new_cels: Array = f.cels.duplicate()
			for i in new_cels.size():
				# TODO: This doesn't work
				new_cels[i] = PixelCel.new(
					new_cels[i].image, new_cels[i].opacity, new_cels[i].image_texture
				)
# TODO: Make sure all this stuff still works after refactor:
			if popup_menu.get_item_metadata(MenuOptions.LINK) == "Unlink Cel":
				new_layers[layer].linked_cels.remove(cel_index)
				var sprite := Image.new()
				sprite.copy_from(f.cels[layer].image)
				var sprite_texture := ImageTexture.new()
				sprite_texture.create_from_image(sprite, 0)
				new_cels[layer].image = sprite
				new_cels[layer].image_texture = sprite_texture

				Global.current_project.undo_redo.create_action("Unlink Cel")
				Global.current_project.undo_redo.add_do_property(
					Global.current_project, "layers", new_layers
				)
				Global.current_project.undo_redo.add_do_property(f, "cels", new_cels)
				Global.current_project.undo_redo.add_undo_property(
					Global.current_project, "layers", Global.current_project.layers
				)
				Global.current_project.undo_redo.add_undo_property(f, "cels", f.cels)

				Global.current_project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
				Global.current_project.undo_redo.add_do_method(Global, "undo_or_redo", false)
				Global.current_project.undo_redo.commit_action()

			elif popup_menu.get_item_metadata(MenuOptions.LINK) == "Link Cel":
				new_layers[layer].linked_cels.append(f)
				Global.current_project.undo_redo.create_action("Link Cel")
				Global.current_project.undo_redo.add_do_property(
					Global.current_project, "layers", new_layers
				)
				if new_layers[layer].linked_cels.size() > 1:
					# If there are already linked cels, set the current cel's image
					# to the first linked cel's image
					new_cels[layer].image = new_layers[layer].linked_cels[0].cels[layer].image
					new_cels[layer].image_texture = new_layers[layer].linked_cels[0].cels[layer].image_texture
					Global.current_project.undo_redo.add_do_property(f, "cels", new_cels)
					Global.current_project.undo_redo.add_undo_property(f, "cels", f.cels)

				Global.current_project.undo_redo.add_undo_property(
					Global.current_project, "layers", Global.current_project.layers
				)
				Global.current_project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
				Global.current_project.undo_redo.add_do_method(Global, "undo_or_redo", false)
				Global.current_project.undo_redo.commit_action()


func _delete_cel_content() -> void:
	if image.is_invisible():
		return
	var curr_layer: PixelLayer = Global.current_project.layers[layer]
	if !curr_layer.can_layer_get_drawn():
		return
	var project = Global.current_project
	image.unlock()
	var data := image.data
	project.undos += 1
	project.undo_redo.create_action("Draw")
	project.undo_redo.add_undo_property(image, "data", data)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true, frame, layer, project)
	image.fill(0)
	project.undo_redo.add_do_property(image, "data", image.data)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false, frame, layer, project)
	project.undo_redo.commit_action()


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

	return ["PixelCel", frame, layer]


func can_drop_data(_pos, data) -> bool:
	if typeof(data) == TYPE_ARRAY and data[0] == "PixelCel":
		var drag_frame = data[1]
		var drag_layer = data[2]
		# TODO: Is this part really right? Should't it only matter if they're linked, and we're changing layers?
		#		It would need to add linked cel logic to project move/swap_cel though
		# If the cel we're dragging or the cel we are targeting are linked, don't allow dragging
		if not (
			Global.current_project.frames[frame] in Global.current_project.layers[layer].linked_cels
			or (
				Global.current_project.frames[drag_frame]
				in Global.current_project.layers[drag_layer].linked_cels
			)
		):
			# TODO: This may be able to be combined with the previous condition depending on the the last TODO
			if not (drag_frame == frame and drag_layer == layer):
				var region: Rect2
				if Input.is_action_pressed("ctrl") or layer != drag_layer: # Swap cels
					region = get_global_rect()
				else: # Move cels
					if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()): # Left
						region = _get_region_rect(-0.125, 0.125)
						region.position.x -= 2  # Container spacing
					else: # Right
						region = _get_region_rect(0.875, 1.125)
						region.position.x += 2  # Container spacing
				Global.animation_timeline.drag_highlight.rect_global_position = region.position
				Global.animation_timeline.drag_highlight.rect_size = region.size
				Global.animation_timeline.drag_highlight.visible = true
				return true

	Global.animation_timeline.drag_highlight.visible = false
	return false


func drop_data(_pos, data) -> void:
	var drop_frame = data[1]
	var drop_layer = data[2]
	var project = Global.current_project

#	var this_frame_new_cels = project.frames[frame].cels.duplicate()
#	var drop_frame_new_cels
#	var temp = this_frame_new_cels[layer]
#	this_frame_new_cels[layer] = project.frames[drop_frame].cels[drop_layer]
#	if frame == drop_frame:
#		this_frame_new_cels[drop_layer] = temp
#	else:
#		drop_frame_new_cels = project.frames[drop_frame].cels.duplicate()
#		drop_frame_new_cels[drop_layer] = temp

	project.undo_redo.create_action("Move Cels")
#	project.undo_redo.add_do_property(
#		project.frames[frame], "cels", this_frame_new_cels
#	)
#
#	project.undo_redo.add_do_property(project, "current_layer", layer)
#	project.undo_redo.add_undo_property(
#		project, "current_layer", project.current_layer
#	)
#
#	if frame != drop_frame:  # If the cel moved to a different frame
#		project.undo_redo.add_do_property(
#			project.frames[drop_frame], "cels", drop_frame_new_cels
#		)
#
#		project.undo_redo.add_do_property(
#			project, "current_frame", frame
#		)
#		project.undo_redo.add_undo_property(
#			project, "current_frame", project.current_frame
#		)
#
#		project.undo_redo.add_undo_property(
#			project.frames[drop_frame],
#			"cels",
#			project.frames[drop_frame].cels
#		)
#
#	project.undo_redo.add_undo_property(
#		project.frames[frame], "cels", project.frames[frame].cels
#	)

	if Input.is_action_pressed("ctrl") or layer != drop_layer: # Swap cels
		project.undo_redo.add_do_method(project, "swap_cel", frame, layer, drop_frame, drop_layer)
		project.undo_redo.add_undo_method(project, "swap_cel", frame, layer, drop_frame, drop_layer)
	else: # Move cels
		var to_frame: int
		# TODO: Test that this is correct: (after cel button ui changes)
		# TODO: This breaks sometimes (after several tests usually), I'm not sure what the condition it breaks in is, maybe need to draw it out?
		#		(This is probably an error in the project.move_cel function)
		if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()): # Left
			to_frame = frame
		else: # Right
			to_frame = frame + 1
		if drop_frame < frame:
			to_frame -= 1
		project.undo_redo.add_do_method(project, "move_cel", drop_frame, to_frame, layer)
		project.undo_redo.add_undo_method(project, "move_cel", to_frame, drop_frame, layer)

	project.undo_redo.add_do_property(project, "current_layer", layer)
	project.undo_redo.add_undo_property(project, "current_layer", project.current_layer)
	if frame != drop_frame:  # If the cel moved to a different frame
		project.undo_redo.add_do_property(project, "current_frame", frame)
		project.undo_redo.add_undo_property(project, "current_frame", project.current_frame)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.commit_action()


func _get_region_rect(x_begin: float, x_end: float) -> Rect2:
	var rect := get_global_rect()
	rect.position.x += rect.size.x * x_begin
	rect.size.x *= x_end - x_begin
	return rect
