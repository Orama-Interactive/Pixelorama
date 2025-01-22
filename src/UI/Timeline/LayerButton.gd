class_name LayerButton
extends HBoxContainer

const HIERARCHY_DEPTH_PIXEL_SHIFT := 16
const ARRAY_TEXTURE_TYPES: Array[Texture2D] = [
	preload("res://assets/graphics/layers/type_icons/layer_pixel.png"),
	preload("res://assets/graphics/layers/type_icons/layer_group.png"),
	preload("res://assets/graphics/layers/type_icons/layer_3d.png"),
	preload("res://assets/graphics/layers/type_icons/layer_tilemap.png"),
	preload("res://assets/graphics/layers/type_icons/layer_sound.png")
]

var layer_index := 0:
	set(value):
		layer_index = value
		if is_instance_valid(main_button):
			main_button.layer_index = value
var button_pressed := false:
	set(value):
		button_pressed = value
		main_button.button_pressed = value
	get:
		return main_button.button_pressed
var animation_running := false
var audio_playing_at_frame := 0

var audio_player: AudioStreamPlayer
@onready var properties: AcceptDialog = Global.control.find_child("LayerProperties")
@onready var main_button := %LayerMainButton as Button
@onready var expand_button := %ExpandButton as BaseButton
@onready var visibility_button := %VisibilityButton as BaseButton
@onready var lock_button := %LockButton as BaseButton
@onready var label := %LayerNameLabel as Label
@onready var line_edit := %LayerNameLineEdit as LineEdit
@onready var hierarchy_spacer := %HierarchySpacer as Control
@onready var layer_fx_texture_rect := %LayerFXTextureRect as TextureRect
@onready var layer_type_texture_rect := %LayerTypeTextureRect as TextureRect
@onready var linked_button := %LinkButton as BaseButton
@onready var clipping_mask_icon := %ClippingMask as TextureRect
@onready var popup_menu := $PopupMenu as PopupMenu


func _ready() -> void:
	main_button.layer_index = layer_index
	main_button.hierarchy_depth_pixel_shift = HIERARCHY_DEPTH_PIXEL_SHIFT
	Global.cel_switched.connect(_on_cel_switched)
	var layer := Global.current_project.layers[layer_index]
	layer.name_changed.connect(func(): label.text = layer.name)
	layer.visibility_changed.connect(_on_layer_visibility_changed)
	if layer is PixelLayer:
		linked_button.visible = true
	elif layer is GroupLayer:
		expand_button.visible = true
	elif layer is AudioLayer:
		audio_player = AudioStreamPlayer.new()
		audio_player.stream = layer.audio
		layer.audio_changed.connect(func(): audio_player.stream = layer.audio)
		add_child(audio_player)
		Global.animation_timeline.animation_started.connect(_on_animation_started)
		Global.animation_timeline.animation_looped.connect(_on_animation_looped)
		Global.animation_timeline.animation_finished.connect(_on_animation_finished)
	custom_minimum_size.y = Global.animation_timeline.cel_size
	label.text = layer.name
	line_edit.text = layer.name
	layer_fx_texture_rect.visible = layer.effects.size() > 0
	layer_type_texture_rect.texture = ARRAY_TEXTURE_TYPES[layer.get_layer_type()]
	layer.effects_added_removed.connect(
		func(): layer_fx_texture_rect.visible = layer.effects.size() > 0
	)
	for child in $HBoxContainer.get_children():
		if not child is Button:
			continue
		var texture := child.get_child(0)
		if not texture is TextureRect:
			continue
		texture.modulate = Global.modulate_icon_color

	# Visualize how deep into the hierarchy the layer is
	var hierarchy_depth := layer.get_hierarchy_depth()
	hierarchy_spacer.custom_minimum_size.x = hierarchy_depth * HIERARCHY_DEPTH_PIXEL_SHIFT
	update_buttons()


func _on_cel_switched() -> void:
	z_index = 1 if button_pressed else 0
	var project := Global.current_project
	var layer := project.layers[layer_index]
	if layer is AudioLayer:
		if not is_instance_valid(audio_player):
			return
		if not layer.is_visible_in_hierarchy():
			audio_player.stop()
			return
		if animation_running:
			var current_frame := project.current_frame
			if (
				current_frame == layer.playback_frame
				or (current_frame == 0 and layer.playback_frame < 0)
				## True when switching cels while the animation is running
				or current_frame != audio_playing_at_frame + 1
			):
				_play_audio(false)
			audio_playing_at_frame = current_frame
		else:
			_play_audio(true)


func _on_layer_visibility_changed() -> void:
	update_buttons()
	var layer := Global.current_project.layers[layer_index]
	if layer is AudioLayer:
		_play_audio(not animation_running)


func _on_animation_started(_dir: bool) -> void:
	animation_running = true
	_play_audio(false)


func _on_animation_looped() -> void:
	var layer := Global.current_project.layers[layer_index]
	if layer is AudioLayer:
		if layer.playback_frame > 0 or not layer.is_visible_in_hierarchy():
			if is_instance_valid(audio_player):
				audio_player.stop()


func _on_animation_finished() -> void:
	animation_running = false
	if is_instance_valid(audio_player):
		audio_player.stop()


func _play_audio(single_frame: bool) -> void:
	if not is_instance_valid(audio_player):
		return
	var project := Global.current_project
	var layer := project.layers[layer_index] as AudioLayer
	if not layer.is_visible_in_hierarchy():
		return
	var audio_length := layer.get_audio_length()
	var frame := project.frames[project.current_frame]
	var frame_pos := frame.position_in_seconds(project, layer.playback_frame)
	if frame_pos >= 0 and frame_pos < audio_length:
		audio_player.play(frame_pos)
		audio_playing_at_frame = project.current_frame
		if single_frame:
			var timer := get_tree().create_timer(frame.get_duration_in_seconds(project.fps))
			timer.timeout.connect(func(): audio_player.stop())
	else:
		audio_player.stop()


func update_buttons() -> void:
	var layer := Global.current_project.layers[layer_index]
	if layer is GroupLayer:
		if layer.expanded:
			Global.change_button_texturerect(expand_button.get_child(0), "group_expanded.png")
		else:
			Global.change_button_texturerect(expand_button.get_child(0), "group_collapsed.png")

	if layer.visible:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_visible.png")
	else:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_invisible.png")

	if layer.locked:
		Global.change_button_texturerect(lock_button.get_child(0), "lock.png")
	else:
		Global.change_button_texturerect(lock_button.get_child(0), "unlock.png")

	if linked_button:
		if layer.new_cels_linked:  # If new layers will be linked
			Global.change_button_texturerect(linked_button.get_child(0), "linked_layer.png")
		else:
			Global.change_button_texturerect(linked_button.get_child(0), "unlinked_layer.png")

	visibility_button.modulate.a = 1
	lock_button.modulate.a = 1
	popup_menu.set_item_checked(0, layer.clipping_mask)
	clipping_mask_icon.visible = layer.clipping_mask
	if is_instance_valid(layer.parent):
		if not layer.parent.is_visible_in_hierarchy():
			visibility_button.modulate.a = 0.33
		if layer.parent.is_locked_in_hierarchy():
			lock_button.modulate.a = 0.33


## When pressing a button, change the appearance of other layers (ie: expand or visible)
func _update_buttons_all_layers() -> void:
	for layer_button: LayerButton in get_parent().get_children():
		layer_button.update_buttons()
		var layer := Global.current_project.layers[layer_button.layer_index]
		var expanded := layer.is_expanded_in_hierarchy()
		layer_button.visible = expanded
		Global.cel_vbox.get_child(layer_button.get_index()).visible = expanded
	Global.animation_timeline.update_global_layer_buttons()


func _input(event: InputEvent) -> void:
	if (
		(event.is_action_released(&"ui_accept") or event.is_action_released(&"ui_cancel"))
		and line_edit.visible
		and event.keycode != KEY_SPACE
	):
		_save_layer_name(line_edit.text)


func _on_layer_main_button_pressed() -> void:
	var project := Global.current_project
	Global.canvas.selection.transform_content_confirm()
	var prev_curr_layer := project.current_layer
	if Input.is_action_pressed(&"shift"):
		var layer_diff_sign := signi(layer_index - prev_curr_layer)
		if layer_diff_sign == 0:
			layer_diff_sign = 1
		for i in range(0, project.frames.size()):
			for j in range(prev_curr_layer, layer_index + layer_diff_sign, layer_diff_sign):
				var frame_layer := [i, j]
				if !project.selected_cels.has(frame_layer):
					project.selected_cels.append(frame_layer)
		project.change_cel(-1, layer_index)
	elif Input.is_action_pressed(&"ctrl"):
		for i in range(0, project.frames.size()):
			var frame_layer := [i, layer_index]
			if !project.selected_cels.has(frame_layer):
				project.selected_cels.append(frame_layer)
		project.change_cel(-1, layer_index)
	else:  # If the button is pressed without Shift or Control
		_select_current_layer()


func _on_main_button_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			label.visible = false
			line_edit.visible = true
			line_edit.editable = true
			line_edit.grab_focus()

	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		popup_menu.popup_on_parent(Rect2(get_global_mouse_position(), Vector2.ONE))


func _on_layer_name_line_edit_focus_exited() -> void:
	_save_layer_name(line_edit.text)


func _save_layer_name(new_name: String) -> void:
	label.visible = true
	line_edit.visible = false
	line_edit.editable = false
	if layer_index < Global.current_project.layers.size():
		Global.current_project.layers[layer_index].name = new_name


func _on_expand_button_pressed() -> void:
	var layer := Global.current_project.layers[layer_index]
	layer.expanded = !layer.expanded
	_update_buttons_all_layers()


func _on_visibility_button_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	var layer := Global.current_project.layers[layer_index]
	layer.visible = !layer.visible
	Global.canvas.update_all_layers = true
	Global.canvas.queue_redraw()
	if Global.select_layer_on_button_click:
		_select_current_layer()
	_update_buttons_all_layers()


func _on_lock_button_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	var layer := Global.current_project.layers[layer_index]
	layer.locked = !layer.locked
	if Global.select_layer_on_button_click:
		_select_current_layer()
	_update_buttons_all_layers()
	var child_count := layer.get_child_count(true)
	Global.disable_button(
		Global.animation_timeline.remove_layer,
		layer.is_locked_in_hierarchy() or Global.current_project.layers.size() == child_count + 1
	)


func _on_link_button_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	var layer := Global.current_project.layers[layer_index]
	if not layer is PixelLayer:
		return
	layer.new_cels_linked = !layer.new_cels_linked
	update_buttons()
	if Global.select_layer_on_button_click:
		_select_current_layer()


func _select_current_layer() -> void:
	Global.current_project.selected_cels.clear()
	var frame_layer := [Global.current_project.current_frame, layer_index]
	if !Global.current_project.selected_cels.has(frame_layer):
		Global.current_project.selected_cels.append(frame_layer)

	Global.current_project.change_cel(-1, layer_index)


func _on_popup_menu_id_pressed(id: int) -> void:
	var layer := Global.current_project.layers[layer_index]
	if id == 0:
		properties.layer_indices = _get_layer_indices()
		properties.popup_centered()
	elif id == 1:
		layer.clipping_mask = not layer.clipping_mask
		popup_menu.set_item_checked(id, layer.clipping_mask)
		clipping_mask_icon.visible = layer.clipping_mask
		Global.canvas.update_all_layers = true
		Global.canvas.draw_layers()


func _get_layer_indices() -> PackedInt32Array:
	var indices := []
	for cel in Global.current_project.selected_cels:
		var l: int = cel[1]
		if not l in indices:
			indices.append(l)
	indices.sort()
	if not layer_index in indices:
		indices = [layer_index]
	return indices
