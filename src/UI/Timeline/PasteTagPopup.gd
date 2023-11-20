extends Popup

@onready var animation_tags_list: ItemList = $PanelContainer/VBoxContainer/TagList
@onready var from_project_list: OptionButton = $PanelContainer/VBoxContainer/ProjectList
@onready var start_frame: Label = $PanelContainer/VBoxContainer/StartFrame

var from_project: Project


func _ready() -> void:
	var tag_container: Control = Global.animation_timeline.find_child("TagContainer")
	# connect signals
	tag_container.connect("gui_input", _on_TagContainer_gui_input)
	from_project_list.connect("item_selected", _on_FromProject_changed)
	animation_tags_list.connect("item_selected", _on_TagList_id_pressed)


func refresh_list() -> void:
	for tag in from_project.animation_tags:
		var img = Image.create(5, 5, true, Image.FORMAT_RGBA8)
		img.fill(tag.color)
		var tex = ImageTexture.create_from_image(img)
		var tag_title = tag.name
		if tag_title == "":
			tag_title = "(Untitled)"
		animation_tags_list.add_item(tag_title, tex)


func _on_TagContainer_gui_input(event: InputEvent) -> void:
	if !event is InputEventMouseButton:
		return
	if Input.is_action_just_released("right_mouse"):
		# Reset UI
		from_project_list.clear()
		animation_tags_list.clear()
		if Global.projects.find(from_project) < 0:
			from_project = Global.current_project
		# Populate project list
		for project in Global.projects:
			from_project_list.add_item(project.name)
		from_project_list.select(Global.projects.find(from_project))
		# Populate tag list
		refresh_list()
		var frame_idx := Global.current_project.current_frame + 2
		start_frame.text = str("The pasted frames will start at (Frame ", frame_idx, ")")
		popup(Rect2i(Global.control.get_global_mouse_position(), size))


func _on_FromProject_changed(id: int) -> void:
	from_project = Global.projects[id]
	refresh_list()


func _on_TagList_id_pressed(id: int) -> void:
	var tag: AnimationTag = from_project.animation_tags[id]
	var frames = []
	for i in range(tag.from - 1, tag.to):
		frames.append(i)
	add_animation(frames, Global.current_project.current_frame)
	hide()


# gets frame indices of from_project and dumps it in current_project
func add_animation(indices: Array, destination: int):
	var project: Project = Global.current_project
	if from_project == project:
		Global.animation_timeline.copy_frames(indices, destination)
		return

	var copied_frames := []
	# the indices of newly copied frames
	var copied_indices := range(destination + 1, (destination + 1) + indices.size())
	var new_animation_tags := project.animation_tags.duplicate()
	# Loop through the tags to create new classes for them, so that they won't be the same
	# as project.animation_tags's classes. Needed for undo/redo to work properly.
	for i in new_animation_tags.size():
		new_animation_tags[i] = AnimationTag.new(
			new_animation_tags[i].name,
			new_animation_tags[i].color,
			new_animation_tags[i].from,
			new_animation_tags[i].to
		)
	project.undos += 1
	project.undo_redo.create_action("Import Tag")
	# Step 1: calculate layers to generate
	var from_l_names := PackedStringArray()
	for l in from_project.layers:
		from_l_names.append(l.name)
	var to_l_names := PackedStringArray()
	for l in project.layers:
		to_l_names.append(l.name)
	var targets := PackedInt32Array()  # target layers the content will be copied to
	var search_idx = 0
	for i in from_l_names.size():
		var idx = to_l_names.find(from_l_names[i], search_idx)
		if project.layers[idx].get_layer_type() != from_project.layers[i].get_layer_type():
			idx = -1
		else:
			search_idx = idx + 1
			idx += targets.count(-1)
		targets.append(idx)
	# Step 2: generate required layers
	var combined_copy := Array()
	combined_copy.append_array(project.layers)
	var added_layers := Array()  # Array of layers
	var added_idx := Array()  # Array of layers
	var added_cels := Array()  # Array of added cels
	for i in targets.size():
		if targets[i] == -1:
			var current_layer_idx = 0
			if i > 0:
				current_layer_idx = targets[i - 1] + 1
			var type = from_project.layers[i].get_layer_type()
			var current_layer = combined_copy[current_layer_idx]
			var l: BaseLayer
			match type:
				Global.LayerTypes.PIXEL:
					l = PixelLayer.new(project)
				Global.LayerTypes.GROUP:
					l = GroupLayer.new(project)
				Global.LayerTypes.THREE_D:
					l = Layer3D.new(project)

			var cels := []
			for f in project.frames:
				cels.append(l.new_empty_cel())

			var new_layer_idx = current_layer_idx
			l.parent = current_layer.parent
			l.name = from_l_names[targets.find(-1)]  # this will set it to the required layer name
			targets[i] = new_layer_idx
			added_layers.append(l)
			added_idx.append(new_layer_idx)
			added_cels.append(cels)
			combined_copy.insert(new_layer_idx, l)
	# Now initiate import
	for f in indices:
		var src_frame: Frame = from_project.frames[f]
		var new_frame := Frame.new()
		copied_frames.append(new_frame)
		new_frame.duration = src_frame.duration
		for l in combined_copy.size():
			var new_cel: BaseCel
			if l in targets:
				var src_cel: BaseCel = from_project.frames[f].cels[targets.find(l)]  # Cel we're copying from, the source
				var selected_id := -1
				if src_cel is Cel3D:
					new_cel = src_cel.get_script().new(
						project.size, false, src_cel.object_properties, src_cel.scene_properties
					)
					if src_cel.selected != null:
						selected_id = src_cel.selected.id
				else:
					new_cel = src_cel.get_script().new()

					# add more types here if they have a copy_content() method
					if src_cel is PixelCel:
						var src_img = src_cel.copy_content()
						var copy := Image.create(
							project.size.x, project.size.y, false, Image.FORMAT_RGBA8
						)
						copy.blit_rect(
							src_img, Rect2(Vector2.ZERO, src_img.get_size()), Vector2.ZERO
						)
						new_cel.set_content(copy)
					new_cel.opacity = src_cel.opacity

					if new_cel is Cel3D:
						if selected_id in new_cel.object_properties.keys():
							if selected_id != -1:
								new_cel.selected = new_cel.get_object_from_id(selected_id)
			else:
				new_cel = combined_copy[l].new_empty_cel()
			new_frame.cels.append(new_cel)

		for tag in new_animation_tags:  # Loop through the tags to see if the frame is in one
			if copied_indices[0] >= tag.from && copied_indices[0] <= tag.to:
				tag.to += 1
			elif copied_indices[0] < tag.from:
				tag.from += 1
				tag.to += 1
	project.undo_redo.add_do_method(project.add_layers.bind(added_layers, added_idx, added_cels))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		# Note: temporarily set the selected cels to an empty array (needed for undo/redo)
	project.undo_redo.add_do_property(Global.current_project, "selected_cels", [])
	project.undo_redo.add_undo_property(Global.current_project, "selected_cels", [])
	project.undo_redo.add_do_method(project.add_frames.bind(copied_frames, copied_indices))
	project.undo_redo.add_undo_method(project.remove_frames.bind(copied_indices))

	var all_new_cels = []
	# Select all the new frames so that it is easier to move/offset collectively if user wants
	# To ease animation workflow, new current frame is the first copied frame instead of the last
	var range_start: int = copied_indices[-1]
	var range_end: int = copied_indices[0]
	var frame_diff_sign := signi(range_end - range_start)
	if frame_diff_sign == 0:
		frame_diff_sign = 1
	for i in range(range_start, range_end + frame_diff_sign, frame_diff_sign):
		for j in range(0, Global.current_project.layers.size()):
			var frame_layer := [i, j]
			if !all_new_cels.has(frame_layer):
				all_new_cels.append(frame_layer)
	project.undo_redo.add_do_property(Global.current_project, "selected_cels", all_new_cels)
	project.undo_redo.add_do_method(project.change_cel.bind(range_end))
#	project.undo_redo.add_do_method(project.change_cel.bind(copied_indices[0]))
	project.undo_redo.add_undo_method(project.change_cel.bind(project.current_frame))
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.add_undo_method(project.remove_layers.bind(added_idx))
	project.undo_redo.commit_action()
#	# Select all the new frames so that it is easier to move/offset collectively if user wants
#	# To ease animation workflow, new current frame is the first copied frame instead of the last
#	var range_start: int = copied_indices[-1]
#	var range_end = copied_indices[0]
#	var frame_diff_sign = sign(range_end - range_start)
#	if frame_diff_sign == 0:
#		frame_diff_sign = 1
#	for i in range(range_start, range_end + frame_diff_sign, frame_diff_sign):
#		for j in range(0, Global.current_project.layers.size()):
#			var frame_layer := [i, j]
#			if !Global.current_project.selected_cels.has(frame_layer):
#				Global.current_project.selected_cels.append(frame_layer)
#	Global.current_project.change_cel(range_end, -1)
#	await get_tree().process_frame
#	await get_tree().process_frame
#	Global.animation_timeline.adjust_scroll_container()
