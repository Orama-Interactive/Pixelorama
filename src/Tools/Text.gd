extends "res://src/Tools/BaseTool.gd"

const TEXT_EDIT_STYLEBOX = preload("res://assets/themes/text_tool_stylebox.tres")

var loaded_fonts := [
	preload("res://assets/fonts/Roboto-Regular.ttf"),
	preload("res://assets/fonts/DroidSansFallback.ttf")
]
var loaded_fonts_paths := [] # String[]
var text_label : Label
var text_edit_pos := Vector2.ZERO

var font := DynamicFont.new()
var font_data : DynamicFontData = loaded_fonts[0]
var font_data_index := 0
var text_size := 16
var outline_color := Color.white
var outline_size := 0
var current_text = ""
var vshape: VectorTextShape # TODO: This should probably be only for editing an existing shape?

onready var text_edit := $"%TextEdit"
onready var font_optionbutton : OptionButton = $"%FontOptionButton"
onready var font_filedialog : FileDialog = $"%FontFileDialog"


func _ready() -> void:
	font.font_data = font_data
	font.size = text_size

func _process(_delta):
	if is_instance_valid(text_label):
		# update text color if it is changed
		if text_label.get_color("font_color", "Label") != tool_slot.color:
			text_label.add_color_override("font_color", tool_slot.color)


func _exit_tree():
	if is_instance_valid(text_label):
		text_label.queue_free()


func get_config() -> Dictionary:
	return {
		"font_data_index" : font_data_index,
		"text_size" : text_size,
		"outline_color" : outline_color,
		"outline_size" : outline_size,
		"loaded_fonts_paths" : loaded_fonts_paths
	}


#func set_config(config : Dictionary) -> void:
#	# Handle loaded fonts
#	loaded_fonts_paths = config.get("loaded_fonts_paths", loaded_fonts_paths)
#
#	var failed_paths := [] # For invalid font paths
#	for path in loaded_fonts_paths:
#		var dir := Directory.new()
#		if !dir.file_exists(path):
#			print("Failed to load ", path)
#			failed_paths.append(path)
#			continue
#		var file = DynamicFontData.new()
#		file = load(path)
#		loaded_fonts.append(file)
#		var file_name = path.get_file().get_basename()
#		font_optionbutton.add_item(file_name)
#		print("Loaded ", path, " succesfully")
#
#	if failed_paths:
#		print(failed_paths)
#		for path in failed_paths:
#			loaded_fonts_paths.erase(path)
#		save_config()
#
#	font_data_index = config.get("font_data_index", font_data_index)
#	if font_data_index >= loaded_fonts.size():
#		font_data_index = 0
#	text_size = config.get("text_size", text_size)
#	outline_color = config.get("outline_color", outline_color)
#	outline_size = config.get("outline_size", outline_size)
#
#	font_data = loaded_fonts[font_data_index]
#	font.font_data = font_data
#	font.size = text_size
#	font.outline_color = outline_color
#	font.outline_size = outline_size


#func update_config() -> void:
#	font_optionbutton.selected = loaded_fonts.find(font_data)
#	$TextSizeSpinBox.value = text_size
#	$OutlineContainer/OutlineColorPickerButton.color = outline_color
#	$OutlineContainer/OutlineSpinBox.value = outline_size


func draw_start(position : Vector2) -> void:
	if is_instance_valid(text_label):
		current_text = text_label.text
		text_label.queue_free()

	text_label = Label.new()
	text_label.text = current_text
	text_edit_pos = position
	text_label.rect_min_size = Vector2(32, max(32, font.get_height()))
	text_label.rect_position = position - Vector2(0, text_label.rect_min_size.y / 2)
	text_label.add_font_override("font", font)
	text_label.add_constant_override("line_spacing", 0)
	text_label.add_stylebox_override("normal", TEXT_EDIT_STYLEBOX)
	text_label.add_color_override("font_color", tool_slot.color)
	Global.canvas.add_child(text_label)


func draw_move(_position : Vector2) -> void:
	pass


func draw_end(_position : Vector2) -> void:
	pass


#func text_to_pixels() -> void:
#	if !text_label:
#		return
#	if !text_label.text:
#		text_label.queue_free()
#		text_label = null
#		return
#
#	var project : Project = Global.current_project
#	var size : Vector2 = project.size
#	var current_cel = project.frames[project.current_frame].cels[project.current_layer].image
#	var viewport_texture := Image.new()
#
#	var vp = VisualServer.viewport_create()
#	var canvas = VisualServer.canvas_create()
#	VisualServer.viewport_attach_canvas(vp, canvas)
#	VisualServer.viewport_set_size(vp, size.x, size.y)
#	VisualServer.viewport_set_disable_3d(vp, true)
#	VisualServer.viewport_set_usage(vp, VisualServer.VIEWPORT_USAGE_2D)
#	VisualServer.viewport_set_hdr(vp, true)
#	VisualServer.viewport_set_active(vp, true)
#	VisualServer.viewport_set_transparent_background(vp, true)
#
#	var ci_rid = VisualServer.canvas_item_create()
#	VisualServer.viewport_set_canvas_transform(vp, canvas, Transform())
#	VisualServer.canvas_item_set_parent(ci_rid, canvas)
#
#	var texts := text_label.text.split("\n")
#	var pos := text_label.rect_position + Vector2(1, font.get_ascent())
#	for text in texts:
#		font.draw(ci_rid, pos, text, tool_slot.color)
#		pos.y += font.get_height()
#
#	VisualServer.viewport_set_update_mode(vp, VisualServer.VIEWPORT_UPDATE_ONCE)
#	VisualServer.viewport_set_vflip(vp, true)
#	VisualServer.force_draw(false)
#
#	#Combining textures through visual server was causing problems so i used an alternative
#	viewport_texture = VisualServer.texture_get_data(VisualServer.viewport_get_texture(vp))
#	viewport_texture.lock()
#	viewport_texture.blend_rect(current_cel,Rect2(Vector2(0, 0), size),Vector2(0,0))
#	viewport_texture.unlock()
#
#	VisualServer.free_rid(vp)
#	VisualServer.free_rid(canvas)
#	VisualServer.free_rid(ci_rid)
#	viewport_texture.convert(Image.FORMAT_RGBA8)
#
#	if !viewport_texture.is_empty():
#		Global.canvas.handle_undo("Draw")
#		current_cel.unlock()
#		current_cel.copy_from(viewport_texture)
#		current_cel.lock()
#		Global.canvas.handle_redo("Draw")
#
#	text_label.queue_free()
#	text_label = null

func _on_TextEdit_text_changed():
	current_text = text_edit.text
	if text_label:
		text_label.text = current_text
		# reset rect to zero so that it can auto-set its size by the text inside it
		text_label.rect_size = Vector2.ZERO


func _on_TextSizeSlider_value_changed(value : int) -> void:
	text_size = value
	font.size = text_size
	save_config()
	if text_label:
		# reset rect to zero so that it can auto-set its size by the text inside it
		text_label.rect_size = Vector2.ZERO


func _on_FontOptionButton_item_selected(index : int) -> void:
	if index >= loaded_fonts.size():
		return
	font_data_index = index
	font_data = loaded_fonts[index]
	font.font_data = font_data
	save_config()


func _on_LoadFontButton_pressed() -> void:
	font_filedialog.popup_centered()
	Global.dialog_open(true)


func _on_FontFileDialog_files_selected(paths : PoolStringArray) -> void:
	for path in paths:
		var dir := Directory.new()
		if !dir.file_exists(path):
			print("Failed to load ", path)
			continue
		var file = DynamicFontData.new()
		file = load(path)
		loaded_fonts.append(file)
		var file_name = path.get_file().get_basename()
		font_optionbutton.add_item(file_name)
		print("Loaded ", path, " succesfully")
		loaded_fonts_paths.append(path)
	save_config()


func _on_FontFileDialog_popup_hide() -> void:
	Global.dialog_open(false)


func textedit_get_max_line(_texte : TextEdit) -> int:
	var max_line : int = 0
	var max_string : int = _texte.get_line(0).length()
	for i in _texte.get_line_count():
		var line := _texte.get_line(i)
		if line.length() > max_string:
			max_string = line.length()
			max_line = i

	return max_line


func _on_OutlineColorPickerButton_color_changed(color : Color) -> void:
	outline_color = color
	font.outline_color = color
	save_config()


func _on_OutlineSlider_value_changed(value : int) -> void:
	outline_size = value
	font.outline_size = value
	save_config()


func _on_ApplyText_pressed():
#	text_to_pixels() # Old method TODO: Remove
	var project: Project = Global.current_project

	# TODO: Not sure if this should be added before or after?
	if not project.layers[project.current_layer] is VectorLayer:
		Global.animation_timeline.add_layer(Global.LayerTypes.VECTOR)

	project.undos += 1
	project.undo_redo.create_action("Add Text")

	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is VectorCel:
			continue
#		font.font_data = loaded_fonts[font_data_index]

		var shape_font = font.duplicate(true)
		shape_font.font_data.override_oversampling = 1

		# TODO: this vshape shouldn't always be new:
		var text_vshape := VectorTextShape.new()
		text_vshape.pos = text_label.rect_position# + Vector2(1, font.get_ascent())
		text_vshape.text = text_label.text
		text_vshape.font = shape_font
		text_vshape.font_size = text_size
		text_vshape.outline_size = outline_size
	#	text_vshape.extra_spacing = Vector2(0, 3)
		text_vshape.color = tool_slot.color
		text_vshape.outline_color = outline_color
	#	text_vshape.antialiased = false
		# TODO: This should be added with Undo/Redo support
		cel.vshapes.append(text_vshape)

		project.undo_redo.add_do_method(Global, "undo_or_redo", false, cel_index[0], cel_index[1])
		project.undo_redo.add_undo_method(Global, "undo_or_redo", true, cel_index[0], cel_index[1])
	project.undo_redo.commit_action()
	text_label.queue_free()
