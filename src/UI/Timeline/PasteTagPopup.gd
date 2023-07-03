extends PopupMenu


func _ready() -> void:
	var tag_container: Control = Global.animation_timeline.find_node("TagContainer")
	connect("id_pressed", self, "_on_TagList_id_pressed")
	tag_container.connect("gui_input", self, "_on_TagContainer_gui_input")


func _on_TagContainer_gui_input(event: InputEvent) -> void:
	if !event is InputEventMouseButton:
		return
	if Input.is_action_just_released("right_mouse"):
		clear()
		if Global.current_project.animation_tags.empty():
			return
		add_separator("Paste content from tag:")
		for tag in Global.current_project.animation_tags:
			var img = Image.new()
			img.create(5, 5, true, Image.FORMAT_RGBA8)
			img.fill(tag.color)
			var tex = ImageTexture.new()
			tex.create_from_image(img)
			var title = tag.name
			if title == "":
				title = "(Untitled)"
			add_icon_item(tex, title)
		var frame_idx = Global.current_project.current_frame + 2
		add_separator(str("The pasted frames will start at (Frame ", frame_idx, ")"))
		popup(Rect2(get_global_mouse_position(), Vector2.ONE))


func _on_TagList_id_pressed(id: int) -> void:
	var tag: AnimationTag = Global.current_project.animation_tags[id - 1]
	var frames = []
	for i in range(tag.from - 1, tag.to):
		frames.append(i)
	Global.animation_timeline.copy_frames(frames, Global.current_project.current_frame)
