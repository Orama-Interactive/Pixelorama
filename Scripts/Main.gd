extends Control

var current_path := ""
var opensprite_file_selected := false
var pencil_tool
var eraser_tool
var fill_tool
var export_all_frames : CheckButton
var export_as_single_file : CheckButton
var export_vertical_spritesheet : CheckButton
var fps := 1.0
var animation_loop := false
var animation_forward := true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var file_menu_items := {
		"New..." : KEY_MASK_CTRL + KEY_N,
		#The import and export key shortcuts will change,
		#and they will be bound to Open and Save/Save as once I
		#make a custom file for Pixelorama projects
		"Import..." : KEY_MASK_CTRL + KEY_O,
		"Export..." : KEY_MASK_CTRL + KEY_S,
		"Export as..." : KEY_MASK_SHIFT + KEY_MASK_CTRL + KEY_S,
		"Quit" : KEY_MASK_CTRL + KEY_Q
		}
	var edit_menu_items := {
		"Scale Image" : 0,
		"Show Grid" : KEY_MASK_CTRL + KEY_G
		#"Undo" : KEY_MASK_CTRL + KEY_Z,
		#"Redo" : KEY_MASK_SHIFT + KEY_MASK_CTRL + KEY_Z,
		}
	var file_menu : PopupMenu = Global.file_menu.get_popup()
	var edit_menu : PopupMenu = Global.edit_menu.get_popup()
	var i = 0
	for item in file_menu_items.keys():
		file_menu.add_item(item, i, file_menu_items[item])
		i += 1
	i = 0
	for item in edit_menu_items.keys():
		edit_menu.add_item(item, i, edit_menu_items[item])
		i += 1
	file_menu.connect("id_pressed", self, "file_menu_id_pressed")
	edit_menu.connect("id_pressed", self, "edit_menu_id_pressed")
	
	pencil_tool = $UI/ToolPanel/Tools/MenusAndTools/ToolsContainer/Pencil
	eraser_tool = $UI/ToolPanel/Tools/MenusAndTools/ToolsContainer/Eraser
	fill_tool = $UI/ToolPanel/Tools/MenusAndTools/ToolsContainer/Fill
	
	pencil_tool.connect("pressed", self, "_on_Tool_pressed", [pencil_tool])
	eraser_tool.connect("pressed", self, "_on_Tool_pressed", [eraser_tool])
	fill_tool.connect("pressed", self, "_on_Tool_pressed", [fill_tool])
	
	export_all_frames = CheckButton.new()
	export_all_frames.text = "Export all frames?"
	export_as_single_file = CheckButton.new()
	export_as_single_file.text = "Export frames as a single file?"
	export_vertical_spritesheet = CheckButton.new()
	export_vertical_spritesheet.text = "Vertical spritesheet?"
	$SaveSprite.get_vbox().add_child(export_all_frames)
	$SaveSprite.get_vbox().add_child(export_as_single_file)
	$SaveSprite.get_vbox().add_child(export_vertical_spritesheet)
	
func _input(event):
	#Handle tool shortcuts
	if event.is_action_pressed("right_pencil_tool"):
		_on_Tool_pressed(pencil_tool, false, false)
	elif event.is_action_pressed("left_pencil_tool"):
		_on_Tool_pressed(pencil_tool, false, true)
	elif event.is_action_pressed("right_eraser_tool"):
		_on_Tool_pressed(eraser_tool, false, false)
	elif event.is_action_pressed("left_eraser_tool"):
		_on_Tool_pressed(eraser_tool, false, true)
	elif event.is_action_pressed("right_fill_tool"):
		_on_Tool_pressed(fill_tool, false, false)
	elif event.is_action_pressed("left_fill_tool"):
		_on_Tool_pressed(fill_tool, false, true)


func file_menu_id_pressed(id : int) -> void:
	match id:
		0: #New
			$CreateNewImage.popup_centered()
			Global.can_draw = false
		1: #Import
			$OpenSprite.popup_centered()
			Global.can_draw = false
			opensprite_file_selected = false
		2: #Export
			if current_path == "":
				$SaveSprite.popup_centered()
				Global.can_draw = false
			else:
				export_project()
		3: #Export as
			$SaveSprite.popup_centered()
			Global.can_draw = false
		4: #Quit
			get_tree().quit()

func edit_menu_id_pressed(id : int) -> void:
	match id:
		0: #Scale Image
			$ScaleImage.popup_centered()
			Global.can_draw = false
		1: #Show grid
			Global.draw_grid = !Global.draw_grid

func _on_CreateNewImage_confirmed() -> void:
	var width = float($CreateNewImage/VBoxContainer/WidthCont/WidthValue.value)
	var height = float($CreateNewImage/VBoxContainer/HeightCont/HeightValue.value)
	new_canvas(Vector2(width, height).floor())

#func _on_OpenSprite_file_selected(path : String) -> void:
#	var image = Image.new()
#	var err = image.load(path)
#	if err == OK:
#		opensprite_file_selected = true
#		new_canvas(image.get_size(), image)
#	else:
#		OS.alert("Can't load file")

func _on_OpenSprite_files_selected(paths) -> void:
	for child in Global.vbox_layer_container.get_children():
		if child is PanelContainer:
			child.queue_free()
	for child in Global.frame_container.get_children():
		child.queue_free()
	for child in Global.canvas_parent.get_children():
		if child is Canvas:
			child.queue_free()
	Global.canvases.clear()
	
	#Find the biggest image and let it handle the camera zoom options
	var max_size : Vector2
	var biggest_canvas : Canvas
	var i := 0
	for path in paths:
		var image = Image.new()
		var err = image.load(path)
		if err == OK:
			opensprite_file_selected = true
			var canvas : Canvas = load("res://Canvas.tscn").instance()
			canvas.size = image.get_size()
			image.convert(Image.FORMAT_RGBA8)
			image.lock()
			var tex := ImageTexture.new()
			tex.create_from_image(image, 0)
			#Store [Image, ImageTexture, Layer Name, Visibity boolean]
			canvas.layers.append([image, tex, "Layer 0", true])
			canvas.frame = i
			Global.canvas_parent.add_child(canvas)
			Global.canvases.append(canvas)
			canvas.visible = false
			if i == 0:
				max_size = canvas.size
				biggest_canvas = canvas
			else:
				if canvas.size > max_size:
					biggest_canvas = canvas
			
		else:
			OS.alert("Can't load file")
		
		i += 1
	Global.current_frame = i - 1
	Global.canvas = Global.canvases[Global.canvases.size() - 1]
	Global.canvas.visible = true
	Global.handle_layer_order_buttons()
	biggest_canvas.camera_zoom()
	if i > 1:
		Global.remove_frame_button.disabled = false
		Global.remove_frame_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		Global.remove_frame_button.disabled = true
		Global.remove_frame_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

func new_canvas(size : Vector2, sprite : Image = null) -> void:
	for child in Global.vbox_layer_container.get_children():
		if child is PanelContainer:
			child.queue_free()
	for child in Global.frame_container.get_children():
		child.queue_free()
	for child in Global.canvas_parent.get_children():
		if child is Canvas:
			child.queue_free()
	Global.canvases.clear()
	Global.canvas = load("res://Canvas.tscn").instance()
	Global.canvas.size = size
	
#	if sprite:
#		var layer0 := sprite
#		layer0.convert(Image.FORMAT_RGBA8)
#		var tex := ImageTexture.new()
#		tex.create_from_image(layer0, 0)
#		#Store [Image, ImageTexture, Layer Name, Visibity boolean]
#		Global.canvas.layers.append([layer0, tex, "Layer 0", true])
	Global.canvas_parent.add_child(Global.canvas)
	Global.canvases.append(Global.canvas)
	Global.current_frame = 0
	Global.remove_frame_button.disabled = true
	Global.remove_frame_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

func _on_SaveSprite_file_selected(path : String) -> void:
	current_path = path
	export_project()

func export_project() -> void:
	if export_all_frames.pressed:
		if !export_as_single_file.pressed:
			var i := 0
			for canvas in Global.canvases:
				var path := "%s_%s" % [current_path, str(i)]
				path = path.replace(".png", "")
				path = "%s.png" % path
				save_sprite(canvas, path)
				i += 1
		else:
			save_spritesheet()
	else:
		save_sprite(Global.canvas, current_path)

func save_sprite(canvas : Canvas, path : String) -> void:
	var whole_image := Image.new()
	whole_image.create(canvas.size.x, canvas.size.y, false, Image.FORMAT_RGBA8)
	for layer in canvas.layers:
		whole_image.blend_rect(layer[0], Rect2(canvas.position, canvas.size), Vector2.ZERO)
		layer[0].lock()
	var err = whole_image.save_png(path)
	if err != OK:
		OS.alert("Can't save file")

func save_spritesheet() -> void:
	var width
	var height
	if export_vertical_spritesheet.pressed:
		width = Global.canvas.size.x
		height = 0
		for canvas in Global.canvases:
			height += canvas.size.y
			if canvas.size.x > width:
				width = canvas.size.x
	else:
		width = 0
		height = Global.canvas.size.y
		for canvas in Global.canvases:
			width += canvas.size.x
			if canvas.size.y > height:
				height = canvas.size.y
	var whole_image := Image.new()
	whole_image.create(width, height, false, Image.FORMAT_RGBA8)
	var dst := Vector2.ZERO
	for canvas in Global.canvases:
		for layer in canvas.layers:
			whole_image.blend_rect(layer[0], Rect2(canvas.position, canvas.size), dst)
			layer[0].lock()
		if export_vertical_spritesheet.pressed:
			dst += Vector2(0, canvas.size.y)
		else:
			dst += Vector2(canvas.size.x, 0)
	
	var err = whole_image.save_png(current_path)
	if err != OK:
		OS.alert("Can't save file")

func _on_OpenSprite_popup_hide() -> void:
	if !opensprite_file_selected:
		Global.can_draw = true
		print(Global.can_draw)

func _on_ViewportContainer_mouse_entered() -> void:
	Global.has_focus = true

func _on_ViewportContainer_mouse_exited() -> void:
	Global.has_focus = false
	
func _can_draw_true() -> void:
	Global.can_draw = true
func _can_draw_false() -> void:
	Global.can_draw = false

func _on_Tool_pressed(tool_pressed : BaseButton, mouse_press := true, key_for_left := true) -> void:
	var current_action := tool_pressed.name
	if (mouse_press && Input.is_action_just_released("left_mouse")) || (!mouse_press && key_for_left):
		Global.current_left_tool = current_action
		Global.left_indicator.get_parent().remove_child(Global.left_indicator)
		tool_pressed.add_child(Global.left_indicator)
	elif (mouse_press && Input.is_action_just_released("right_mouse")) || (!mouse_press && !key_for_left):
		Global.current_right_tool = current_action
		Global.right_indicator.get_parent().remove_child(Global.right_indicator)
		tool_pressed.add_child(Global.right_indicator)

func _on_ScaleImage_confirmed() -> void:
	var width = float($ScaleImage/VBoxContainer/WidthCont/WidthValue.value)
	var height = float($ScaleImage/VBoxContainer/HeightCont/HeightValue.value)
	for i in range(Global.canvas.layers.size() - 1, -1, -1):
		var sprite = Image.new()
		sprite = Global.canvas.layers[i][1].get_data()
		sprite.resize(width, height, $ScaleImage/VBoxContainer/InterpolationContainer/InterpolationType.selected)
		Global.canvas.layers[i][0] = sprite
		Global.canvas.layers[i][0].lock()
		Global.canvas.update_texture(i)
	
	Global.canvas.size = Vector2(width, height).floor()
	Global.canvas.camera_zoom()

func add_layer(is_new := true) -> void:
	var new_layer := Image.new()
	if is_new:
		new_layer.create(Global.canvas.size.x, Global.canvas.size.y, false, Image.FORMAT_RGBA8)
	else: #clone layer
		new_layer.copy_from(Global.canvas.layers[Global.canvas.current_layer_index][0])
	new_layer.lock()
	var new_layer_tex := ImageTexture.new()
	new_layer_tex.create_from_image(new_layer, 0)
	Global.canvas.layers.append([new_layer, new_layer_tex, null, true])
	Global.canvas.generate_layer_panels()

func _on_AddLayerButton_pressed() -> void:
	add_layer()

func _on_RemoveLayerButton_pressed() -> void:
	Global.canvas.layers.remove(Global.canvas.current_layer_index)
	Global.canvas.generate_layer_panels()

func _on_MoveUpLayer_pressed() -> void:
	change_layer_order(1)

func _on_MoveDownLayer_pressed() -> void:
	change_layer_order(-1)

func change_layer_order(rate : int) -> void:
	var change = Global.canvas.current_layer_index + rate
	
	var temp = Global.canvas.layers[Global.canvas.current_layer_index]
	Global.canvas.layers[Global.canvas.current_layer_index] = Global.canvas.layers[change]
	Global.canvas.layers[change] = temp
	
	Global.canvas.generate_layer_panels()
	Global.canvas.current_layer_index = change
	Global.canvas.get_layer_container(Global.canvas.current_layer_index).changed_selection()
	
func _on_CloneLayer_pressed() -> void:
	add_layer(false)

func _on_MergeLayer_pressed() -> void:
	var selected_layer = Global.canvas.layers[Global.canvas.current_layer_index][0]
	Global.canvas.layers[Global.canvas.current_layer_index - 1][0].blend_rect(selected_layer, Rect2(Global.canvas.position, Global.canvas.size), Vector2.ZERO)
	Global.canvas.layers[Global.canvas.current_layer_index - 1][0].lock()
	Global.canvas.update_texture(Global.canvas.current_layer_index - 1)
	_on_RemoveLayerButton_pressed()

func _on_LeftIndicatorCheckbox_toggled(button_pressed) -> void:
	Global.left_square_indicator_visible = button_pressed

func _on_RightIndicatorCheckbox_toggled(button_pressed) -> void:
	Global.right_square_indicator_visible = button_pressed

func _on_LeftBrushSizeEdit_value_changed(value) -> void:
	var new_size = int(value)
	Global.left_brush_size = new_size

func _on_RightBrushSizeEdit_value_changed(value) -> void:
	var new_size = int(value)
	Global.right_brush_size = new_size

func _on_AddFrame_pressed() -> void:
	var canvas = load("res://Canvas.tscn").instance()
	canvas.size = Global.canvas.size
	Global.current_frame = Global.canvases.size()
	canvas.frame = Global.current_frame
	for canvas in Global.canvases:
		canvas.visible = false
	Global.canvases.append(canvas)
	Global.canvas = canvas
	
	Global.canvas_parent.add_child(canvas)
	Global.remove_frame_button.disabled = false
	Global.remove_frame_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Global.move_left_frame_button.disabled = false
	Global.move_left_frame_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_RemoveFrame_pressed() -> void:
	Global.canvas.frame_button.queue_free()
	Global.canvas.queue_free()
	Global.canvases.remove(Global.current_frame)
	for canvas in Global.canvases:
		if canvas.frame > Global.current_frame:
			canvas.frame -= 1
			canvas.frame_button.get_node("FrameButton").frame = canvas.frame
			canvas.frame_button.get_node("FrameID").text = str(canvas.frame)
	if Global.current_frame > 0:
		Global.current_frame -= 1
	if len(Global.canvases) == 1:
		Global.remove_frame_button.disabled = true
		Global.remove_frame_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	Global.canvas = Global.canvases[Global.current_frame]
	Global.canvas.visible = true
	Global.canvas.generate_layer_panels()
	Global.handle_layer_order_buttons()


func _on_CloneFrame_pressed() -> void:
	var canvas = load("res://Canvas.tscn").instance()
	canvas.size = Global.canvas.size
	#canvas.layers = Global.canvas.layers.duplicate(true)
	for layer in Global.canvas.layers:
		var sprite := Image.new()
		sprite.copy_from(layer[0])
		sprite.lock()
		var tex := ImageTexture.new()
		tex.create_from_image(sprite, 0)
		canvas.layers.append([sprite, tex, layer[2], layer[3]])
	Global.current_frame = Global.canvases.size()
	canvas.frame = Global.current_frame
	for canvas in Global.canvases:
		canvas.visible = false
	Global.canvases.append(canvas)
	Global.canvas = canvas
	
	Global.canvas_parent.add_child(canvas)
	Global.remove_frame_button.disabled = false
	Global.remove_frame_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Global.move_left_frame_button.disabled = false
	Global.move_left_frame_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_MoveFrameLeft_pressed() -> void:
	change_frame_order(-1)

func _on_MoveFrameRight_pressed() -> void:
	change_frame_order(1)

func change_frame_order(rate : int) -> void:
	var frame_button = Global.frame_container.get_node("Frame_%s" % Global.current_frame)
	var change = Global.current_frame + rate
	
	var temp = Global.canvases[Global.current_frame]
	Global.canvases[Global.current_frame] = Global.canvases[change]
	Global.canvases[change] = temp
	
	#Clear frame button names first, to avoid duplicates like two Frame_0s
	for canvas in Global.canvases:
		canvas.frame_button.name = "frame"
	
	for canvas in Global.canvases:
		canvas.frame = Global.canvases.find(canvas)
		canvas.frame_button.name = "Frame_%s" % canvas.frame
		canvas.frame_button.get_node("FrameButton").frame = canvas.frame
		canvas.frame_button.get_node("FrameID").text = str(canvas.frame)
	
	Global.current_frame = change
	Global.frame_container.move_child(frame_button, Global.current_frame)
	Global.canvas_parent.move_child(Global.canvas, Global.current_frame)
	#Global.canvas.generate_layer_panels()
	Global.handle_layer_order_buttons()


func _on_PlayForward_toggled(button_pressed) -> void:
	Global.play_backwards.pressed = false
	Global.play_backwards.text = "Play Backwards"
	
	if button_pressed:
		Global.play_forward.text = "Stop"
		$AnimationTimer.wait_time = 1 / fps
		$AnimationTimer.start()
		animation_forward = true
	else:
		Global.play_forward.text = "Play Forward"
		$AnimationTimer.stop()

func _on_PlayBackwards_toggled(button_pressed) -> void:
	Global.play_forward.pressed = false
	Global.play_forward.text = "Play Forward"
	
	if button_pressed:
		Global.play_backwards.text = "Stop"
		$AnimationTimer.wait_time = 1 / fps
		$AnimationTimer.start()
		animation_forward = false
	else:
		Global.play_backwards.text = "Play Backwards"
		$AnimationTimer.stop()

func _on_AnimationTimer_timeout() -> void:
	if animation_forward:
		if Global.current_frame < Global.canvases.size() - 1:
			Global.current_frame += 1
		else:
			if animation_loop:
				Global.current_frame = 0
			else:
				Global.play_forward.pressed = false
				Global.play_forward.text = "Play Forward"
				$AnimationTimer.stop()
	else:
		if Global.current_frame > 0:
			Global.current_frame -= 1
		else:
			if animation_loop:
				Global.current_frame = Global.canvases.size() - 1
			else:
				Global.play_backwards.pressed = false
				Global.play_backwards.text = "Play Backwards"
				$AnimationTimer.stop()
	
	Global.change_frame()

func _on_FPSValue_value_changed(value) -> void:
	fps = float(value)
	$AnimationTimer.wait_time = 1 / fps

func _on_LoopAnim_toggled(button_pressed) -> void:
	animation_loop = button_pressed