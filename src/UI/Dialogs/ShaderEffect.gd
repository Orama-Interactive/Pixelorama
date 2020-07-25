extends ConfirmationDialog


var current_cel : Image

onready var viewport : Viewport = $VBoxContainer/ViewportContainer/Viewport
onready var preview : TextureRect = viewport.get_node("Preview")
onready var shader_loaded_label : Label = $VBoxContainer/ShaderLoadedLabel


func _on_ShaderEffect_about_to_show() -> void:
	current_cel = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	current_cel.unlock()
	viewport.size = current_cel.get_size()
	var viewport_texture = viewport.get_texture().get_data()
	viewport_texture.convert(Image.FORMAT_RGBA8)

	var preview_image := Image.new()
	preview_image.copy_from(current_cel)
	var preview_texture = ImageTexture.new()
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


func _on_ShaderEffect_confirmed() -> void:
	var viewport_texture = viewport.get_texture().get_data()
	viewport_texture.flip_y()
	viewport_texture.convert(Image.FORMAT_RGBA8)
	print(viewport_texture.get_size())
	Global.canvas.handle_undo("Draw")
	current_cel.copy_from(viewport_texture)
	Global.canvas.handle_redo("Draw")


func _on_ShaderEffect_popup_hide() -> void:
	current_cel.lock()
	Global.dialog_open(false)
	yield(get_tree().create_timer(0.2), "timeout")
	preview.texture = null
	viewport.size = Vector2.ONE
	rect_size = Vector2.ONE


func _on_ChooseShader_pressed() -> void:
	if OS.get_name() == "HTML5":
		Html5FileExchange.load_shader()
	else:
		$FileDialog.popup_centered(Vector2(200, 340))


func _on_FileDialog_file_selected(path : String) -> void:
	var shader = load(path)
	if !shader is Shader:
		return
	preview.material.shader = shader
	shader_loaded_label.text = tr("Shader loaded:") + " " + path.get_file().get_basename()
