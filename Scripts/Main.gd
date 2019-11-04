extends Control

var current_save_path := ""
var current_export_path := ""
var opensprite_file_selected := false
var view_menu : PopupMenu
var tools := []
var import_as_new_frame : CheckBox
var export_all_frames : CheckBox
var export_as_single_file : CheckBox
var export_vertical_spritesheet : CheckBox
var fps := 1.0
var animation_loop := 0 #0 is no loop, 1 is cycle loop, 2 is ping-pong loop
var animation_forward := true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	OS.set_window_title("Pixelorama %s" % ProjectSettings.get_setting("application/config/Version"))
	# Set a minimum window size to prevent UI elements from collapsing on each other.
	# This property is only available in 3.2alpha or later, so use `set()` to fail gracefully if it doesn't exist.
	OS.set("min_window_size", Vector2(1024, 600))

	var file_menu_items := {
		"New..." : KEY_MASK_CTRL + KEY_N,
		"Open..." : KEY_MASK_CTRL + KEY_O,
		"Save..." : KEY_MASK_CTRL + KEY_S,
		"Save as..." : KEY_MASK_SHIFT + KEY_MASK_CTRL + KEY_S,
		"Import..." : KEY_MASK_CTRL + KEY_I,
		"Export..." : KEY_MASK_CTRL + KEY_E,
		"Export as..." : KEY_MASK_SHIFT + KEY_MASK_CTRL + KEY_E,
		"Quit" : KEY_MASK_CTRL + KEY_Q
		}
	var edit_menu_items := {
		"Undo" : KEY_MASK_CTRL + KEY_Z,
		"Redo" : KEY_MASK_SHIFT + KEY_MASK_CTRL + KEY_Z,
		"Scale Image" : 0,
		"Crop Image" : 0,
		"Clear Selection" : 0,
		"Flip Horizontal": KEY_MASK_SHIFT + KEY_H,
		"Flip Vertical": KEY_MASK_SHIFT + KEY_V
		}
	var view_menu_items := {
		"Tile Mode" : KEY_MASK_CTRL + KEY_T,
		"Show Grid" : KEY_MASK_CTRL + KEY_G
		}
	var help_menu_items := {
			"About Pixelorama" : 0
		}
	var file_menu : PopupMenu = Global.file_menu.get_popup()
	var edit_menu : PopupMenu = Global.edit_menu.get_popup()
	view_menu = Global.view_menu.get_popup()
	var help_menu : PopupMenu = Global.help_menu.get_popup()

	var i = 0
	for item in file_menu_items.keys():
		file_menu.add_item(item, i, file_menu_items[item])
		i += 1
	i = 0
	for item in edit_menu_items.keys():
		edit_menu.add_item(item, i, edit_menu_items[item])
		i += 1
	i = 0
	for item in view_menu_items.keys():
		view_menu.add_check_item(item, i, view_menu_items[item])
		i += 1
	i = 0
	for item in help_menu_items.keys():
		help_menu.add_item(item, i, help_menu_items[item])
		i += 1

	file_menu.connect("id_pressed", self, "file_menu_id_pressed")
	edit_menu.connect("id_pressed", self, "edit_menu_id_pressed")
	view_menu.connect("id_pressed", self, "view_menu_id_pressed")
	help_menu.connect("id_pressed", self, "help_menu_id_pressed")

	var root = get_tree().get_root()
	#Node, left mouse shortcut, right mouse shortcut
	tools.append([Global.find_node_by_name(root, "Pencil"), "left_pencil_tool", "right_pencil_tool"])
	tools.append([Global.find_node_by_name(root, "Eraser"), "left_eraser_tool", "right_eraser_tool"])
	tools.append([Global.find_node_by_name(root, "Fill"), "left_fill_tool", "right_fill_tool"])
	tools.append([Global.find_node_by_name(root, "PaintAllPixelsSameColor"), "left_paint_all_tool", "right_paint_all_tool"])
	tools.append([Global.find_node_by_name(root, "LightenDarken"), "left_lightdark_tool", "right_lightdark_tool"])
	tools.append([Global.find_node_by_name(root, "RectSelect"), "left_rectangle_select_tool", "right_rectangle_select_tool"])

	for t in tools:
		t[0].connect("pressed", self, "_on_Tool_pressed", [t[0]])

	#Options for Import
	import_as_new_frame = CheckBox.new()
	import_as_new_frame.text = "Import as new frame?"
	$ImportSprites.get_vbox().add_child(import_as_new_frame)

	#Options for Export
	export_all_frames = CheckBox.new()
	export_all_frames.text = "Export all frames?"
	export_as_single_file = CheckBox.new()
	export_as_single_file.text = "Export frames as a single file?"
	export_vertical_spritesheet = CheckBox.new()
	export_vertical_spritesheet.text = "Vertical spritesheet?"
	$ExportSprites.get_vbox().add_child(export_all_frames)
	$ExportSprites.get_vbox().add_child(export_as_single_file)
	$ExportSprites.get_vbox().add_child(export_vertical_spritesheet)


func _input(event):
	for t in tools: #Handle tool shortcuts
		if event.is_action_pressed(t[2]): #Shortcut for right button (with Alt)
			_on_Tool_pressed(t[0], false, false)
		elif event.is_action_pressed(t[1]): #Shortcut for left button
			_on_Tool_pressed(t[0], false, true)

func file_menu_id_pressed(id : int) -> void:
	match id:
		0: #New
			$CreateNewImage.popup_centered()
			Global.can_draw = false
		1: #Open
			$OpenSprite.popup_centered()
			Global.can_draw = false
			opensprite_file_selected = false
		2: #Save
			if current_save_path == "":
				$SaveSprite.popup_centered()
				Global.can_draw = false
			else:
				_on_SaveSprite_file_selected(current_save_path)
		3: #Save as
			$SaveSprite.popup_centered()
			Global.can_draw = false
		4: #Import
			$ImportSprites.popup_centered()
			Global.can_draw = false
			opensprite_file_selected = false
		5: #Export
			if current_export_path == "":
				$ExportSprites.popup_centered()
				Global.can_draw = false
			else:
				export_project()
		6: #Export as
			$ExportSprites.popup_centered()
			Global.can_draw = false
		7: #Quit
			get_tree().quit()

func edit_menu_id_pressed(id : int) -> void:
	match id:
		0: #Undo
			Global.undo_redo.undo()
		1: #Redo
			Global.undo_redo.redo()
		2: #Scale Image
			$ScaleImage.popup_centered()
			Global.can_draw = false
		3: #Crop Image
			#Use first layer as a starting rectangle
			var used_rect : Rect2 = Global.canvas.layers[0][0].get_used_rect()
			#However, if first layer is empty, loop through all layers until we find one that isn't
			var i := 0
			while(i < Global.canvas.layers.size() - 1 && Global.canvas.layers[i][0].get_used_rect() == Rect2(0, 0, 0, 0)):
				i += 1
				used_rect = Global.canvas.layers[i][0].get_used_rect()

			#Merge all layers with content
			for j in range(Global.canvas.layers.size() - 1, i, -1):
					if Global.canvas.layers[j][0].get_used_rect() != Rect2(0, 0, 0, 0):
						used_rect = used_rect.merge(Global.canvas.layers[j][0].get_used_rect())

			#If no layer has any content, just return
			if used_rect == Rect2(0, 0, 0, 0):
				return

			#Loop through all the layers to crop them
			for j in range(Global.canvas.layers.size() - 1, -1, -1):
				var sprite := Image.new()
				sprite = Global.canvas.layers[j][0].get_rect(used_rect)
				Global.canvas.layers[j][0] = sprite
				Global.canvas.layers[j][0].lock()
				Global.canvas.update_texture(j)

			var width = Global.canvas.layers[0][0].get_width()
			var height = Global.canvas.layers[0][0].get_height()
			Global.canvas.size = Vector2(width, height).floor()
			Global.canvas.camera_zoom()
		4: #Clear selection
			Global.canvas.handle_undo("Rectangle Select")
			Global.selection_rectangle.polygon[0] = Vector2.ZERO
			Global.selection_rectangle.polygon[1] = Vector2.ZERO
			Global.selection_rectangle.polygon[2] = Vector2.ZERO
			Global.selection_rectangle.polygon[3] = Vector2.ZERO
			Global.selected_pixels.clear()
			Global.canvas.handle_redo("Rectangle Select")
		5: # Flip Horizontal
			var canvas : Canvas = Global.canvas
			canvas.handle_undo("Draw")
			canvas.layers[canvas.current_layer_index][0].unlock()
			canvas.layers[canvas.current_layer_index][0].flip_x()
			canvas.layers[canvas.current_layer_index][0].lock()
			canvas.handle_redo("Draw")
		6: # Flip Vertical
			var canvas : Canvas = Global.canvas
			canvas.handle_undo("Draw")
			canvas.layers[canvas.current_layer_index][0].unlock()
			canvas.layers[canvas.current_layer_index][0].flip_y()
			canvas.layers[canvas.current_layer_index][0].lock()
			canvas.handle_redo("Draw")

func view_menu_id_pressed(id : int) -> void:
	match id:
		0: #Tile mode
			Global.tile_mode = !Global.tile_mode
			view_menu.set_item_checked(0, Global.tile_mode)
		1: #Show grid
			Global.draw_grid = !Global.draw_grid
			view_menu.set_item_checked(1, Global.draw_grid)

func help_menu_id_pressed(id : int) -> void:
	match id:
		0: #About Pixelorama
			$AboutDialog.popup_centered()
			Global.can_draw = false

func _on_CreateNewImage_confirmed() -> void:
	var width = $CreateNewImage/VBoxContainer/WidthCont/WidthValue.value
	var height = $CreateNewImage/VBoxContainer/HeightCont/HeightValue.value
	var fill_color : Color = $CreateNewImage/VBoxContainer/FillColor/FillColor.color
	clear_canvases()
	Global.canvas = load("res://Prefabs/Canvas.tscn").instance()
	Global.canvas.size = Vector2(width, height).floor()

	Global.canvas_parent.add_child(Global.canvas)
	Global.canvases.append(Global.canvas)
	Global.current_frame = 0
	if fill_color.a > 0:
		Global.canvas.layers[0][0].fill(fill_color)
		Global.canvas.layers[0][0].lock()
		Global.canvas.update_texture(0)
	Global.remove_frame_button.disabled = true
	Global.remove_frame_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

func _on_OpenSprite_file_selected(path) -> void:
	var file := File.new()
	var err := file.open(path, File.READ)
	if err == 0:
		var current_version : String = ProjectSettings.get_setting("application/config/Version")
		var version := file.get_line()
		if current_version != version:
			OS.alert("File is from an older version of Pixelorama, as such it might not work properly")
		var frame := 0
		var frame_line := file.get_line()
		clear_canvases()
		while frame_line == "--":
			var canvas : Canvas = load("res://Prefabs/Canvas.tscn").instance()
			Global.canvas = canvas
			var width := file.get_16()
			var height := file.get_16()

			var layer := 0
			var layer_line := file.get_line()

			while layer_line == "-":
				var buffer := file.get_buffer(width * height * 4)
				var image := Image.new()
				image.create_from_data(width, height, false, Image.FORMAT_RGBA8, buffer)
				image.lock()
				var tex := ImageTexture.new()
				tex.create_from_image(image, 0)
				canvas.layers.append([image, tex, "Layer %s" % layer, true])
				layer_line = file.get_line()
				layer += 1

			canvas.size = Vector2(width, height)
			Global.canvases.append(canvas)
			canvas.frame = frame
			Global.canvas_parent.add_child(canvas)
			frame_line = file.get_line()
			frame += 1

		Global.current_frame = frame - 1
		#Load tool options
		Global.left_color_picker.color = file.get_var()
		Global.right_color_picker.color = file.get_var()
		Global.left_brush_size = file.get_8()
		Global.left_brush_size_edit.value = Global.left_brush_size
		Global.right_brush_size = file.get_8()
		Global.right_brush_size_edit.value = Global.right_brush_size
		var left_palette = file.get_var()
		var right_palette = file.get_var()
		for color in left_palette:
			Global.left_color_picker.get_picker().add_preset(color)
		for color in right_palette:
			Global.right_color_picker.get_picker().add_preset(color)

		#Load custom brushes
		Global.custom_brushes.clear()
		Global.remove_brush_buttons()

		var brush_line := file.get_line()
		while brush_line == "/":
			var b_width := file.get_16()
			var b_height := file.get_16()
			var buffer := file.get_buffer(b_width * b_height * 4)
			var image := Image.new()
			image.create_from_data(b_width, b_height, false, Image.FORMAT_RGBA8, buffer)
			Global.custom_brushes.append(image)
			Global.create_brush_button(image)
			brush_line = file.get_line()

	file.close()

func _on_SaveSprite_file_selected(path) -> void:
	current_save_path = path
	var file := File.new()
	var err := file.open(path, File.WRITE)
	if err == 0:
		file.store_line(ProjectSettings.get_setting("application/config/Version"))
		for canvas in Global.canvases:
			file.store_line("--")
			file.store_16(canvas.size.x)
			file.store_16(canvas.size.y)
			for layer in canvas.layers:
				file.store_line("-")
				file.store_buffer(layer[0].get_data())
			file.store_line("END_LAYERS")
		file.store_line("END_FRAMES")

		#Save tool options
		var left_color := Global.left_color_picker.color
		var right_color := Global.right_color_picker.color
		var left_brush_size := Global.left_brush_size
		var right_brush_size := Global.right_brush_size
		var left_palette := Global.left_color_picker.get_picker().get_presets()
		var right_palette := Global.right_color_picker.get_picker().get_presets()
		file.store_var(left_color)
		file.store_var(right_color)
		file.store_8(left_brush_size)
		file.store_8(right_brush_size)
		file.store_var(left_palette)
		file.store_var(right_palette)
		#Save custom brushes
		for brush in Global.custom_brushes:
			file.store_line("/")
			file.store_16(brush.get_size().x)
			file.store_16(brush.get_size().y)
			file.store_buffer(brush.get_data())
		file.store_line("END_BRUSHES")
	file.close()

func _on_ImportSprites_files_selected(paths) -> void:
	if !import_as_new_frame.pressed: #If we're not adding a new frame, delete the previous
		clear_canvases()

	#Find the biggest image and let it handle the camera zoom options
	var max_size : Vector2
	var biggest_canvas : Canvas
	var i := Global.canvases.size()
	for path in paths:
		var image = Image.new()
		var err = image.load(path)
		if err == OK:
			opensprite_file_selected = true
			var canvas : Canvas = load("res://Prefabs/Canvas.tscn").instance()
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
			if path == paths[0]: #If it's the first file
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

func clear_canvases() -> void:
	for child in Global.vbox_layer_container.get_children():
		if child is PanelContainer:
			child.queue_free()
	for child in Global.frame_container.get_children():
		child.queue_free()
	for child in Global.canvas_parent.get_children():
		if child is Canvas:
			child.queue_free()
	Global.canvases.clear()

func _on_ExportSprites_file_selected(path : String) -> void:
	current_export_path = path
	export_project()

func export_project() -> void:
	if export_all_frames.pressed:
		if !export_as_single_file.pressed:
			var i := 1
			for canvas in Global.canvases:
				var path := "%s_%s" % [current_export_path, str(i)]
				path = path.replace(".png", "")
				path = "%s.png" % path
				save_sprite(canvas, path)
				i += 1
		else:
			save_spritesheet()
	else:
		save_sprite(Global.canvas, current_export_path)

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
	if export_vertical_spritesheet.pressed: #Vertical spritesheet
		width = Global.canvas.size.x
		height = 0
		for canvas in Global.canvases:
			height += canvas.size.y
			if canvas.size.x > width:
				width = canvas.size.x
	else: #Horizontal spritesheet
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

	var err = whole_image.save_png(current_export_path)
	if err != OK:
		OS.alert("Can't save file")

func _on_ImportSprites_popup_hide() -> void:
	if !opensprite_file_selected:
		Global.can_draw = true

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
	var width = $ScaleImage/VBoxContainer/WidthCont/WidthValue.value
	var height = $ScaleImage/VBoxContainer/HeightCont/HeightValue.value
	var interpolation = $ScaleImage/VBoxContainer/InterpolationContainer/InterpolationType.selected
	for i in range(Global.canvas.layers.size() - 1, -1, -1):
		var sprite := Image.new()
		sprite = Global.canvas.layers[i][1].get_data()
		sprite.resize(width, height, interpolation)
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
	update_left_custom_brush()

func _on_RightBrushSizeEdit_value_changed(value) -> void:
	var new_size = int(value)
	Global.right_brush_size = new_size
	update_right_custom_brush()

func _on_AddFrame_pressed() -> void:
	var canvas = load("res://Prefabs/Canvas.tscn").instance()
	canvas.size = Global.canvas.size
	canvas.frame = Global.canvases.size()
	for canvas in Global.canvases:
		canvas.visible = false
	Global.canvases.append(canvas)
	Global.current_frame = Global.canvases.size() - 1
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
			canvas.frame_button.get_node("FrameID").text = str(canvas.frame + 1)
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
	var canvas = load("res://Prefabs/Canvas.tscn").instance()
	canvas.size = Global.canvas.size
	#canvas.layers = Global.canvas.layers.duplicate(true)
	for layer in Global.canvas.layers:
		var sprite := Image.new()
		sprite.copy_from(layer[0])
		sprite.lock()
		var tex := ImageTexture.new()
		tex.create_from_image(sprite, 0)
		canvas.layers.append([sprite, tex, layer[2], layer[3]])
	canvas.frame = Global.canvases.size()
	for canvas in Global.canvases:
		canvas.visible = false
	Global.canvases.append(canvas)
	Global.current_frame = Global.canvases.size() - 1
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
		canvas.frame_button.get_node("FrameID").text = str(canvas.frame + 1)

	Global.current_frame = change
	Global.frame_container.move_child(frame_button, Global.current_frame)
	Global.canvas_parent.move_child(Global.canvas, Global.current_frame)
	#Global.canvas.generate_layer_panels()
	Global.handle_layer_order_buttons()

func _on_LoopAnim_pressed() -> void:
	match Global.loop_animation_button.text:
		"No":
			#Make it loop
			animation_loop = 1
			Global.loop_animation_button.text = "Cycle"
		"Cycle":
			#Make it ping-pong
			animation_loop = 2
			Global.loop_animation_button.text = "Ping-Pong"
		"Ping-Pong":
			#Make it stop
			animation_loop = 0
			Global.loop_animation_button.text = "No"

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
			match animation_loop:
				0: #No loop
					Global.play_forward.pressed = false
					Global.play_forward.text = "Play Forward"
					Global.play_backwards.pressed = false
					Global.play_backwards.text = "Play Backwards"
					$AnimationTimer.stop()
				1: #Cycle loop
					Global.current_frame = 0
				2: #Ping pong loop
					animation_forward = false
					_on_AnimationTimer_timeout()

	else:
		if Global.current_frame > 0:
			Global.current_frame -= 1
		else:
			match animation_loop:
				0: #No loop
					Global.play_backwards.pressed = false
					Global.play_backwards.text = "Play Backwards"
					Global.play_forward.pressed = false
					Global.play_forward.text = "Play Forward"
					$AnimationTimer.stop()
				1: #Cycle loop
					Global.current_frame = Global.canvases.size() - 1
				2: #Ping pong loop
					animation_forward = true
					_on_AnimationTimer_timeout()

	Global.change_frame()

func _on_FPSValue_value_changed(value) -> void:
	fps = float(value)
	$AnimationTimer.wait_time = 1 / fps

func _on_PastOnionSkinning_value_changed(value) -> void:
	Global.onion_skinning_past_rate = int(value)

func _on_FutureOnionSkinning_value_changed(value) -> void:
	Global.onion_skinning_future_rate = int(value)

func _on_BlueRedMode_toggled(button_pressed) -> void:
	Global.onion_skinning_blue_red = button_pressed

func _on_SplitScreenButton_toggled(button_pressed) -> void:
	if button_pressed:
		Global.split_screen_button.text = ">"
		Global.viewport_separator.visible = true
		Global.second_viewport.visible = true
	else:
		Global.split_screen_button.text = "<"
		Global.viewport_separator.visible = false
		Global.second_viewport.visible = false

# warning-ignore:unused_argument
func _on_LeftColorPickerButton_color_changed(color : Color) -> void:
	update_left_custom_brush()

# warning-ignore:unused_argument
func _on_RightColorPickerButton_color_changed(color : Color) -> void:
	update_right_custom_brush()

# warning-ignore:unused_argument
func _on_LeftInterpolateFactor_value_changed(value : float) -> void:
	update_left_custom_brush()

# warning-ignore:unused_argument
func _on_RightInterpolateFactor_value_changed(value : float) -> void:
	update_right_custom_brush()

func update_left_custom_brush() -> void:
	Global.update_left_custom_brush()
func update_right_custom_brush() -> void:
	Global.update_right_custom_brush()

func _on_LeftHorizontalMirroring_toggled(button_pressed) -> void:
	Global.left_horizontal_mirror = button_pressed
func _on_LeftVerticalMirroring_toggled(button_pressed) -> void:
	Global.left_vertical_mirror = button_pressed

func _on_RightHorizontalMirroring_toggled(button_pressed) -> void:
	Global.right_horizontal_mirror = button_pressed
func _on_RightVerticalMirroring_toggled(button_pressed) -> void:
	Global.right_vertical_mirror = button_pressed
