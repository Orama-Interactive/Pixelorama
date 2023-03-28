extends Button

enum MenuOptions { DELETE, LINK, UNLINK, PROPERTIES }

var frame := 0
var layer := 0
var cel: BaseCel

onready var popup_menu: PopupMenu = get_node_or_null("PopupMenu")
onready var linked_indicator: Polygon2D = get_node_or_null("LinkedIndicator")
onready var cel_texture: TextureRect = $CelTexture
onready var transparent_checker: ColorRect = $CelTexture/TransparentChecker


func _ready() -> void:
	cel = Global.current_project.frames[frame].cels[layer]
	button_setup()
	_dim_checker()
	cel.connect("texture_changed", self, "_dim_checker")


func button_setup() -> void:
	rect_min_size.x = Global.animation_timeline.cel_size
	rect_min_size.y = Global.animation_timeline.cel_size

	var base_layer: BaseLayer = Global.current_project.layers[layer]
	hint_tooltip = tr("Frame: %s, Layer: %s") % [frame + 1, base_layer.name]
	cel_texture.texture = cel.image_texture
	if is_instance_valid(linked_indicator):
		linked_indicator.visible = cel.link_set != null
		if cel.link_set != null:
			linked_indicator.color.h = cel.link_set["hue"]

	# Reset the checkers size because it assumes you want the same size as the canvas
	transparent_checker.rect_size = transparent_checker.get_parent().rect_size


func _on_CelButton_resized() -> void:
	cel_texture.rect_min_size.x = rect_min_size.x - 4
	cel_texture.rect_min_size.y = rect_min_size.y - 4

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
			project.change_cel(frame, layer)
		else:
			project.change_cel(project.selected_cels[0][0], project.selected_cels[0][1])
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
					selected_cels.append([frame, layer])  # Include this cel with the selected ones
				for cel_index in selected_cels:
					if layer != cel_index[1]:  # Skip selected cels not on the same layer
						continue
					var s_cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
					if s_cel.link_set == null:  # Skip cels that aren't linked
						continue
					project.undo_redo.add_do_method(project.layers[layer], "link_cel", s_cel, null)
					project.undo_redo.add_undo_method(
						project.layers[layer], "link_cel", s_cel, s_cel.link_set
					)
					if s_cel.link_set.size() > 1:  # Skip copying content if not linked to another
						project.undo_redo.add_do_method(
							s_cel, "set_content", s_cel.copy_content(), ImageTexture.new()
						)
						project.undo_redo.add_undo_method(
							s_cel, "set_content", s_cel.get_content(), s_cel.image_texture
						)

			elif id == MenuOptions.LINK:
				project.undo_redo.create_action("Link Cel")
				var link_set: Dictionary = {} if cel.link_set == null else cel.link_set
				if cel.link_set == null:
					project.undo_redo.add_do_method(
						project.layers[layer], "link_cel", cel, link_set
					)
					project.undo_redo.add_undo_method(project.layers[layer], "link_cel", cel, null)

				for cel_index in project.selected_cels:
					if layer != cel_index[1]:  # Skip selected cels not on the same layer
						continue
					var s_cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
					if cel == s_cel:  # Don't need to link cel to itself
						continue
					if s_cel.link_set == link_set:  # Skip cels that were already linked
						continue
					project.undo_redo.add_do_method(
						project.layers[layer], "link_cel", s_cel, link_set
					)
					project.undo_redo.add_undo_method(
						project.layers[layer], "link_cel", s_cel, s_cel.link_set
					)
					project.undo_redo.add_do_method(
						s_cel, "set_content", cel.get_content(), cel.image_texture
					)
					project.undo_redo.add_undo_method(
						s_cel, "set_content", s_cel.get_content(), s_cel.image_texture
					)

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
	var project: Project = Global.current_project
	var empty_content = cel.create_empty_content()
	var old_content = cel.get_content()
	project.undos += 1
	project.undo_redo.create_action("Draw")
	if cel.link_set == null:
		project.undo_redo.add_do_method(cel, "set_content", empty_content)
		project.undo_redo.add_undo_method(cel, "set_content", old_content)
	else:
		for linked_cel in cel.link_set["cels"]:
			project.undo_redo.add_do_method(linked_cel, "set_content", empty_content)
			project.undo_redo.add_undo_method(linked_cel, "set_content", old_content)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false, frame, layer, project)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true, frame, layer, project)
	project.undo_redo.commit_action()


func _dim_checker() -> void:
	var image := cel.get_image()
	if image == null:
		return
	if image.is_empty() or image.is_invisible():
		transparent_checker.self_modulate.a = 0.5
	else:
		transparent_checker.self_modulate.a = 1.0


func get_drag_data(_position: Vector2) -> Array:
	var button := Button.new()
	button.rect_size = rect_size
	button.theme = Global.control.theme
	var texture_rect := TextureRect.new()
	texture_rect.rect_size = cel_texture.rect_size
	texture_rect.rect_position = cel_texture.rect_position
	texture_rect.expand = true
	texture_rect.texture = cel_texture.texture
	button.add_child(texture_rect)
	set_drag_preview(button)

	return ["Cel", frame, layer]


func can_drop_data(_pos: Vector2, data) -> bool:
	var project: Project = Global.current_project
	if typeof(data) == TYPE_ARRAY and data[0] == "Cel":
		var drag_frame = data[1]
		var drag_layer = data[2]
		if project.layers[drag_layer].get_script() == project.layers[layer].get_script():
			if (  # If both cels are on the same layer, or both are not linked
				drag_layer == layer
				or (
					project.frames[frame].cels[layer].link_set == null
					and project.frames[drag_frame].cels[drag_layer].link_set == null
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


func drop_data(_pos: Vector2, data) -> void:
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

	project.undo_redo.add_do_method(project, "change_cel", frame, layer)
	project.undo_redo.add_undo_method(
		project, "change_cel", project.current_frame, project.current_layer
	)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.commit_action()


func _get_region_rect(x_begin: float, x_end: float) -> Rect2:
	var rect := get_global_rect()
	rect.position.x += rect.size.x * x_begin
	rect.size.x *= x_end - x_begin
	return rect
