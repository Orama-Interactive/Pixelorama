extends Button

enum MenuOptions { DELETE, LINK, PROPERTIES }

var frame := 0
var layer := 0
var cel: PixelCel

onready var popup_menu: PopupMenu = $PopupMenu
onready var linked_indicator: Polygon2D = $LinkedIndicator

func _ready() -> void:
	button_setup()


func button_setup() -> void:
	rect_min_size.x = Global.animation_timeline.cel_size
	rect_min_size.y = Global.animation_timeline.cel_size

	hint_tooltip = tr("Frame: %s, Layer: %s") % [frame + 1, layer]
	if Global.current_project.frames[frame] in Global.current_project.layers[layer].linked_cels:
		linked_indicator.visible = true
		popup_menu.set_item_text(MenuOptions.LINK, "Unlink Cel")
		popup_menu.set_item_metadata(MenuOptions.LINK, "Unlink Cel")
	else:
		linked_indicator.visible = false
		popup_menu.set_item_text(MenuOptions.LINK, "Link Cel")
		popup_menu.set_item_metadata(MenuOptions.LINK, "Link Cel")

	# Reset the checkers size because it assumes you want the same size as the canvas
	var checker = $CelTexture/TransparentChecker
	checker.rect_size = checker.get_parent().rect_size
	cel = Global.current_project.frames[frame].cels[layer]


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
			var project: Project = Global.current_project
			var f: Frame = project.frames[frame]
			var cel_index: int = project.layers[layer].linked_cels.find(f)
			# TODO H0: If my content methods idea is used, I think new_cels won't need to exist
			#			Will new_layers be needed either?
			var new_layers: Array = project.duplicate_layers()
			var new_cels: Array = f.cels.duplicate()
			# TODO H: Make sure all this works with group layers:
			for i in new_cels.size():
				# TODO H: This doesn't work (currently replaces ALL cels on the frame)
				new_cels[i] = PixelCel.new(
					new_cels[i].image, new_cels[i].opacity, new_cels[i].image_texture
				)
			# TODO H: Make sure all this works with group layers:
			if popup_menu.get_item_metadata(MenuOptions.LINK) == "Unlink Cel":
				new_layers[layer].linked_cels.remove(cel_index)
				project.undo_redo.create_action("Unlink Cel")
				var cel: BaseCel = project.frames[frame].cels[layer]
				project.undo_redo.add_do_property(cel, "image_texture", ImageTexture.new())
				project.undo_redo.add_undo_property(cel, "image_texture", cel.image_texture)
				project.undo_redo.add_do_method(cel, "set_content", cel.copy_content())
				project.undo_redo.add_undo_method(cel, "set_content", cel.get_content())

			elif popup_menu.get_item_metadata(MenuOptions.LINK) == "Link Cel":
				new_layers[layer].linked_cels.append(f)
				project.undo_redo.create_action("Link Cel")
				if new_layers[layer].linked_cels.size() > 1:
					# If there are already linked cels, set the current cel's image
					# to the first linked cel's image
					var cel: BaseCel = project.frames[frame].cels[layer]
					var linked_cel: BaseCel = project.layers[layer].linked_cels[0].cels[layer]
					project.undo_redo.add_do_property(cel, "image_texture", linked_cel.image_texture)
					project.undo_redo.add_undo_property(cel, "image_texture", cel.image_texture)
					project.undo_redo.add_do_method(cel, "set_content", linked_cel.get_content())
					project.undo_redo.add_undo_method(cel, "set_content", cel.get_content())

			project.undo_redo.add_do_property(project, "layers", new_layers)
			project.undo_redo.add_undo_property(project, "layers", project.layers)
			# Remove and add a new cel button to update appearance (can't use self.button_setup
			# because there is no guarantee that it will be the exact same cel button instance)
			project.undo_redo.add_do_method(Global.animation_timeline, "project_cel_removed", frame, layer)
			project.undo_redo.add_undo_method(Global.animation_timeline, "project_cel_removed", frame, layer)
			project.undo_redo.add_do_method(Global.animation_timeline, "project_cel_added", frame, layer)
			project.undo_redo.add_undo_method(Global.animation_timeline, "project_cel_added", frame, layer)

			project.undo_redo.add_do_method(Global, "undo_or_redo", false)
			project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
			project.undo_redo.commit_action()


func _delete_cel_content() -> void:
	var project = Global.current_project
	var cel: BaseCel = project.frames[frame].cels[layer]
	var empty_content = cel.create_empty_content()
	var old_content = cel.get_content()
	project.undos += 1
	project.undo_redo.create_action("Draw")
	if project.frames[frame] in project.layers[layer].linked_cels:
		for frame in project.layers[layer].linked_cels:
			project.undo_redo.add_do_method(frame.cels[layer], "set_content", empty_content)
			project.undo_redo.add_undo_method(frame.cels[layer], "set_content", old_content)
	else:
		project.undo_redo.add_do_method(cel, "set_content", empty_content)
		project.undo_redo.add_undo_method(cel, "set_content", old_content)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false, frame, layer, project)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true, frame, layer, project)
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
		# TODO L: Is this part really right? Should't it only matter if they're linked, and we're changing layers?
		#		It would need to add linked cel logic to project move/swap_cel though
		# If the cel we're dragging or the cel we are targeting are linked, don't allow dragging
		if not (
			Global.current_project.frames[frame] in Global.current_project.layers[layer].linked_cels
			or (
				Global.current_project.frames[drag_frame]
				in Global.current_project.layers[drag_layer].linked_cels
			)
		):
			# TODO L: This may be able to be combined with the previous condition depending on the the last TODO
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

	project.undo_redo.create_action("Move Cels")
	if Input.is_action_pressed("ctrl") or layer != drop_layer: # Swap cels
		project.undo_redo.add_do_method(project, "swap_cel", frame, layer, drop_frame, drop_layer)
		project.undo_redo.add_undo_method(project, "swap_cel", frame, layer, drop_frame, drop_layer)
	else: # Move cels
		var to_frame: int
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
