class_name Project extends Reference
# A class for project properties.


var name := "" setget name_changed
var size := Vector2(64, 64)
var undo_redo : UndoRedo
var undos := 0 # The number of times we added undo properties
var has_changed := false setget has_changed_changed
var frames := [] setget frames_changed # Array of Frames (that contain Cels)
var layers := [] setget layers_changed # Array of Layers
var current_frame := 0 setget frame_changed
var current_layer := 0 setget layer_changed
var animation_tags := [] setget animation_tags_changed # Array of AnimationTags
var guides := [] # Array of Guides

var brushes := [] # Array of Images

var selected_pixels := []
var x_min := 0
var x_max := 64
var y_min := 0
var y_max := 64

# For every camera (currently there are 3)
var cameras_zoom := [Vector2(0.15, 0.15), Vector2(0.15, 0.15), Vector2(0.15, 0.15)] # Array of Vector2
var cameras_offset := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO] # Array of Vector2


func _init(_frames := [], _name := tr("untitled")) -> void:
	frames = _frames
	name = _name
	x_max = size.x
	y_max = size.y
	undo_redo = UndoRedo.new()

	Global.tabs.add_tab(name)
	OpenSave.current_save_paths.append("")
	OpenSave.backup_save_paths.append("")


func change_project() -> void:
	# Remove old nodes
	for container in Global.layers_container.get_children():
		container.queue_free()

	remove_cel_buttons()

	for frame_id in Global.frame_ids.get_children():
		Global.frame_ids.remove_child(frame_id)
		frame_id.queue_free()

	# Create new ones
	for i in range(layers.size() - 1, -1, -1):
		# Create layer buttons
		var layer_container = load("res://src/UI/Timeline/LayerButton.tscn").instance()
		layer_container.i = i
		if layers[i].name == tr("Layer") + " 0":
			layers[i].name = tr("Layer") + " %s" % i

		Global.layers_container.add_child(layer_container)
		layer_container.label.text = layers[i].name
		layer_container.line_edit.text = layers[i].name

		Global.frames_container.add_child(layers[i].frame_container)
		for j in range(frames.size()): # Create Cel buttons
			var cel_button = load("res://src/UI/Timeline/CelButton.tscn").instance()
			cel_button.frame = j
			cel_button.layer = i
			cel_button.get_child(0).texture = frames[j].cels[i].image_texture
			if j == current_frame and i == current_layer:
				cel_button.pressed = true

			layers[i].frame_container.add_child(cel_button)

	for j in range(frames.size()): # Create frame ID labels
		var label := Label.new()
		label.rect_min_size.x = 36
		label.align = Label.ALIGN_CENTER
		label.text = str(j + 1)
		if j == current_frame:
			label.add_color_override("font_color", Global.control.theme.get_color("Selected Color", "Label"))
		Global.frame_ids.add_child(label)

	var layer_button = Global.layers_container.get_child(Global.layers_container.get_child_count() - 1 - current_layer)
	layer_button.pressed = true

	Global.current_frame_mark_label.text = "%s/%s" % [str(current_frame + 1), frames.size()]

	Global.disable_button(Global.remove_frame_button, frames.size() == 1)
	toggle_layer_buttons_layers()
	toggle_layer_buttons_current_layer()

	self.animation_tags = animation_tags

	# Change the selection rectangle
	if selected_pixels.size() != 0:
		Global.selection_rectangle.polygon[0] = Vector2(x_min, y_min)
		Global.selection_rectangle.polygon[1] = Vector2(x_max, y_min)
		Global.selection_rectangle.polygon[2] = Vector2(x_max, y_max)
		Global.selection_rectangle.polygon[3] = Vector2(x_min, y_max)
	else:
		Global.selection_rectangle.polygon[0] = Vector2.ZERO
		Global.selection_rectangle.polygon[1] = Vector2.ZERO
		Global.selection_rectangle.polygon[2] = Vector2.ZERO
		Global.selection_rectangle.polygon[3] = Vector2.ZERO

	# Change the guides
	for guide in Global.canvas.get_children():
		if guide is Guide:
			if guide in guides:
				guide.visible = true
			else:
				guide.visible = false

	# Change the project brushes
	for child in Global.project_brush_container.get_children():
		child.queue_free()

	for brush in brushes:
		Global.create_brush_button(brush)

	var cameras = [Global.camera, Global.camera2, Global.camera_preview]
	var i := 0
	for camera in cameras:
		camera.zoom = cameras_zoom[i]
		camera.offset = cameras_offset[i]
		i += 1
	Global.zoom_level_label.text = str(round(100 / Global.camera.zoom.x)) + " %"
	Global.canvas.update()
	Global.transparent_checker._ready()
	Global.horizontal_ruler.update()
	Global.vertical_ruler.update()
	Global.window_title = "%s - Pixelorama %s" % [name, Global.current_version]
	if has_changed:
		Global.window_title = Global.window_title + "(*)"

	var save_path = OpenSave.current_save_paths[Global.current_project_index]
	if save_path != "":
		Global.open_sprites_dialog.current_path = save_path
		Global.save_sprites_dialog.current_path = save_path
		Global.file_menu.get_popup().set_item_text(3, tr("Save") + " %s" % save_path.get_file())
	else:
		Global.file_menu.get_popup().set_item_text(3, tr("Save"))


func serialize() -> Dictionary:
	var layer_data := []
	for layer in layers:
		var linked_cels := []
		for cel in layer.linked_cels:
			linked_cels.append(frames.find(cel))

		layer_data.append({
			"name" : layer.name,
			"visible" : layer.visible,
			"locked" : layer.locked,
			"new_cels_linked" : layer.new_cels_linked,
			"linked_cels" : linked_cels,
		})

	var tag_data := []
	for tag in animation_tags:
		tag_data.append({
			"name" : tag.name,
			"color" : tag.color.to_html(),
			"from" : tag.from,
			"to" : tag.to,
		})

	var guide_data := []
	for guide in guides:
		var coords = guide.points[0].x
		if guide.type == Guide.Types.HORIZONTAL:
			coords = guide.points[0].y

		guide_data.append({"type" : guide.type, "pos" : coords})

	var frame_data := []
	for frame in frames:
		var cel_data := []
		for cel in frame.cels:
			cel_data.append({
				"opacity" : cel.opacity,
#				"image_data" : cel.image.get_data()
			})
		frame_data.append({
			"cels" : cel_data
		})
	var brush_data := []
	for brush in brushes:
		brush_data.append({
			"size_x" : brush.get_size().x,
			"size_y" : brush.get_size().y
		})

	var project_data := {
		"pixelorama_version" : Global.current_version,
		"name" : name,
		"size_x" : size.x,
		"size_y" : size.y,
		"save_path" : OpenSave.current_save_paths[Global.projects.find(self)],
		"layers" : layer_data,
		"tags" : tag_data,
		"guides" : guide_data,
		"frames" : frame_data,
		"brushes" : brush_data,
	}

	return project_data


func deserialize(dict : Dictionary) -> void:
	if dict.has("name"):
		name = dict.name
	if dict.has("size_x"):
		size.x = dict.size_x
	if dict.has("size_y"):
		size.y = dict.size_y
	if dict.has("save_path"):
		OpenSave.current_save_paths[Global.projects.find(self)] = dict.save_path
	if dict.has("frames"):
		for frame in dict.frames:
			var cels := []
			for cel in frame.cels:
				cels.append(Cel.new(Image.new(), cel.opacity))
			frames.append(Frame.new(cels))
		if dict.has("layers"):
			var layer_i :=  0
			for saved_layer in dict.layers:
				var linked_cels := []
				for linked_cel_number in saved_layer.linked_cels:
					linked_cels.append(frames[linked_cel_number])
					frames[linked_cel_number].cels[layer_i].image = linked_cels[0].cels[layer_i].image
					frames[linked_cel_number].cels[layer_i].image_texture = linked_cels[0].cels[layer_i].image_texture
				var layer := Layer.new(saved_layer.name, saved_layer.visible, saved_layer.locked, HBoxContainer.new(), saved_layer.new_cels_linked, linked_cels)
				layers.append(layer)
				layer_i += 1
	if dict.has("tags"):
		for tag in dict.tags:
			animation_tags.append(AnimationTag.new(tag.name, Color(tag.color), tag.from, tag.to))
		self.animation_tags = animation_tags
	if dict.has("guides"):
		for g in dict.guides:
			var guide := Guide.new()
			guide.type = g.type
			if guide.type == Guide.Types.HORIZONTAL:
				guide.add_point(Vector2(-99999, g.pos))
				guide.add_point(Vector2(99999, g.pos))
			else:
				guide.add_point(Vector2(g.pos, -99999))
				guide.add_point(Vector2(g.pos, 99999))
			guide.has_focus = false
			Global.canvas.add_child(guide)
			guides.append(guide)


func name_changed(value : String) -> void:
	name = value
	Global.tabs.set_tab_title(Global.tabs.current_tab, name)


func frames_changed(value : Array) -> void:
	frames = value
	remove_cel_buttons()

	for frame_id in Global.frame_ids.get_children():
		Global.frame_ids.remove_child(frame_id)
		frame_id.queue_free()

	for i in range(layers.size() - 1, -1, -1):
		Global.frames_container.add_child(layers[i].frame_container)

	for j in range(frames.size()):
		var label := Label.new()
		label.rect_min_size.x = 36
		label.align = Label.ALIGN_CENTER
		label.text = str(j + 1)
		Global.frame_ids.add_child(label)

		for i in range(layers.size() - 1, -1, -1):
			var cel_button = load("res://src/UI/Timeline/CelButton.tscn").instance()
			cel_button.frame = j
			cel_button.layer = i
			cel_button.get_child(0).texture = frames[j].cels[i].image_texture

			layers[i].frame_container.add_child(cel_button)

	set_timeline_first_and_last_frames()


func layers_changed(value : Array) -> void:
	layers = value
	if Global.layers_changed_skip:
		Global.layers_changed_skip = false
		return

	for container in Global.layers_container.get_children():
		container.queue_free()

	remove_cel_buttons()

	for i in range(layers.size() - 1, -1, -1):
		var layer_container = load("res://src/UI/Timeline/LayerButton.tscn").instance()
		layer_container.i = i
		if layers[i].name == tr("Layer") + " 0":
			layers[i].name = tr("Layer") + " %s" % i

		Global.layers_container.add_child(layer_container)
		layer_container.label.text = layers[i].name
		layer_container.line_edit.text = layers[i].name

		Global.frames_container.add_child(layers[i].frame_container)
		for j in range(frames.size()):
			var cel_button = load("res://src/UI/Timeline/CelButton.tscn").instance()
			cel_button.frame = j
			cel_button.layer = i
			cel_button.get_child(0).texture = frames[j].cels[i].image_texture

			layers[i].frame_container.add_child(cel_button)

	var layer_button = Global.layers_container.get_child(Global.layers_container.get_child_count() - 1 - current_layer)
	layer_button.pressed = true
	self.current_frame = current_frame # Call frame_changed to update UI
	toggle_layer_buttons_layers()


func remove_cel_buttons() -> void:
	for container in Global.frames_container.get_children():
		for button in container.get_children():
			container.remove_child(button)
			button.queue_free()
		Global.frames_container.remove_child(container)


func frame_changed(value : int) -> void:
	current_frame = value
	Global.current_frame_mark_label.text = "%s/%s" % [str(current_frame + 1), frames.size()]

	for i in frames.size():
		var text_color := Color.white
		if Global.theme_type == Global.Theme_Types.CARAMEL || Global.theme_type == Global.Theme_Types.LIGHT:
			text_color = Color.black
		Global.frame_ids.get_child(i).add_color_override("font_color", text_color)
		for layer in layers: # De-select all the other frames
			if i < layer.frame_container.get_child_count():
				layer.frame_container.get_child(i).pressed = false

	# Select the new frame
	if current_frame < Global.frame_ids.get_child_count():
		Global.frame_ids.get_child(current_frame).add_color_override("font_color", Global.control.theme.get_color("Selected Color", "Label"))
	if layers and current_frame < layers[current_layer].frame_container.get_child_count():
		layers[current_layer].frame_container.get_child(current_frame).pressed = true

	Global.disable_button(Global.remove_frame_button, frames.size() == 1)

	Global.canvas.update()
	Global.transparent_checker._ready() # To update the rect size


func layer_changed(value : int) -> void:
	current_layer = value
	if current_frame < frames.size():
		Global.layer_opacity_slider.value = frames[current_frame].cels[current_layer].opacity * 100
		Global.layer_opacity_spinbox.value = frames[current_frame].cels[current_layer].opacity * 100

	for container in Global.layers_container.get_children():
		container.pressed = false

	if current_layer < Global.layers_container.get_child_count():
		var layer_button = Global.layers_container.get_child(Global.layers_container.get_child_count() - 1 - current_layer)
		layer_button.pressed = true

	toggle_layer_buttons_current_layer()

	yield(Global.get_tree().create_timer(0.01), "timeout")
	self.current_frame = current_frame # Call frame_changed to update UI


func toggle_layer_buttons_layers() -> void:
	if !layers:
		return
	if layers[current_layer].locked:
		Global.disable_button(Global.remove_layer_button, true)

	if layers.size() == 1:
		Global.disable_button(Global.remove_layer_button, true)
		Global.disable_button(Global.move_up_layer_button, true)
		Global.disable_button(Global.move_down_layer_button, true)
		Global.disable_button(Global.merge_down_layer_button, true)
	elif !layers[current_layer].locked:
		Global.disable_button(Global.remove_layer_button, false)


func toggle_layer_buttons_current_layer() -> void:
	if current_layer < layers.size() - 1:
		Global.disable_button(Global.move_up_layer_button, false)
	else:
		Global.disable_button(Global.move_up_layer_button, true)

	if current_layer > 0:
		Global.disable_button(Global.move_down_layer_button, false)
		Global.disable_button(Global.merge_down_layer_button, false)
	else:
		Global.disable_button(Global.move_down_layer_button, true)
		Global.disable_button(Global.merge_down_layer_button, true)

	if current_layer < layers.size():
		if layers[current_layer].locked:
			Global.disable_button(Global.remove_layer_button, true)
		else:
			if layers.size() > 1:
				Global.disable_button(Global.remove_layer_button, false)


func animation_tags_changed(value : Array) -> void:
	animation_tags = value
	for child in Global.tag_container.get_children():
		child.queue_free()

	for tag in animation_tags:
		var tag_c : Container = load("res://src/UI/Timeline/AnimationTag.tscn").instance()
		Global.tag_container.add_child(tag_c)
		var tag_position : int = Global.tag_container.get_child_count() - 1
		Global.tag_container.move_child(tag_c, tag_position)
		tag_c.get_node("Label").text = tag.name
		tag_c.get_node("Label").modulate = tag.color
		tag_c.get_node("Line2D").default_color = tag.color

		tag_c.rect_position.x = (tag.from - 1) * 39 + tag.from

		var tag_size : int = tag.to - tag.from
		tag_c.rect_min_size.x = (tag_size + 1) * 39
		tag_c.get_node("Line2D").points[2] = Vector2(tag_c.rect_min_size.x, 0)
		tag_c.get_node("Line2D").points[3] = Vector2(tag_c.rect_min_size.x, 32)

	set_timeline_first_and_last_frames()


func set_timeline_first_and_last_frames() -> void:
	# This is useful in case tags get modified DURING the animation is playing
	# otherwise, this code is useless in this context, since these values are being set
	# when the play buttons get pressed anyway
	Global.animation_timeline.first_frame = 0
	Global.animation_timeline.last_frame = frames.size() - 1
	if Global.play_only_tags:
		for tag in animation_tags:
			if current_frame + 1 >= tag.from && current_frame + 1 <= tag.to:
				Global.animation_timeline.first_frame = tag.from - 1
				Global.animation_timeline.last_frame = min(frames.size() - 1, tag.to - 1)


func has_changed_changed(value : bool) -> void:
	has_changed = value
	if value:
		Global.tabs.set_tab_title(Global.tabs.current_tab, name + "(*)")
	else:
		Global.tabs.set_tab_title(Global.tabs.current_tab, name)
