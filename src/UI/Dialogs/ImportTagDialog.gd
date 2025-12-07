extends AcceptDialog

var from_project: Project
var create_new_tags := false
var frame: int
var tag_id: int

@onready var from_project_list: OptionButton = %ProjectList
@onready var create_tags: CheckButton = %CreateTags
@onready var animation_tags_list: ItemList = %TagList


func _ready() -> void:
	# connect signals
	from_project_list.item_selected.connect(_on_FromProject_changed)
	animation_tags_list.item_selected.connect(_on_TagList_id_pressed)
	animation_tags_list.empty_clicked.connect(_on_TagList_empty_clicked)
	create_tags.toggled.connect(_on_CreateTags_toggled)


func refresh_list() -> void:
	animation_tags_list.clear()
	get_ok_button().disabled = true
	for tag: AnimationTag in from_project.animation_tags:
		var img := from_project.new_empty_image()
		DrawingAlgos.blend_layers(
			img, from_project.frames[tag.from - 1], Vector2i.ZERO, from_project
		)
		var tex := ImageTexture.create_from_image(img)
		var tag_title := tag.name
		if tag_title == "":
			tag_title = "(Untitled)"
		var idx = animation_tags_list.add_item(tag_title, tex)
		animation_tags_list.set_item_custom_fg_color(idx, tag.color)


func _on_CreateTags_toggled(pressed: bool) -> void:
	create_new_tags = pressed


func prepare_and_show(frame_no: int) -> void:
	# Reset UI
	frame = frame_no
	from_project_list.clear()
	if Global.projects.find(from_project) < 0:
		from_project = Global.current_project
	# Populate project list
	for project in Global.projects:
		from_project_list.add_item(project.name)
	from_project_list.select(Global.projects.find(from_project))
	# Populate tag list
	refresh_list()
	title = str("Import Tag (After Frame ", frame + 1, ")")
	popup_centered_clamped()


func _on_FromProject_changed(id: int) -> void:
	from_project = Global.projects[id]
	refresh_list()


func _on_confirmed() -> void:
	var tag: AnimationTag = from_project.animation_tags[tag_id]
	var from_frames := []
	for i in range(tag.from - 1, tag.to):
		from_frames.append(i)
	if create_new_tags:
		Import.copy_frames_to_current_project(from_project, from_frames, frame, tag)
	else:
		Import.copy_frames_to_current_project(from_project, from_frames, frame)


func _on_TagList_id_pressed(id: int) -> void:
	get_ok_button().disabled = false
	tag_id = id


func _on_TagList_empty_clicked(_at_position: Vector2, _mouse_button_index: int) -> void:
	animation_tags_list.deselect_all()
	get_ok_button().disabled = true


func _on_close_requested() -> void:
	hide()
