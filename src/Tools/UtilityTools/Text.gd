extends BaseTool

var text_edit: TextToolEdit
var text_size := 16
var font_name := "":
	set(value):
		font_name = value
		font.base_font = Global.find_font_from_name(font_name)
		font.base_font.antialiasing = antialiasing
var horizontal_alignment := HORIZONTAL_ALIGNMENT_LEFT
var antialiasing := TextServer.FONT_ANTIALIASING_NONE:
	set(value):
		antialiasing = value
		font.base_font.antialiasing = antialiasing

@onready var font := FontVariation.new()
@onready var font_option_button: OptionButton = $GridContainer/FontOptionButton


func _ready() -> void:
	var font_names := Global.get_available_font_names()
	for f_name in font_names:
		font_option_button.add_item(f_name)
	Tools.color_changed.connect(_on_color_changed)
	super._ready()



func get_config() -> Dictionary:
	return {
		"font_name": font_name,
		"text_size": text_size,
		"horizontal_alignment": horizontal_alignment,
		"antialiasing": antialiasing
	}


func set_config(config: Dictionary) -> void:
	font_name = config.get("font_name", "Roboto")
	if font_name not in Global.get_available_font_names():
		font_name = "Roboto"
	text_size = config.get("text_size", text_size)
	horizontal_alignment = config.get("horizontal_alignment", horizontal_alignment)
	antialiasing = config.get("antialiasing", antialiasing)


func update_config() -> void:
	for i in font_option_button.item_count:
		var item_name: String = font_option_button.get_item_text(i)
		if font_name == item_name:
			font_option_button.selected = i
	$TextSizeSlider.value = text_size


func draw_start(pos: Vector2i) -> void:
	if is_instance_valid(text_edit):
		var text_edit_rect := Rect2i(text_edit.position, text_edit.size)
		if text_edit_rect.has_point(pos):
			return
		text_to_pixels()

	text_edit = TextToolEdit.new()
	text_edit.text = ""
	text_edit.font = font
	text_edit.add_theme_color_override(&"font_color", tool_slot.color)
	text_edit.add_theme_font_size_override(&"font_size", text_size)
	Global.canvas.add_child(text_edit)
	text_edit.position = pos - Vector2i(0, text_edit.custom_minimum_size.y / 2)


func draw_move(_position: Vector2i) -> void:
	pass


func draw_end(_position: Vector2i) -> void:
	pass


func text_to_pixels() -> void:
	if not is_instance_valid(text_edit):
		return
	if text_edit.text.is_empty():
		text_edit.queue_free()
		text_edit = null
		return

	var undo_data := _get_undo_data()
	var project := Global.current_project
	var image := project.frames[project.current_frame].cels[project.current_layer].get_image()

	var vp := RenderingServer.viewport_create()
	var canvas := RenderingServer.canvas_create()
	RenderingServer.viewport_attach_canvas(vp, canvas)
	RenderingServer.viewport_set_size(vp, project.size.x, project.size.y)
	RenderingServer.viewport_set_disable_3d(vp, true)
	RenderingServer.viewport_set_active(vp, true)
	RenderingServer.viewport_set_transparent_background(vp, true)

	var ci_rid := RenderingServer.canvas_item_create()
	RenderingServer.viewport_set_canvas_transform(vp, canvas, Transform2D())
	RenderingServer.canvas_item_set_parent(ci_rid, canvas)
	var texture := RenderingServer.texture_2d_create(image)
	RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(Vector2(0, 0), project.size), texture)

	var texts := text_edit.text.split("\n")
	var pos := text_edit.position + Vector2(1, font.get_ascent())
	for text in texts:
		font.draw_string(ci_rid, pos, text, horizontal_alignment, -1, text_size, tool_slot.color)
		pos.y += font.get_height()

	RenderingServer.viewport_set_update_mode(vp, RenderingServer.VIEWPORT_UPDATE_ONCE)
	RenderingServer.force_draw(false)
	var viewport_texture := RenderingServer.texture_2d_get(RenderingServer.viewport_get_texture(vp))
	RenderingServer.free_rid(vp)
	RenderingServer.free_rid(canvas)
	RenderingServer.free_rid(ci_rid)
	RenderingServer.free_rid(texture)
	viewport_texture.convert(Image.FORMAT_RGBA8)

	text_edit.queue_free()
	text_edit = null
	if !viewport_texture.is_empty():
		image.copy_from(viewport_texture)
		commit_undo("Draw", undo_data)


func commit_undo(action: String, undo_data: Dictionary) -> void:
	var redo_data := _get_undo_data()
	var project := Global.current_project
	var frame := -1
	var layer := -1
	if Global.animation_timeline.animation_timer.is_stopped() and project.selected_cels.size() == 1:
		frame = project.current_frame
		layer = project.current_layer

	project.undos += 1
	project.undo_redo.create_action(action)
	for image in redo_data:
		project.undo_redo.add_do_property(image, "data", redo_data[image])
	for image in undo_data:
		project.undo_redo.add_undo_property(image, "data", undo_data[image])
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false, frame, layer))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true, frame, layer))
	project.undo_redo.commit_action()


func _get_undo_data() -> Dictionary:
	var data := {}
	var images := _get_selected_draw_images()
	for image in images:
		data[image] = image.data
	return data


func _textedit_text_changed() -> void:
	if not is_instance_valid(text_edit):
		return
	if text_edit.font != font:
		text_edit.font = font
	text_edit.add_theme_font_size_override(&"font_size", text_size)
	text_edit._on_text_changed()


func _on_color_changed(_color: Color, _button: int) -> void:
	if is_instance_valid(text_edit):
		text_edit.add_theme_color_override(&"font_color", tool_slot.color)


func _on_text_size_slider_value_changed(value: float) -> void:
	text_size = value
	_textedit_text_changed()
	save_config()


func _on_font_option_button_item_selected(index: int) -> void:
	font_name = font_option_button.get_item_text(index)
	_textedit_text_changed()
	save_config()


func _on_horizontal_alignment_option_button_item_selected(index: int) -> void:
	horizontal_alignment = index


func _on_antialiasing_option_button_item_selected(index: TextServer.FontAntialiasing) -> void:
	antialiasing = index


func _exit_tree() -> void:
	text_to_pixels()
