extends Control

var config_cache : ConfigFile = ConfigFile.new()
var current_save_path := ""
var current_export_path := ""
var opensprite_file_selected := false
var view_menu : PopupMenu
var tools := []
var import_as_new_frame : CheckBox
var export_all_frames : CheckBox
var export_as_single_file : CheckBox
var export_vertical_spritesheet : CheckBox
var redone := false
var fps := 6.0
var animation_loop := 0 #0 is no loop, 1 is cycle loop, 2 is ping-pong loop
var animation_forward := true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	OS.set_window_title("(untitled) - Pixelorama")
	# Set a minimum window size to prevent UI elements from collapsing on each other.
	# This property is only available in 3.2alpha or later, so use `set()` to fail gracefully if it doesn't exist.
	OS.set("min_window_size", Vector2(1152, 648))

	# Restore the window position/size if values are present in the configuration cache
	config_cache.load("user://cache.ini")

	if config_cache.has_section_key("window", "screen"):
		OS.current_screen = config_cache.get_value("window", "screen")
	if config_cache.has_section_key("window", "maximized"):
		OS.window_maximized = config_cache.get_value("window", "maximized")

	if !OS.window_maximized:
		if config_cache.has_section_key("window", "position"):
			OS.window_position = config_cache.get_value("window", "position")
		if config_cache.has_section_key("window", "size"):
			OS.window_size = config_cache.get_value("window", "size")

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
	tools.append([Global.find_node_by_name(root, "Bucket"), "left_fill_tool", "right_fill_tool"])
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

	var path := "Brushes"
	var brushes_dir := Directory.new()
	if !brushes_dir.dir_exists(path):
		brushes_dir.make_dir(path)

	brushes_dir.open(path)
	brushes_dir.list_dir_begin(true, true)
	var file := brushes_dir.get_next()
	while file != "":
		if file.get_extension().to_upper() == "PNG":
			var image := Image.new()
			var err := image.load(path.plus_file(file))
			if err == OK:
				image.convert(Image.FORMAT_RGBA8)
				Global.custom_brushes.append(image)
				Global.create_brush_button(image, Global.BRUSH_TYPES.FILE)
		file = brushes_dir.get_next()
	brushes_dir.list_dir_end()
	Global.brushes_from_files = Global.custom_brushes.size()

func _input(event):
	if event.is_action_pressed("toggle_fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen

	if Global.has_focus:
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
			redone = true
			Global.undo_redo.redo()
			redone = false
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

			var width := used_rect.size.x
			var height := used_rect.size.y
			Global.undos += 1
			Global.undo_redo.create_action("Scale")
			Global.undo_redo.add_do_property(Global.canvas, "size", Vector2(width, height).floor())
			#Loop through all the layers to crop them
			for j in range(Global.canvas.layers.size() - 1, -1, -1):
				var sprite : Image = Global.canvas.layers[j][0].get_rect(used_rect)
				Global.undo_redo.add_do_property(Global.canvas.layers[j][0], "data", sprite.data)
				Global.undo_redo.add_undo_property(Global.canvas.layers[j][0], "data", Global.canvas.layers[j][0].data)

			Global.undo_redo.add_undo_property(Global.canvas, "size", Global.canvas.size)
			Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
			Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
			Global.undo_redo.commit_action()
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
			
			# Sprite changed this frame, so update is needed
			canvas.update_texture(canvas.current_layer_index)
		6: # Flip Vertical
			var canvas : Canvas = Global.canvas
			canvas.handle_undo("Draw")
			canvas.layers[canvas.current_layer_index][0].unlock()
			canvas.layers[canvas.current_layer_index][0].flip_y()
			canvas.layers[canvas.current_layer_index][0].lock()
			canvas.handle_redo("Draw")
			
			# Sprite changed this frame, so update is needed
			canvas.update_texture(canvas.current_layer_index)

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
	Global.undo_redo.clear_history(false)

func _on_OpenSprite_file_selected(path : String) -> void:
	var file := File.new()
	var err := file.open(path, File.READ)
	if err != OK: #An error occured
		file.close()
		OS.alert("Can't load file")
		return

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
		var layer_line := file.get_line()

		while layer_line == "-":
			var buffer := file.get_buffer(width * height * 4)
			var layer_name := file.get_line()
			var image := Image.new()
			image.create_from_data(width, height, false, Image.FORMAT_RGBA8, buffer)
			image.lock()
			var tex := ImageTexture.new()
			tex.create_from_image(image, 0)
			canvas.layers.append([image, tex, layer_name, true])
			layer_line = file.get_line()

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
	#Global.custom_brushes.clear()
	Global.custom_brushes.resize(Global.brushes_from_files)
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
	Global.undo_redo.clear_history(false)

	OS.set_window_title(path.get_file() + " - Pixelorama")


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
				file.store_line(layer[2])
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
		for i in range(Global.brushes_from_files, Global.custom_brushes.size()):
			var brush = Global.custom_brushes[i]
			file.store_line("/")
			file.store_16(brush.get_size().x)
			file.store_16(brush.get_size().y)
			file.store_buffer(brush.get_data())
		file.store_line("END_BRUSHES")
	file.close()
	Global.notification_label("File saved")

func _on_ImportSprites_files_selected(paths) -> void:
	if !import_as_new_frame.pressed: #If we're not adding a new frame, delete the previous
		clear_canvases()

	#Find the biggest image and let it handle the camera zoom options
	var max_size : Vector2
	var biggest_canvas : Canvas
	var i := Global.canvases.size()
	for path in paths:
		var image := Image.new()
		var err := image.load(path)
		if err != OK: #An error occured
			OS.alert("Can't load file")
			continue

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

		i += 1
	Global.current_frame = i - 1
	Global.canvas = Global.canvases[Global.canvases.size() - 1]
	Global.canvas.visible = true
	biggest_canvas.camera_zoom()

	Global.undo_redo.clear_history(false)

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
	current_save_path = ""
	current_export_path = ""

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
	Global.notification_label("File exported")

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

func _on_ScaleImage_confirmed() -> void:
	var width = $ScaleImage/VBoxContainer/WidthCont/WidthValue.value
	var height = $ScaleImage/VBoxContainer/HeightCont/HeightValue.value
	var interpolation = $ScaleImage/VBoxContainer/InterpolationContainer/InterpolationType.selected
	Global.undos += 1
	Global.undo_redo.create_action("Scale")
	Global.undo_redo.add_do_property(Global.canvas, "size", Vector2(width, height).floor())

	for i in range(Global.canvas.layers.size() - 1, -1, -1):
		var sprite : Image = Global.canvas.layers[i][1].get_data()
		sprite.resize(width, height, interpolation)
		Global.undo_redo.add_do_property(Global.canvas.layers[i][0], "data", sprite.data)
		Global.undo_redo.add_undo_property(Global.canvas.layers[i][0], "data", Global.canvas.layers[i][0].data)

	Global.undo_redo.add_undo_property(Global.canvas, "size", Global.canvas.size)
	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()

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
	elif (mouse_press && Input.is_action_just_released("right_mouse")) || (!mouse_press && !key_for_left):
		Global.current_right_tool = current_action

	for t in tools:
		var tool_name : String = t[0].name
		if tool_name == "PaintAllPixelsSameColor":
			continue
		if tool_name == Global.current_left_tool && tool_name == Global.current_right_tool:
			t[0].texture_normal = load("res://Assets/Graphics/Tools/%s_l_r.png" % tool_name)
		elif tool_name == Global.current_left_tool:
			t[0].texture_normal = load("res://Assets/Graphics/Tools/%s_l.png" % tool_name)
		elif tool_name == Global.current_right_tool:
			t[0].texture_normal = load("res://Assets/Graphics/Tools/%s_r.png" % tool_name)
		else:
			t[0].texture_normal = load("res://Assets/Graphics/Tools/%s.png" % tool_name)

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

func add_layer(is_new := true) -> void:
	var new_layer := Image.new()
	if is_new:
		new_layer.create(Global.canvas.size.x, Global.canvas.size.y, false, Image.FORMAT_RGBA8)
	else: #clone layer
		new_layer.copy_from(Global.canvas.layers[Global.canvas.current_layer_index][0])
	new_layer.lock()
	var new_layer_tex := ImageTexture.new()
	new_layer_tex.create_from_image(new_layer, 0)

	var new_layers := Global.canvas.layers.duplicate()
	new_layers.append([new_layer, new_layer_tex, null, true])
	Global.undos += 1
	Global.undo_redo.create_action("Add Layer")
	Global.undo_redo.add_do_property(Global.canvas, "layers", new_layers)
	Global.undo_redo.add_undo_property(Global.canvas, "layers", Global.canvas.layers)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()

func _on_RemoveLayerButton_pressed() -> void:
	var new_layers := Global.canvas.layers.duplicate()
	new_layers.remove(Global.canvas.current_layer_index)
	Global.undos += 1
	Global.undo_redo.create_action("Remove Layer")
	Global.undo_redo.add_do_property(Global.canvas, "layers", new_layers)
	Global.undo_redo.add_undo_property(Global.canvas, "layers", Global.canvas.layers)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()

func change_layer_order(rate : int) -> void:
	var change = Global.canvas.current_layer_index + rate

	var new_layers := Global.canvas.layers.duplicate()
	var temp = new_layers[Global.canvas.current_layer_index]
	new_layers[Global.canvas.current_layer_index] = new_layers[change]
	new_layers[change] = temp
	Global.undo_redo.create_action("Change Layer Order")
	Global.undo_redo.add_do_property(Global.canvas, "layers", new_layers)
	Global.undo_redo.add_do_property(Global.canvas, "current_layer_index", change)
	Global.undo_redo.add_undo_property(Global.canvas, "layers", Global.canvas.layers)
	Global.undo_redo.add_undo_property(Global.canvas, "current_layer_index", Global.canvas.current_layer_index)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()

func _on_MergeLayer_pressed() -> void:
	var new_layers := Global.canvas.layers.duplicate()
	new_layers.remove(Global.canvas.current_layer_index)
	var selected_layer = Global.canvas.layers[Global.canvas.current_layer_index][0]

	var new_layer := Image.new()
	new_layer.copy_from(Global.canvas.layers[Global.canvas.current_layer_index - 1][0])
	new_layer.blend_rect(selected_layer, Rect2(Global.canvas.position, Global.canvas.size), Vector2.ZERO)

	Global.undos += 1
	Global.undo_redo.create_action("Merge Layer")
	Global.undo_redo.add_do_property(Global.canvas, "layers", new_layers)
	Global.undo_redo.add_do_property(Global.canvas.layers[Global.canvas.current_layer_index - 1][0], "data", new_layer.data)
	Global.undo_redo.add_undo_property(Global.canvas, "layers", Global.canvas.layers)
	Global.undo_redo.add_undo_property(Global.canvas.layers[Global.canvas.current_layer_index - 1][0], "data", Global.canvas.layers[Global.canvas.current_layer_index - 1][0].data)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()

func add_frame() -> void:
	var new_canvas : Canvas = load("res://Prefabs/Canvas.tscn").instance()
	new_canvas.size = Global.canvas.size
	new_canvas.frame = Global.canvases.size()

	var new_canvases := Global.canvases.duplicate()
	new_canvases.append(new_canvas)
	var new_hidden_canvases := Global.hidden_canvases.duplicate()
	new_hidden_canvases.append(new_canvas)

	Global.undos += 1
	Global.undo_redo.create_action("Add Frame")
	Global.undo_redo.add_do_method(Global, "redo", [new_canvas])
	Global.undo_redo.add_undo_method(Global, "undo", [new_canvas])

	Global.undo_redo.add_do_property(Global, "canvases", new_canvases)
	Global.undo_redo.add_do_property(Global, "hidden_canvases", Global.hidden_canvases)
	Global.undo_redo.add_do_property(Global, "canvas", new_canvas)
	Global.undo_redo.add_do_property(Global, "current_frame", new_canvases.size() - 1)
	for child in Global.frame_container.get_children():
		var frame_button = child.get_node("FrameButton")
		Global.undo_redo.add_do_property(frame_button, "pressed", false)
		Global.undo_redo.add_undo_property(frame_button, "pressed", frame_button.pressed)
	for c in Global.canvases:
		Global.undo_redo.add_do_property(c, "visible", false)
		Global.undo_redo.add_undo_property(c, "visible", c.visible)

	Global.undo_redo.add_undo_property(Global, "canvases", Global.canvases)
	Global.undo_redo.add_undo_property(Global, "hidden_canvases", new_hidden_canvases)
	Global.undo_redo.add_undo_property(Global, "canvas", Global.canvas)
	Global.undo_redo.add_undo_property(Global, "current_frame", Global.current_frame)
	Global.undo_redo.commit_action()

func _on_LoopAnim_pressed() -> void:
	match Global.loop_animation_button.texture_normal.resource_path:
		"res://Assets/Graphics/Timeline/Loop_None.png":
			#Make it loop
			animation_loop = 1
			Global.loop_animation_button.texture_normal = preload("res://Assets/Graphics/Timeline/Loop.png")
		"res://Assets/Graphics/Timeline/Loop.png":
			#Make it ping-pong
			animation_loop = 2
			Global.loop_animation_button.texture_normal = preload("res://Assets/Graphics/Timeline/Loop_PingPong.png")
		"res://Assets/Graphics/Timeline/Loop_PingPong.png":
			#Make it stop
			animation_loop = 0
			Global.loop_animation_button.texture_normal = preload("res://Assets/Graphics/Timeline/Loop_None.png")

func _on_PlayForward_toggled(button_pressed) -> void:
	Global.play_backwards.pressed = false

	if button_pressed:
		$AnimationTimer.wait_time = 1 / fps
		$AnimationTimer.start()
		animation_forward = true
	else:
		$AnimationTimer.stop()

func _on_PlayBackwards_toggled(button_pressed) -> void:
	Global.play_forward.pressed = false

	if button_pressed:
		$AnimationTimer.wait_time = 1 / fps
		$AnimationTimer.start()
		animation_forward = false
	else:
		$AnimationTimer.stop()

func _on_NextFrame_pressed() -> void:
	if Global.current_frame < Global.canvases.size() - 1:
		Global.current_frame += 1

func _on_PreviousFrame_pressed() -> void:
	if Global.current_frame > 0:
		Global.current_frame -= 1

func _on_LastFrame_pressed() -> void:
	Global.current_frame = Global.canvases.size() - 1

func _on_FirstFrame_pressed() -> void:
	Global.current_frame = 0

func _on_AnimationTimer_timeout() -> void:
	if animation_forward:
		if Global.current_frame < Global.canvases.size() - 1:
			Global.current_frame += 1
		else:
			match animation_loop:
				0: #No loop
					Global.play_forward.pressed = false
					Global.play_backwards.pressed = false
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
					Global.play_forward.pressed = false
					$AnimationTimer.stop()
				1: #Cycle loop
					Global.current_frame = Global.canvases.size() - 1
				2: #Ping pong loop
					animation_forward = true
					_on_AnimationTimer_timeout()

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

func _exit_tree() -> void:
	# Save the window position and size to remember it when restarting the application
	config_cache.set_value("window", "screen", OS.current_screen)
	config_cache.set_value("window", "maximized", OS.window_maximized || OS.window_fullscreen)
	config_cache.set_value("window", "position", OS.window_position)
	config_cache.set_value("window", "size", OS.window_size)
	config_cache.save("user://cache.ini")
