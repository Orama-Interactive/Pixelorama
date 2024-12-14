extends Button

enum MenuOptions { PROPERTIES, DELETE, LINK, UNLINK }

var frame := 0
var layer := 0
var cel: BaseCel

var _is_guide_stylebox := false

@onready var popup_menu: PopupMenu = get_node_or_null("PopupMenu")
@onready var linked_rect: ColorRect = $Linked
@onready var cel_texture: TextureRect = $CelTexture
@onready var transparent_checker: ColorRect = $CelTexture/TransparentChecker
@onready var properties: AcceptDialog = Global.control.find_child("CelProperties")


func _ready() -> void:
	Global.cel_switched.connect(cel_switched)
	Themes.theme_switched.connect(cel_switched.bind(true))
	cel = Global.current_project.frames[frame].cels[layer]
	button_setup()
	_dim_checker()
	cel.texture_changed.connect(_dim_checker)
	for selected in Global.current_project.selected_cels:
		if selected[1] == layer and selected[0] == frame:
			button_pressed = true
	if cel is PixelCel:
		popup_menu.add_item("Delete")
		popup_menu.add_item("Link Cels to")
		popup_menu.add_item("Unlink Cels")
	elif cel is GroupCel:
		transparent_checker.visible = false
	elif cel is AudioCel:
		popup_menu.add_item("Play audio here")
		_is_playing_audio()
		Global.cel_switched.connect(_is_playing_audio)
		Themes.theme_switched.connect(_is_playing_audio)
		Global.current_project.fps_changed.connect(_is_playing_audio)
		Global.current_project.layers[layer].audio_changed.connect(_is_playing_audio)
		Global.current_project.layers[layer].playback_frame_changed.connect(_is_playing_audio)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		tooltip_text = (
			tr("Frame: %s, Layer: %s") % [frame + 1, Global.current_project.layers[layer].name]
		)


func cel_switched(force_stylebox_change := false) -> void:
	z_index = 1 if button_pressed else 0
	var current_theme := Global.control.theme
	var is_guide := false
	for selected in Global.current_project.selected_cels:
		if selected[1] == layer or selected[0] == frame:
			is_guide = true
			break
	if is_guide:
		if not _is_guide_stylebox or force_stylebox_change:
			var guide_stylebox := current_theme.get_stylebox("guide", "CelButton")
			add_theme_stylebox_override("normal", guide_stylebox)
			_is_guide_stylebox = true
	else:
		if _is_guide_stylebox or force_stylebox_change:
			var normal_stylebox := current_theme.get_stylebox("normal", "CelButton")
			add_theme_stylebox_override("normal", normal_stylebox)
			_is_guide_stylebox = false


func button_setup() -> void:
	custom_minimum_size.x = Global.animation_timeline.cel_size
	custom_minimum_size.y = Global.animation_timeline.cel_size

	var base_layer := Global.current_project.layers[layer]
	tooltip_text = tr("Frame: %s, Layer: %s") % [frame + 1, base_layer.name]
	if cel is not AudioCel:
		cel_texture.texture = cel.image_texture
	if is_instance_valid(linked_rect):
		linked_rect.visible = cel.link_set != null
		if cel.link_set != null:
			linked_rect.color.h = cel.link_set["hue"]


func _on_CelButton_pressed() -> void:
	var project := Global.current_project
	if Input.is_action_just_released("left_mouse"):
		Global.canvas.selection.transform_content_confirm()
		var change_cel := true
		var prev_curr_frame: int = project.current_frame
		var prev_curr_layer: int = project.current_layer

		if Input.is_action_pressed("shift"):
			var frame_diff_sign := signi(frame - prev_curr_frame)
			if frame_diff_sign == 0:
				frame_diff_sign = 1
			var layer_diff_sign := signi(layer - prev_curr_layer)
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
		popup_menu.popup_on_parent(Rect2(get_global_mouse_position(), Vector2.ONE))
		button_pressed = !button_pressed
	elif Input.is_action_just_released("middle_mouse"):
		button_pressed = !button_pressed
		_delete_cel_content()
	else:  # An example of this would be Space
		button_pressed = !button_pressed


func _on_PopupMenu_id_pressed(id: int) -> void:
	match id:
		MenuOptions.PROPERTIES:
			properties.cel_indices = _get_cel_indices()
			properties.popup_centered()
		MenuOptions.DELETE:
			var layer_class := Global.current_project.layers[layer]
			if layer_class is AudioLayer:
				layer_class.playback_frame = frame
			else:
				_delete_cel_content()

		MenuOptions.LINK, MenuOptions.UNLINK:
			var project := Global.current_project
			if id == MenuOptions.UNLINK:
				project.undo_redo.create_action("Unlink Cel")
				var selected_cels := _get_cel_indices(true)
				if not selected_cels.has([frame, layer]):
					selected_cels.append([frame, layer])  # Include this cel with the selected ones
				for cel_index in selected_cels:
					if layer != cel_index[1]:  # Skip selected cels not on the same layer
						continue
					var s_cel := project.frames[cel_index[0]].cels[cel_index[1]]
					if s_cel.link_set == null:  # Skip cels that aren't linked
						continue
					project.undo_redo.add_do_method(
						project.layers[layer].link_cel.bind(s_cel, null)
					)
					project.undo_redo.add_undo_method(
						project.layers[layer].link_cel.bind(s_cel, s_cel.link_set)
					)
					if s_cel.link_set.size() > 1:  # Skip copying content if not linked to another
						project.undo_redo.add_do_method(
							s_cel.set_content.bind(s_cel.copy_content(), ImageTexture.new())
						)
						project.undo_redo.add_undo_method(
							s_cel.set_content.bind(s_cel.get_content(), s_cel.image_texture)
						)

			elif id == MenuOptions.LINK:
				project.undo_redo.create_action("Link Cel")
				var link_set: Dictionary = {} if cel.link_set == null else cel.link_set
				if cel.link_set == null:
					project.undo_redo.add_do_method(
						project.layers[layer].link_cel.bind(cel, link_set)
					)
					project.undo_redo.add_undo_method(
						project.layers[layer].link_cel.bind(cel, null)
					)

				for cel_index in project.selected_cels:
					if layer != cel_index[1]:  # Skip selected cels not on the same layer
						continue
					var s_cel := project.frames[cel_index[0]].cels[cel_index[1]]
					if cel == s_cel:  # Don't need to link cel to itself
						continue
					if s_cel.link_set == link_set:  # Skip cels that were already linked
						continue
					project.undo_redo.add_do_method(
						project.layers[layer].link_cel.bind(s_cel, link_set)
					)
					project.undo_redo.add_undo_method(
						project.layers[layer].link_cel.bind(s_cel, s_cel.link_set)
					)
					project.undo_redo.add_do_method(
						s_cel.set_content.bind(cel.get_content(), cel.image_texture)
					)
					project.undo_redo.add_undo_method(
						s_cel.set_content.bind(s_cel.get_content(), s_cel.image_texture)
					)

			# Remove and add a new cel button to update appearance (can't use button_setup
			# because there is no guarantee that it will be the exact same cel button instance)
			# May be able to use button_setup with a lambda to find correct cel button in Godot 4
			for f in project.frames.size():
				project.undo_redo.add_do_method(
					Global.animation_timeline.project_cel_removed.bind(f, layer)
				)
				project.undo_redo.add_undo_method(
					Global.animation_timeline.project_cel_removed.bind(f, layer)
				)
				project.undo_redo.add_do_method(
					Global.animation_timeline.project_cel_added.bind(f, layer)
				)
				project.undo_redo.add_undo_method(
					Global.animation_timeline.project_cel_added.bind(f, layer)
				)

			project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
			project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
			project.undo_redo.commit_action()


func _delete_cel_content() -> void:
	var indices := _get_cel_indices()
	var project := Global.current_project
	project.undos += 1
	project.undo_redo.create_action("Draw")
	for cel_index in indices:
		var frame_index: int = cel_index[0]
		var layer_index: int = cel_index[1]
		var selected_cel := project.frames[frame_index].cels[layer_index]
		var empty_content = selected_cel.create_empty_content()
		var old_content = selected_cel.get_content()
		if selected_cel.link_set == null:
			project.undo_redo.add_do_method(selected_cel.set_content.bind(empty_content))
			project.undo_redo.add_undo_method(selected_cel.set_content.bind(old_content))
		else:
			for linked_cel in selected_cel.link_set["cels"]:
				project.undo_redo.add_do_method(linked_cel.set_content.bind(empty_content))
				project.undo_redo.add_undo_method(linked_cel.set_content.bind(old_content))
		project.undo_redo.add_do_method(
			Global.undo_or_redo.bind(false, frame_index, layer_index, project)
		)
		project.undo_redo.add_undo_method(
			Global.undo_or_redo.bind(true, frame_index, layer_index, project)
		)
	project.undo_redo.commit_action()


func _dim_checker() -> void:
	var image := cel.get_image()
	if image == null:
		return
	if image.is_empty() or image.is_invisible():
		transparent_checker.visible = false
	else:
		transparent_checker.visible = true


func _get_drag_data(_position: Vector2) -> Variant:
	var button := Button.new()
	button.size = size
	button.theme = Global.control.theme
	var texture_rect := TextureRect.new()
	texture_rect.size = cel_texture.size
	texture_rect.position = cel_texture.position
	texture_rect.expand = true
	texture_rect.texture = cel_texture.texture
	button.add_child(texture_rect)
	set_drag_preview(button)
	return ["Cel", _get_cel_indices()]


func _can_drop_data(_pos: Vector2, data) -> bool:
	var project := Global.current_project
	if typeof(data) != TYPE_ARRAY:
		Global.animation_timeline.drag_highlight.visible = false
		return false
	if data[0] != "Cel":
		Global.animation_timeline.drag_highlight.visible = false
		return false
	var drop_cels: Array = data[1]
	drop_cels.sort_custom(_sort_cel_indices_by_frame)
	var drop_frames: PackedInt32Array = []
	var drop_layers: PackedInt32Array = []
	for cel_idx in drop_cels:
		drop_frames.append(cel_idx[0])
		drop_layers.append(cel_idx[1])
	# Can't move to the same cel
	for drop_frame in drop_frames:
		if drop_frame == frame and drop_layers[-1] == layer:
			Global.animation_timeline.drag_highlight.visible = false
			return false
	# Can't move different types of layers between them
	for drop_layer in drop_layers:
		if project.layers[drop_layer].get_script() != project.layers[layer].get_script():
			Global.animation_timeline.drag_highlight.visible = false
			return false

	var drop_layer := drop_layers[0]
	# Check if all dropped cels are on the same layer
	var different_layers := false
	for l in drop_layers:
		if l != layer:
			different_layers = true
	# Check if any of the dropped cels are linked
	var are_dropped_cels_linked := false
	for f in drop_frames:
		if project.frames[f].cels[drop_layer].link_set != null:
			are_dropped_cels_linked = true

	if (  # If both cels are on the same layer, or both are not linked
		drop_layer == layer
		or (project.frames[frame].cels[layer].link_set == null and not are_dropped_cels_linked)
	):
		var region: Rect2
		if Input.is_action_pressed("ctrl") or different_layers:  # Swap cels
			region = get_global_rect()
		else:  # Move cels
			if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):  # Left
				region = _get_region_rect(-0.125, 0.125)
				region.position.x -= 2  # Container spacing
			else:  # Right
				region = _get_region_rect(0.875, 1.125)
				region.position.x += 2  # Container spacing
		Global.animation_timeline.drag_highlight.global_position = region.position
		Global.animation_timeline.drag_highlight.size = region.size
		Global.animation_timeline.drag_highlight.visible = true
		return true

	Global.animation_timeline.drag_highlight.visible = false
	return false


func _drop_data(_pos: Vector2, data) -> void:
	var drop_cels: Array = data[1]
	drop_cels.sort_custom(_sort_cel_indices_by_frame)
	var drop_frames: PackedInt32Array = []
	var drop_layers: PackedInt32Array = []
	for cel_idx in drop_cels:
		drop_frames.append(cel_idx[0])
		drop_layers.append(cel_idx[1])
	var drop_layer := drop_layers[0]
	var different_layers := false
	for l in drop_layers:
		if l != layer:
			different_layers = true

	var project := Global.current_project
	project.undo_redo.create_action("Move Cels")
	if Input.is_action_pressed("ctrl") or different_layers:  # Swap cels
		project.undo_redo.add_do_method(
			project.swap_cel.bind(frame, layer, drop_frames[0], drop_layer)
		)
		project.undo_redo.add_undo_method(
			project.swap_cel.bind(frame, layer, drop_frames[0], drop_layer)
		)
	else:  # Move cels
		var to_frame: int
		if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):  # Left
			to_frame = frame
		else:  # Right
			to_frame = frame + 1
		for drop_frame in drop_frames:
			if drop_frame < frame:
				to_frame -= 1
		var to_frames := range(to_frame, to_frame + drop_frames.size())
		project.undo_redo.add_do_method(
			project.move_cels_same_layer.bind(drop_frames, to_frames, layer)
		)
		project.undo_redo.add_undo_method(
			project.move_cels_same_layer.bind(to_frames, drop_frames, layer)
		)

	project.undo_redo.add_do_method(project.change_cel.bind(frame, layer))
	project.undo_redo.add_undo_method(
		project.change_cel.bind(project.current_frame, project.current_layer)
	)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.commit_action()


func _get_region_rect(x_begin: float, x_end: float) -> Rect2:
	var rect := get_global_rect()
	rect.position.x += rect.size.x * x_begin
	rect.size.x *= x_end - x_begin
	return rect


func _get_cel_indices(add_current_cel := false) -> Array:
	var indices := Global.current_project.selected_cels.duplicate()
	if not [frame, layer] in indices:
		if add_current_cel:
			indices.append([frame, layer])
		else:
			indices = [[frame, layer]]
	return indices


func _sort_cel_indices_by_frame(a: Array, b: Array) -> bool:
	var frame_a: int = a[0]
	var frame_b: int = b[0]
	if frame_a < frame_b:
		return true
	return false


func _is_playing_audio() -> void:
	var project := Global.current_project
	var frame_class := project.frames[frame]
	var layer_class := project.layers[layer] as AudioLayer
	var audio_length := layer_class.get_audio_length()
	var frame_pos := frame_class.position_in_seconds(project, layer_class.playback_frame)
	var audio_color := Color.LIGHT_GRAY
	var pressed_stylebox := Global.control.theme.get_stylebox(&"pressed", &"CelButton")
	if pressed_stylebox is StyleBoxFlat:
		audio_color = pressed_stylebox.border_color
	var is_last_frame := frame + 1 >= project.frames.size()
	if not is_last_frame:
		is_last_frame = (
			project.frames[frame + 1].position_in_seconds(project, layer_class.playback_frame)
			>= audio_length
		)
	if frame_pos == 0 or (is_last_frame and frame_pos < audio_length):
		cel_texture.texture = preload("res://assets/graphics/misc/musical_note.png")
		cel_texture.self_modulate = audio_color
		linked_rect.visible = false
	else:
		linked_rect.visible = frame_pos < audio_length and frame_pos > 0
		linked_rect.color = audio_color
		cel_texture.texture = null
