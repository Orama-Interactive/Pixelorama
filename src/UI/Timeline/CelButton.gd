extends Button

enum MenuOptions { DELETE, LINK, UNLINK, PROPERTIES }

var frame := 0
var layer := 0
var cel: BaseCel

onready var popup_menu: PopupMenu = get_node_or_null("PopupMenu")
onready var linked_indicator: Polygon2D = get_node_or_null("LinkedIndicator")


func _ready() -> void:
	button_setup()


func button_setup() -> void:
	rect_min_size.x = Global.animation_timeline.cel_size
	rect_min_size.y = Global.animation_timeline.cel_size

	hint_tooltip = tr("Frame: %s, Layer: %s") % [frame + 1, layer]
	cel = Global.current_project.frames[frame].cels[layer]
	if is_instance_valid(linked_indicator):
		linked_indicator.visible = cel.link_group != null
		if cel.link_group != null:
			var cel_link_groups: Array = Global.current_project.layers[layer].cel_link_groups
			var link_group_index = cel_link_groups.find(cel.link_group)
			linked_indicator.color.h = float(link_group_index) / max(cel_link_groups.size(), 6) # TODO: Improve
#			linked_indicator.color.v *= min(1, (1 / linked_indicator.color.get_luminance()) * 0.75)  # Trick to make them all about the same luminance
			print("Index: ", float(link_group_index), "  Size: ", cel_link_groups.size(), "  Max: ", max(cel_link_groups.size(), 6), "  Hue: ", linked_indicator.color.h)

	# Reset the checkers size because it assumes you want the same size as the canvas
	var checker = $CelTexture/TransparentChecker
	checker.rect_size = checker.get_parent().rect_size


func _on_CelButton_resized() -> void:
	get_node("CelTexture").rect_min_size.x = rect_min_size.x - 4
	get_node("CelTexture").rect_min_size.y = rect_min_size.y - 4

	if is_instance_valid(linked_indicator):
		linked_indicator.polygon[1].x = rect_min_size.x
		linked_indicator.polygon[2].x = rect_min_size.x
		linked_indicator.polygon[2].y = rect_min_size.y
		linked_indicator.polygon[3].y = rect_min_size.y


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
		if is_instance_valid(popup_menu):
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

		MenuOptions.LINK, MenuOptions.UNLINK:
			var project: Project = Global.current_project
			if id == MenuOptions.UNLINK:
				project.undo_redo.create_action("Unlink Cel")
				var selected_cels = project.selected_cels.duplicate()
				if not selected_cels.has([frame, layer]):
					selected_cels.append([frame, layer])
				for cel_index in selected_cels:
					if layer != cel_index[1]:  # Skip selected cels not on the same layer
						continue
					var selected_cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
					if selected_cel.link_group == null:  # Skip cels that aren't linked
						continue
					project.undo_redo.add_do_method(project.layers[layer], "unlink_cel", selected_cel)
					project.undo_redo.add_undo_method(project.layers[layer], "link_cel", selected_cel, selected_cel.link_group)
					if selected_cel.link_group.size() > 1:  # Skip copying content if not linked to another
						project.undo_redo.add_do_property(selected_cel, "image_texture", ImageTexture.new())
						project.undo_redo.add_undo_property(selected_cel, "image_texture", selected_cel.image_texture)
						project.undo_redo.add_do_method(selected_cel, "set_content", selected_cel.copy_content())
						project.undo_redo.add_undo_method(selected_cel, "set_content", selected_cel.get_content())

			elif id == MenuOptions.LINK:
				project.undo_redo.create_action("Link Cel")
				var link_group: Array = [] if cel.link_group == null else cel.link_group
				if cel.link_group == null:
					project.undo_redo.add_do_method(project.layers[layer], "link_cel", cel, link_group)
					project.undo_redo.add_undo_method(project.layers[layer], "unlink_cel", cel)

				for cel_index in project.selected_cels:
					if layer != cel_index[1]:  # Skip selected cels not on the same layer
						continue
					var selected_cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
					if cel == selected_cel:  # Don't need to link cel to itself
						continue
					if selected_cel.link_group == link_group:  # Skip cels that were already linked
						continue
					project.undo_redo.add_do_method(selected_cel, "set_content", cel.get_content())
					project.undo_redo.add_undo_method(selected_cel, "set_content", selected_cel.get_content())
					project.undo_redo.add_do_property(selected_cel, "image_texture", cel.image_texture)
					project.undo_redo.add_undo_property(selected_cel, "image_texture", selected_cel.image_texture)

					project.undo_redo.add_do_method(project.layers[layer], "link_cel", selected_cel, link_group)
					if selected_cel.link_group == null:
						project.undo_redo.add_undo_method(project.layers[layer], "unlink_cel", selected_cel)
					else:
						project.undo_redo.add_undo_method(project.layers[layer], "link_cel", selected_cel, selected_cel.link_group)

			# Remove and add a new cel button to update appearance (can't use button_setup
			# because there is no guarantee that it will be the exact same cel button instance)
			# May be able to use button_setup with a lambda to find correct cel button in Godot 4
			for f in project.frames.size():
				project.undo_redo.add_do_method(
					Global.animation_timeline, "project_cel_removed", f, layer
				)
				project.undo_redo.add_undo_method(
					Global.animation_timeline, "project_cel_removed", f, layer
				)
				project.undo_redo.add_do_method(
					Global.animation_timeline, "project_cel_added", f, layer
				)
				project.undo_redo.add_undo_method(
					Global.animation_timeline, "project_cel_added", f, layer
				)

			project.undo_redo.add_do_method(Global, "undo_or_redo", false)
			project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
			project.undo_redo.commit_action()


func _delete_cel_content() -> void:
	var project = Global.current_project
	var empty_content = cel.create_empty_content()
	var old_content = cel.get_content()
	project.undos += 1
	project.undo_redo.create_action("Draw")
	if cel.link_group == null:
		project.undo_redo.add_do_method(cel, "set_content", empty_content)
		project.undo_redo.add_undo_method(cel, "set_content", old_content)
	else:
		for linked_cel in cel.link_group:
			project.undo_redo.add_do_method(linked_cel, "set_content", empty_content)
			project.undo_redo.add_undo_method(linked_cel, "set_content", old_content)
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

	return ["Cel", frame, layer]


func can_drop_data(_pos, data) -> bool:
	var project: Project = Global.current_project
	if typeof(data) == TYPE_ARRAY and data[0] == "Cel":
		var drag_frame = data[1]
		var drag_layer = data[2]
		if project.layers[drag_layer].get_script() == project.layers[layer].get_script():
			if (
				project.layers[layer] is GroupLayer
				or not (
					(project.frames[frame] in project.layers[layer].linked_cels)
					or (project.frames[drag_frame] in project.layers[drag_layer].linked_cels)
				)
			):
				if not (drag_frame == frame and drag_layer == layer):
					var region: Rect2
					if Input.is_action_pressed("ctrl") or layer != drag_layer:  # Swap cels
						region = get_global_rect()
					else:  # Move cels
						if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):  # Left
							region = _get_region_rect(-0.125, 0.125)
							region.position.x -= 2  # Container spacing
						else:  # Right
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
	if Input.is_action_pressed("ctrl") or layer != drop_layer:  # Swap cels
		project.undo_redo.add_do_method(project, "swap_cel", frame, layer, drop_frame, drop_layer)
		project.undo_redo.add_undo_method(project, "swap_cel", frame, layer, drop_frame, drop_layer)
	else:  # Move cels
		var to_frame: int
		if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):  # Left
			to_frame = frame
		else:  # Right
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
