extends Popup

var from_project: Project
var create_new_tags := false

@onready var from_project_list: OptionButton = %ProjectList
@onready var create_tags: CheckButton = %CreateTags
@onready var animation_tags_list: ItemList = %TagList
@onready var start_frame: Label = %StartFrame


func _ready() -> void:
	var tag_container: Control = Global.animation_timeline.find_child("TagContainer")
	# connect signals
	tag_container.connect("gui_input", _on_TagContainer_gui_input)
	from_project_list.connect("item_selected", _on_FromProject_changed)
	animation_tags_list.connect("item_selected", _on_TagList_id_pressed)
	create_tags.connect("toggled", _on_CreateTags_toggled)


func refresh_list() -> void:
	animation_tags_list.clear()
	for tag in from_project.animation_tags:
		var img = Image.create(5, 5, true, Image.FORMAT_RGBA8)
		img.fill(tag.color)
		var tex = ImageTexture.create_from_image(img)
		var tag_title = tag.name
		if tag_title == "":
			tag_title = "(Untitled)"
		animation_tags_list.add_item(tag_title, tex)


func _on_CreateTags_toggled(pressed: bool) -> void:
	create_new_tags = pressed


func _on_TagContainer_gui_input(event: InputEvent) -> void:
	if !event is InputEventMouseButton:
		return
	if Input.is_action_just_released("right_mouse"):
		# Reset UI
		from_project_list.clear()
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
		popup(Rect2i(Global.control.get_global_mouse_position(), Vector2i.ONE))


func _on_FromProject_changed(id: int) -> void:
	from_project = Global.projects[id]
	refresh_list()


func _on_TagList_id_pressed(id: int) -> void:
	var tag: AnimationTag = from_project.animation_tags[id]
	var frames = []
	for i in range(tag.from - 1, tag.to):
		frames.append(i)
	if create_new_tags:
		add_animation(frames, Global.current_project.current_frame, tag)
	else:
		add_animation(frames, Global.current_project.current_frame)
	hide()


## Gets frame indices of [member from_project] and dumps it in the current project.
func add_animation(indices: Array, destination: int, from_tag: AnimationTag = null):
	var project: Project = Global.current_project
	if from_project == project:  ## If we are copying tags within project
		Global.animation_timeline.copy_frames(indices, destination, true, from_tag)
		return
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
	var imported_frames: Array[Frame] = []  # The copied frames
	# the indices of newly copied frames
	var copied_indices: PackedInt32Array = range(
		destination + 1, (destination + 1) + indices.size()
	)
	project.undos += 1
	project.undo_redo.create_action("Import Tag")
	# Step 1: calculate layers to generate
	var layer_to_names := PackedStringArray()  # names of currently existing layers
	for l in project.layers:
		layer_to_names.append(l.name)

	# the goal of this section is to mark existing layers with their indices else with -1
	var layer_from_to := {}  # indices of layers from and to
	for from in from_project.layers.size():
		var to = layer_to_names.find(from_project.layers[from].name)
		if project.layers[to].get_layer_type() != from_project.layers[from].get_layer_type():
			to = -1
		if to in layer_from_to.values():  # from_project has layers with duplicate frames
			to = -1
		layer_from_to[from] = to

	# Step 2: generate required layers
	var combined_copy := Array()  # Makes calculations easy
	combined_copy.append_array(project.layers)
	var added_layers := Array()  # Array of layers
	var added_idx := Array()  # Array of indices to add the respective layers (in added_layers) to
	var added_cels := Array()  # Array of an Array of cels (added in same order as their layer)

	if layer_from_to.values().count(-1) > 0:
		# As it is extracted from a dictionary, so i assume the keys aren't sorted
		var from_layers_size = layer_from_to.keys().duplicate(true)
		from_layers_size.sort()  # it's values should now be from (layer size - 1) to zero
		for i in from_layers_size:
			if layer_from_to[i] == -1:
				var type = from_project.layers[i].get_layer_type()
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
				l.name = from_project.layers[i].name  # this will set it to the required layer name

				# Set an appropriate parent
				var new_layer_idx = combined_copy.size()
				layer_from_to[i] = new_layer_idx
				var from_children = from_project.layers[i].get_children(false)
				for from_child in from_children:  # If this layer had children
					var child_to_idx = layer_from_to[from_project.layers.find(from_child)]
					var to_child = combined_copy[child_to_idx]
					if to_child in added_layers:  # if child was added recently
						to_child.parent = l

				combined_copy.insert(new_layer_idx, l)
				added_layers.append(l)  # layer is now added
				added_idx.append(new_layer_idx)  # at index new_layer_idx
				added_cels.append(cels)  # with cels

	# Now initiate import
	for f in indices:
		var src_frame: Frame = from_project.frames[f]
		var new_frame := Frame.new()
		imported_frames.append(new_frame)
		new_frame.duration = src_frame.duration
		for to in combined_copy.size():
			var new_cel: BaseCel
			if to in layer_from_to.values():
				var from = layer_from_to.find_key(to)
				# Cel we're copying from, the source
				var src_cel: BaseCel = from_project.frames[f].cels[from]
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
				new_cel = combined_copy[to].new_empty_cel()
			new_frame.cels.append(new_cel)

		for tag in new_animation_tags:  # Loop through the tags to see if the frame is in one
			if copied_indices[0] >= tag.from && copied_indices[0] <= tag.to:
				tag.to += 1
			elif copied_indices[0] < tag.from:
				tag.from += 1
				tag.to += 1
	if from_tag:
		new_animation_tags.append(
			AnimationTag.new(
				from_tag.name, from_tag.color, copied_indices[0] + 1, copied_indices[-1] + 1
			)
		)
	project.undo_redo.add_undo_method(project.remove_frames.bind(copied_indices))
	project.undo_redo.add_do_method(project.add_layers.bind(added_layers, added_idx, added_cels))
	project.undo_redo.add_do_method(project.add_frames.bind(imported_frames, copied_indices))
	project.undo_redo.add_undo_method(project.remove_layers.bind(added_idx))
	# Note: temporarily set the selected cels to an empty array (needed for undo/redo)
	project.undo_redo.add_do_property(Global.current_project, "selected_cels", [])
	project.undo_redo.add_undo_property(Global.current_project, "selected_cels", [])

	var all_new_cels = []
	# Select all the new frames so that it is easier to move/offset collectively if user wants
	# To ease animation workflow, new current frame is the first copied frame instead of the last
	var range_start: int = copied_indices[-1]
	var range_end: int = copied_indices[0]
	var frame_diff_sign := signi(range_end - range_start)
	if frame_diff_sign == 0:
		frame_diff_sign = 1
	for i in range(range_start, range_end + frame_diff_sign, frame_diff_sign):
		for j in range(0, combined_copy.size()):
			var frame_layer := [i, j]
			if !all_new_cels.has(frame_layer):
				all_new_cels.append(frame_layer)
	project.undo_redo.add_do_property(Global.current_project, "selected_cels", all_new_cels)
	project.undo_redo.add_undo_method(
		project.change_cel.bind(project.current_frame, project.current_layer)
	)
	project.undo_redo.add_do_method(project.change_cel.bind(range_end))
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()
