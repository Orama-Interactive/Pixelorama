extends Node


enum Grid_Types {CARTESIAN, ISOMETRIC, ALL}
enum Pressure_Sensitivity {NONE, ALPHA, SIZE, ALPHA_AND_SIZE}
enum Brush_Types {PIXEL, CIRCLE, FILLED_CIRCLE, FILE, RANDOM_FILE, CUSTOM}
enum Direction {UP, DOWN, LEFT, RIGHT}
enum Mouse_Button {LEFT, RIGHT}
enum Tools {PENCIL, ERASER, BUCKET, LIGHTENDARKEN, RECTSELECT, COLORPICKER, ZOOM}
enum Theme_Types {DARK, BLUE, CARAMEL, LIGHT}
enum Fill_Area {SAME_COLOR_AREA, SAME_COLOR_PIXELS}
enum Fill_With {COLOR, PATTERN}
enum Lighten_Darken_Mode {LIGHTEN, DARKEN}
enum Zoom_Mode {ZOOM_IN, ZOOM_OUT}

# Stuff for arrowkey-based canvas movements nyaa ^.^
const low_speed_move_rate := 150.0
const medium_speed_move_rate := 750.0
const high_speed_move_rate := 3750.0

var root_directory := "."
var window_title := "" setget title_changed # Why doesn't Godot have get_window_title()?
var config_cache := ConfigFile.new()
var XDGDataPaths = preload("res://src/XDGDataPaths.gd")
var directory_module : Reference

# Indices are as in the Direction enum
# This is the total time the key for
# that direction has been pressed.
var key_move_press_time := [0.0, 0.0, 0.0, 0.0]

var loaded_locales : Array
var undo_redo : UndoRedo
var undos := 0 # The number of times we added undo properties
var project_has_changed := false # Checks if the user has made changes to the project

# Canvas related stuff
var frames := [] setget frames_changed
var layers := [] setget layers_changed
var layers_changed_skip := false
var current_frame := 0 setget frame_changed
var current_layer := 0 setget layer_changed

var can_draw := false

var has_focus := false
var pressure_sensitivity_mode = Pressure_Sensitivity.NONE
var open_last_project := false
var smooth_zoom := true
var cursor_image = preload("res://assets/graphics/cursor_icons/cursor.png")
var left_cursor_tool_texture : ImageTexture
var right_cursor_tool_texture : ImageTexture

var selected_pixels := []
var image_clipboard : Image
var animation_tags := [] setget animation_tags_changed
var play_only_tags := true

var theme_type : int = Theme_Types.DARK
var default_image_width := 64
var default_image_height := 64
var default_fill_color := Color(0, 0, 0, 0)
var grid_type = Grid_Types.CARTESIAN
var grid_width := 1
var grid_height := 1
var grid_color := Color.black
var guide_color := Color.purple
var checker_size := 10
var checker_color_1 := Color(0.47, 0.47, 0.47, 1)
var checker_color_2 := Color(0.34, 0.35, 0.34, 1)

var autosave_interval := 5.0
var enable_autosave := true

# Tools & options
var current_tools := [Tools.PENCIL, Tools.ERASER]
var show_left_tool_icon := true
var show_right_tool_icon := true
var left_square_indicator_visible := true
var right_square_indicator_visible := false

var fill_areas := [Fill_Area.SAME_COLOR_AREA, Fill_Area.SAME_COLOR_AREA]
var fill_with := [Fill_With.COLOR, Fill_With.COLOR]
var fill_pattern_offsets := [Vector2.ZERO, Vector2.ZERO]

var ld_modes := [Lighten_Darken_Mode.LIGHTEN, Lighten_Darken_Mode.LIGHTEN]
var ld_amounts := [0.1, 0.1]

var color_picker_for := [Mouse_Button.LEFT, Mouse_Button.RIGHT]

var zoom_modes := [Zoom_Mode.ZOOM_IN, Zoom_Mode.ZOOM_OUT]

var horizontal_mirror := [false, false]
var vertical_mirror := [false, false]
var pixel_perfect := [false, false]

# View menu options
var tile_mode := false
var draw_grid := false
var show_rulers := true
var show_guides := true
var show_animation_timeline := true

# Onion skinning options
var onion_skinning := false
var onion_skinning_past_rate := 1.0
var onion_skinning_future_rate := 1.0
var onion_skinning_blue_red := false

# Brushes
var brush_sizes := [1, 1]
var current_brush_types := [Brush_Types.PIXEL, Brush_Types.PIXEL]

var brush_type_window_position : int = Mouse_Button.LEFT
var left_circle_points := []
var right_circle_points := []

var brushes_from_files := 0
var custom_brushes := []
var custom_brush_indexes := [-1, -1]
var custom_brush_images := [Image.new(), Image.new()]
var custom_brush_textures := [ImageTexture.new(), ImageTexture.new()]

# Patterns
var patterns := []
var pattern_window_position : int = Mouse_Button.LEFT
var pattern_images := [Image.new(), Image.new()]

# Palettes
var palettes := {}

# Nodes
var control : Node
var top_menu_container : Panel
var left_cursor : Sprite
var right_cursor : Sprite
var canvas : Canvas
var main_viewport : ViewportContainer
var second_viewport : ViewportContainer
var camera : Camera2D
var camera2 : Camera2D
var camera_preview : Camera2D
var selection_rectangle : Polygon2D
var horizontal_ruler : BaseButton
var vertical_ruler : BaseButton
var transparent_checker : ColorRect

var file_menu : MenuButton
var edit_menu : MenuButton
var view_menu : MenuButton
var image_menu : MenuButton
var help_menu : MenuButton
var cursor_position_label : Label
var zoom_level_label : Label

var import_sprites_dialog : FileDialog
var export_dialog : AcceptDialog
var preferences_dialog : AcceptDialog

var color_pickers := []

var color_switch_button : BaseButton

var tool_options_containers := []

var brush_type_containers := []
var brush_type_buttons := []
var brushes_popup : Popup
var file_brush_container : GridContainer
var project_brush_container : GridContainer
var patterns_popup : Popup

var brush_size_edits := []
var brush_size_sliders := []

var pixel_perfect_containers := []

var color_interpolation_containers := []
var interpolate_spinboxes := []
var interpolate_sliders := []

var fill_area_containers := []
var fill_pattern_containers := []

var ld_containers := []
var ld_amount_sliders := []
var ld_amount_spinboxes := []

var colorpicker_containers := []

var zoom_containers := []

var mirror_containers := []

var animation_timeline : Panel

var animation_timer : Timer
var frame_ids : HBoxContainer
var current_frame_mark_label : Label
var onion_skinning_button : BaseButton
var loop_animation_button : BaseButton
var play_forward : BaseButton
var play_backwards : BaseButton
var layers_container : VBoxContainer
var frames_container : VBoxContainer
var tag_container : Control
var tag_dialog : AcceptDialog

var remove_frame_button : BaseButton

var remove_layer_button : BaseButton
var move_up_layer_button : BaseButton
var move_down_layer_button : BaseButton
var merge_down_layer_button : BaseButton
var layer_opacity_slider : HSlider
var layer_opacity_spinbox : SpinBox

var add_palette_button : BaseButton
var edit_palette_button : BaseButton
var palette_option_button : OptionButton
var palette_container : GridContainer
var edit_palette_popup : WindowDialog
var new_palette_dialog : ConfirmationDialog
var new_palette_name_line_edit : LineEdit
var palette_import_file_dialog : FileDialog
var error_dialog : AcceptDialog

onready var current_version : String = ProjectSettings.get_setting("application/config/Version")


func _ready() -> void:
	randomize()
	if OS.has_feature("standalone"):
		root_directory = OS.get_executable_path().get_base_dir()
	# Load settings from the config file
	config_cache.load("user://cache.ini")

	# The fact that root_dir is set earlier than this is important
	# XDGDataDirs depends on it nyaa
	directory_module = XDGDataPaths.new()

	undo_redo = UndoRedo.new()
	image_clipboard = Image.new()

	var root = get_tree().get_root()
	control = find_node_by_name(root, "Control")
	top_menu_container = find_node_by_name(control, "TopMenuContainer")
	left_cursor = find_node_by_name(root, "LeftCursor")
	right_cursor = find_node_by_name(root, "RightCursor")
	canvas = find_node_by_name(root, "Canvas")
	left_cursor_tool_texture = ImageTexture.new()
	left_cursor_tool_texture.create_from_image(preload("res://assets/graphics/cursor_icons/pencil_cursor.png"))
	right_cursor_tool_texture = ImageTexture.new()
	right_cursor_tool_texture.create_from_image(preload("res://assets/graphics/cursor_icons/eraser_cursor.png"))
	main_viewport = find_node_by_name(root, "ViewportContainer")
	second_viewport = find_node_by_name(root, "ViewportContainer2")
	camera = find_node_by_name(main_viewport, "Camera2D")
	camera2 = find_node_by_name(root, "Camera2D2")
	camera_preview = find_node_by_name(root, "CameraPreview")
	selection_rectangle = find_node_by_name(root, "SelectionRectangle")
	horizontal_ruler = find_node_by_name(root, "HorizontalRuler")
	vertical_ruler = find_node_by_name(root, "VerticalRuler")
	transparent_checker = find_node_by_name(root, "TransparentChecker")

	file_menu = find_node_by_name(root, "FileMenu")
	edit_menu = find_node_by_name(root, "EditMenu")
	view_menu = find_node_by_name(root, "ViewMenu")
	image_menu = find_node_by_name(root, "ImageMenu")
	help_menu = find_node_by_name(root, "HelpMenu")
	cursor_position_label = find_node_by_name(root, "CursorPosition")
	zoom_level_label = find_node_by_name(root, "ZoomLevel")

	import_sprites_dialog = find_node_by_name(root, "ImportSprites")
	export_dialog = find_node_by_name(root, "ExportDialog")
	preferences_dialog = find_node_by_name(root, "PreferencesDialog")

	tool_options_containers.append(find_node_by_name(root, "LeftToolOptions"))
	tool_options_containers.append(find_node_by_name(root, "RightToolOptions"))

	color_pickers.append(find_node_by_name(root, "LeftColorPickerButton"))
	color_pickers.append(find_node_by_name(root, "RightColorPickerButton"))
	color_switch_button = find_node_by_name(root, "ColorSwitch")

	brush_type_containers.append(find_node_by_name(tool_options_containers[0], "LeftBrushType"))
	brush_type_containers.append(find_node_by_name(tool_options_containers[1], "RightBrushType"))
	brush_type_buttons.append(find_node_by_name(brush_type_containers[0], "LeftBrushTypeButton"))
	brush_type_buttons.append(find_node_by_name(brush_type_containers[1], "RightBrushTypeButton"))
	brushes_popup = find_node_by_name(root, "BrushesPopup")
	file_brush_container = find_node_by_name(brushes_popup, "FileBrushContainer")
	project_brush_container = find_node_by_name(brushes_popup, "ProjectBrushContainer")
	patterns_popup = find_node_by_name(root, "PatternsPopup")

	brush_size_edits.append(find_node_by_name(root, "LeftBrushSizeEdit"))
	brush_size_sliders.append(find_node_by_name(root, "LeftBrushSizeSlider"))
	brush_size_edits.append(find_node_by_name(root, "RightBrushSizeEdit"))
	brush_size_sliders.append(find_node_by_name(root, "RightBrushSizeSlider"))

	pixel_perfect_containers.append(find_node_by_name(root, "LeftBrushPixelPerfectMode"))
	pixel_perfect_containers.append(find_node_by_name(root, "RightBrushPixelPerfectMode"))

	color_interpolation_containers.append(find_node_by_name(root, "LeftColorInterpolation"))
	color_interpolation_containers.append(find_node_by_name(root, "RightColorInterpolation"))
	interpolate_spinboxes.append(find_node_by_name(root, "LeftInterpolateFactor"))
	interpolate_sliders.append(find_node_by_name(root, "LeftInterpolateSlider"))
	interpolate_spinboxes.append(find_node_by_name(root, "RightInterpolateFactor"))
	interpolate_sliders.append(find_node_by_name(root, "RightInterpolateSlider"))

	fill_area_containers.append(find_node_by_name(root, "LeftFillArea"))
	fill_pattern_containers.append(find_node_by_name(root, "LeftFillPattern"))
	fill_area_containers.append(find_node_by_name(root, "RightFillArea"))
	fill_pattern_containers.append(find_node_by_name(root, "RightFillPattern"))

	ld_containers.append(find_node_by_name(root, "LeftLDOptions"))
	ld_amount_sliders.append(find_node_by_name(root, "LeftLDAmountSlider"))
	ld_amount_spinboxes.append(find_node_by_name(root, "LeftLDAmountSpinbox"))
	ld_containers.append(find_node_by_name(root, "RightLDOptions"))
	ld_amount_sliders.append(find_node_by_name(root, "RightLDAmountSlider"))
	ld_amount_spinboxes.append(find_node_by_name(root, "RightLDAmountSpinbox"))

	colorpicker_containers.append(find_node_by_name(root, "LeftColorPickerOptions"))
	colorpicker_containers.append(find_node_by_name(root, "RightColorPickerOptions"))

	zoom_containers.append(find_node_by_name(root, "LeftZoomOptions"))
	zoom_containers.append(find_node_by_name(root, "RightZoomOptions"))

	mirror_containers.append(find_node_by_name(root, "LeftMirrorButtons"))
	mirror_containers.append(find_node_by_name(root, "RightMirrorButtons"))

	animation_timeline = find_node_by_name(root, "AnimationTimeline")

	layers_container = find_node_by_name(animation_timeline, "LayersContainer")
	frames_container = find_node_by_name(animation_timeline, "FramesContainer")
	animation_timer = find_node_by_name(animation_timeline, "AnimationTimer")
	frame_ids = find_node_by_name(animation_timeline, "FrameIDs")
	current_frame_mark_label = find_node_by_name(control, "CurrentFrameMark")
	onion_skinning_button = find_node_by_name(animation_timeline, "OnionSkinning")
	loop_animation_button = find_node_by_name(animation_timeline, "LoopAnim")
	play_forward = find_node_by_name(animation_timeline, "PlayForward")
	play_backwards = find_node_by_name(animation_timeline, "PlayBackwards")
	tag_container = find_node_by_name(animation_timeline, "TagContainer")
	tag_dialog = find_node_by_name(animation_timeline, "FrameTagDialog")

	remove_frame_button = find_node_by_name(animation_timeline, "DeleteFrame")

	remove_layer_button = find_node_by_name(animation_timeline, "RemoveLayer")
	move_up_layer_button = find_node_by_name(animation_timeline, "MoveUpLayer")
	move_down_layer_button = find_node_by_name(animation_timeline, "MoveDownLayer")
	merge_down_layer_button = find_node_by_name(animation_timeline, "MergeDownLayer")

	layer_opacity_slider = find_node_by_name(animation_timeline, "OpacitySlider")
	layer_opacity_spinbox = find_node_by_name(animation_timeline, "OpacitySpinBox")

	add_palette_button = find_node_by_name(root, "AddPalette")
	edit_palette_button = find_node_by_name(root, "EditPalette")
	palette_option_button = find_node_by_name(root, "PaletteOptionButton")
	palette_container = find_node_by_name(root, "PaletteContainer")
	edit_palette_popup = find_node_by_name(root, "EditPalettePopup")
	new_palette_dialog = find_node_by_name(root, "NewPaletteDialog")
	new_palette_name_line_edit = find_node_by_name(new_palette_dialog, "NewPaletteNameLineEdit")
	palette_import_file_dialog = find_node_by_name(root, "PaletteImportFileDialog")

	error_dialog = find_node_by_name(root, "ErrorDialog")

	layers.append(Layer.new())


# Thanks to https://godotengine.org/qa/17524/how-to-find-an-instanced-scene-by-its-name
func find_node_by_name(root : Node, node_name : String) -> Node:
	if root.get_name() == node_name:
		return root
	for child in root.get_children():
		if child.get_name() == node_name:
			return child
		var found = find_node_by_name(child, node_name)
		if found:
			return found
	return null


func notification_label(text : String) -> void:
	var notification : Label = load("res://src/UI/NotificationLabel.tscn").instance()
	notification.text = tr(text)
	notification.rect_position = Vector2(240, OS.window_size.y - animation_timeline.rect_size.y - 20)
	notification.theme = control.theme
	get_tree().get_root().add_child(notification)


func general_undo() -> void:
	undos -= 1
	var action_name := undo_redo.get_current_action_name()
	notification_label("Undo: %s" % action_name)


func general_redo() -> void:
	if undos < undo_redo.get_version(): # If we did undo and then redo
		undos = undo_redo.get_version()
	if control.redone:
		var action_name := undo_redo.get_current_action_name()
		notification_label("Redo: %s" % action_name)


func undo(_frame_index := -1, _layer_index := -1) -> void:
	general_undo()
	var action_name := undo_redo.get_current_action_name()
	if action_name == "Draw" or action_name == "Rectangle Select" or action_name == "Scale" or action_name == "Merge Layer" or action_name == "Link Cel" or action_name == "Unlink Cel":
		if _layer_index > -1 and _frame_index > -1:
			canvas.update_texture(_layer_index, _frame_index)
		else:
			for i in frames.size():
				for j in layers.size():
					canvas.update_texture(j, i)

		if action_name == "Scale":
			canvas.camera_zoom()

	elif "Frame" in action_name:
		# This actually means that frames.size is one, but it hasn't been updated yet
		if frames.size() == 2: # Stop animating
			play_forward.pressed = false
			play_backwards.pressed = false
			animation_timer.stop()

	canvas.update()
	if !project_has_changed:
		project_has_changed = true
		self.window_title = window_title + "(*)"


func redo(_frame_index := -1, _layer_index := -1) -> void:
	general_redo()
	var action_name := undo_redo.get_current_action_name()
	if action_name == "Draw" or action_name == "Rectangle Select" or action_name == "Scale" or action_name == "Merge Layer" or action_name == "Link Cel" or action_name == "Unlink Cel":
		if _layer_index > -1 and _frame_index > -1:
			canvas.update_texture(_layer_index, _frame_index)
		else:
			for i in frames.size():
				for j in layers.size():
					canvas.update_texture(j, i)

		if action_name == "Scale":
			canvas.camera_zoom()

	elif "Frame" in action_name:
		if frames.size() == 1: # Stop animating
			play_forward.pressed = false
			play_backwards.pressed = false
			animation_timer.stop()

	canvas.update()
	if !project_has_changed:
		project_has_changed = true
		self.window_title = window_title + "(*)"


func title_changed(value : String) -> void:
	window_title = value
	OS.set_window_title(value)


func frames_changed(value : Array) -> void:
	frames = value
	for container in frames_container.get_children():
		for button in container.get_children():
			container.remove_child(button)
			button.queue_free()
		frames_container.remove_child(container)

	for frame_id in frame_ids.get_children():
		frame_ids.remove_child(frame_id)
		frame_id.queue_free()

	for i in range(layers.size() - 1, -1, -1):
		frames_container.add_child(layers[i].frame_container)

	for j in range(frames.size()):
		var label := Label.new()
		label.rect_min_size.x = 36
		label.align = Label.ALIGN_CENTER
		label.text = str(j + 1)
		frame_ids.add_child(label)

		for i in range(layers.size() - 1, -1, -1):
			var cel_button = load("res://src/UI/Timeline/CelButton.tscn").instance()
			cel_button.frame = j
			cel_button.layer = i
			cel_button.get_child(0).texture = frames[j].cels[i].image_texture

			layers[i].frame_container.add_child(cel_button)

	# This is useful in case tagged frames get deleted DURING the animation is playing
	# otherwise, this code is useless in this context, since these values are being set
	# when the play buttons get pressed, anyway
	animation_timeline.first_frame = 0
	animation_timeline.last_frame = frames.size() - 1
	if play_only_tags:
		for tag in animation_tags:
			if current_frame + 1 >= tag.from && current_frame + 1 <= tag.to:
				animation_timeline.first_frame = tag.from - 1
				animation_timeline.last_frame = min(frames.size() - 1, tag.to - 1)


func clear_frames() -> void:
	frames.clear()
	animation_tags.clear()
	self.animation_tags = animation_tags # To execute animation_tags_changed()

	# Stop playing the animation
	play_backwards.pressed = false
	play_forward.pressed = false
	animation_timer.stop()

	self.window_title = "(" + tr("untitled") + ") - Pixelorama " + Global.current_version
	OpenSave.current_save_path = ""
	control.get_node("ExportDialog").was_exported = false
	control.file_menu.set_item_text(3, tr("Save..."))
	control.file_menu.set_item_text(6, tr("Export..."))
	undo_redo.clear_history(false)


func layers_changed(value : Array) -> void:
	layers = value
	if layers_changed_skip:
		layers_changed_skip = false
		return

	for container in layers_container.get_children():
		container.queue_free()

	for container in frames_container.get_children():
		for button in container.get_children():
			container.remove_child(button)
			button.queue_free()
		frames_container.remove_child(container)

	for i in range(layers.size() - 1, -1, -1):
		var layer_container = load("res://src/UI/Timeline/LayerButton.tscn").instance()
		layer_container.i = i
		if layers[i].name == tr("Layer") + " 0":
			layers[i].name = tr("Layer") + " %s" % i

		layers_container.add_child(layer_container)
		layer_container.label.text = layers[i].name
		layer_container.line_edit.text = layers[i].name

		frames_container.add_child(layers[i].frame_container)
		for j in range(frames.size()):
			var cel_button = load("res://src/UI/Timeline/CelButton.tscn").instance()
			cel_button.frame = j
			cel_button.layer = i
			cel_button.get_child(0).texture = frames[j].cels[i].image_texture

			layers[i].frame_container.add_child(cel_button)

	var layer_button = layers_container.get_child(layers_container.get_child_count() - 1 - current_layer)
	layer_button.pressed = true
	self.current_frame = current_frame # Call frame_changed to update UI

	if layers[current_layer].locked:
		disable_button(remove_layer_button, true)

	if layers.size() == 1:
		disable_button(remove_layer_button, true)
		disable_button(move_up_layer_button, true)
		disable_button(move_down_layer_button, true)
		disable_button(merge_down_layer_button, true)
	elif !layers[current_layer].locked:
		disable_button(remove_layer_button, false)


func frame_changed(value : int) -> void:
	current_frame = value
	current_frame_mark_label.text = "%s/%s" % [str(current_frame + 1), frames.size()]

	for i in frames.size(): # De-select all the other frames
		var text_color := Color.white
		if theme_type == Theme_Types.CARAMEL || theme_type == Theme_Types.LIGHT:
			text_color = Color.black
		frame_ids.get_child(i).add_color_override("font_color", text_color)
		for layer in layers:
			if i < layer.frame_container.get_child_count():
				layer.frame_container.get_child(i).pressed = false

	# Select the new frame
	frame_ids.get_child(current_frame).add_color_override("font_color", control.theme.get_color("Selected Color", "Label"))
	if current_frame < layers[current_layer].frame_container.get_child_count():
		layers[current_layer].frame_container.get_child(current_frame).pressed = true

	if frames.size() == 1:
		disable_button(remove_frame_button, true)
	elif !layers[current_layer].locked:
		disable_button(remove_frame_button, false)

	Global.canvas.update()
	Global.transparent_checker._ready() # To update the rect size


func layer_changed(value : int) -> void:
	current_layer = value
	if current_frame < frames.size():
		layer_opacity_slider.value = frames[current_frame].cels[current_layer].opacity * 100
		layer_opacity_spinbox.value = frames[current_frame].cels[current_layer].opacity * 100

	for container in layers_container.get_children():
		container.pressed = false

	if current_layer < layers_container.get_child_count():
		var layer_button = layers_container.get_child(layers_container.get_child_count() - 1 - current_layer)
		layer_button.pressed = true

	if current_layer < layers.size() - 1:
		disable_button(move_up_layer_button, false)
	else:
		disable_button(move_up_layer_button, true)

	if current_layer > 0:
		disable_button(move_down_layer_button, false)
		disable_button(merge_down_layer_button, false)
	else:
		disable_button(move_down_layer_button, true)
		disable_button(merge_down_layer_button, true)

	if current_layer < layers.size():
		if layers[current_layer].locked:
			disable_button(remove_layer_button, true)
		else:
			if layers.size() > 1:
				disable_button(remove_layer_button, false)

	yield(get_tree().create_timer(0.01), "timeout")
	self.current_frame = current_frame # Call frame_changed to update UI


func dialog_open(open : bool) -> void:
	if open:
		can_draw = false
		control.get_node("ModulateTween").interpolate_property(control, "modulate", control.modulate, Color(0.5, 0.5, 0.5), 0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	else:
		can_draw = true
		control.get_node("ModulateTween").interpolate_property(control, "modulate", control.modulate, Color.white, 0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT)

	control.get_node("ModulateTween").start()


func disable_button(button : BaseButton, disable : bool) -> void:
	button.disabled = disable
	if disable:
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	else:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if button is Button:
		var theme := theme_type
		if theme == Theme_Types.CARAMEL:
			theme = Theme_Types.DARK
		for c in button.get_children():
			if c is TextureRect:
				var normal_file_name = c.texture.resource_path.get_file().trim_suffix(".png").replace("_disabled", "")
				if disable:
					change_button_texturerect(c, "%s_disabled.png" % normal_file_name)
				else:
					change_button_texturerect(c, "%s.png" % normal_file_name)
				break


func change_button_texturerect(texture_button : TextureRect, new_file_name : String) -> void:
	var file_name := texture_button.texture.resource_path.get_basename().get_file()
	var directory_path := texture_button.texture.resource_path.get_basename().replace(file_name, "")
	texture_button.texture = load(directory_path.plus_file(new_file_name))


func animation_tags_changed(value : Array) -> void:
	animation_tags = value
	for child in tag_container.get_children():
		child.queue_free()

	for tag in animation_tags:
		var tag_c : Container = load("res://src/UI/Timeline/AnimationTag.tscn").instance()
		tag_container.add_child(tag_c)
		var tag_position := tag_container.get_child_count() - 1
		tag_container.move_child(tag_c, tag_position)
		tag_c.get_node("Label").text = tag.name
		tag_c.get_node("Label").modulate = tag.color
		tag_c.get_node("Line2D").default_color = tag.color

		tag_c.rect_position.x = (tag.from - 1) * 39 + tag.from

		var size : int = tag.to - tag.from
		tag_c.rect_min_size.x = (size + 1) * 39
		tag_c.get_node("Line2D").points[2] = Vector2(tag_c.rect_min_size.x, 0)
		tag_c.get_node("Line2D").points[3] = Vector2(tag_c.rect_min_size.x, 32)

	# This is useful in case tags get modified DURING the animation is playing
	# otherwise, this code is useless in this context, since these values are being set
	# when the play buttons get pressed, anyway
	animation_timeline.first_frame = 0
	animation_timeline.last_frame = frames.size() - 1
	if play_only_tags:
		for tag in animation_tags:
			if current_frame + 1 >= tag.from && current_frame + 1 <= tag.to:
				animation_timeline.first_frame = tag.from - 1
				animation_timeline.last_frame = min(frames.size() - 1, tag.to - 1)


func update_hint_tooltips() -> void:
	var root = get_tree().get_root()

	var rect_select : BaseButton = find_node_by_name(root, "RectSelect")
	rect_select.hint_tooltip = tr("""Rectangular Selection

%s for left mouse button
%s for right mouse button

Press %s to move the content""") % [InputMap.get_action_list("left_rectangle_select_tool")[0].as_text(), InputMap.get_action_list("right_rectangle_select_tool")[0].as_text(), "Shift"]

	var zoom_tool : BaseButton = find_node_by_name(root, "Zoom")
	zoom_tool.hint_tooltip = tr("""Zoom

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_zoom_tool")[0].as_text(), InputMap.get_action_list("right_zoom_tool")[0].as_text()]


	var color_picker : BaseButton = find_node_by_name(root, "ColorPicker")
	color_picker.hint_tooltip = tr("""Color Picker
Select a color from a pixel of the sprite

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_colorpicker_tool")[0].as_text(), InputMap.get_action_list("right_colorpicker_tool")[0].as_text()]

	var pencil : BaseButton = find_node_by_name(root, "Pencil")
	pencil.hint_tooltip = tr("""Pencil

%s for left mouse button
%s for right mouse button

Hold %s to make a line""") % [InputMap.get_action_list("left_pencil_tool")[0].as_text(), InputMap.get_action_list("right_pencil_tool")[0].as_text(), "Shift"]

	var eraser : BaseButton = find_node_by_name(root, "Eraser")
	eraser.hint_tooltip = tr("""Eraser

%s for left mouse button
%s for right mouse button

Hold %s to make a line""") % [InputMap.get_action_list("left_eraser_tool")[0].as_text(), InputMap.get_action_list("right_eraser_tool")[0].as_text(), "Shift"]

	var bucket : BaseButton = find_node_by_name(root, "Bucket")
	bucket.hint_tooltip = tr("""Bucket

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_fill_tool")[0].as_text(), InputMap.get_action_list("right_fill_tool")[0].as_text()]

	var ld : BaseButton = find_node_by_name(root, "LightenDarken")
	ld.hint_tooltip = tr("""Lighten/Darken

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_lightdark_tool")[0].as_text(), InputMap.get_action_list("right_lightdark_tool")[0].as_text()]

	var color_switch : BaseButton = find_node_by_name(root, "ColorSwitch")
	color_switch.hint_tooltip = tr("""Switch left and right colors
(%s)""") % InputMap.get_action_list("switch_colors")[0].as_text()

	var first_frame : BaseButton = find_node_by_name(root, "FirstFrame")
	first_frame.hint_tooltip = tr("""Jump to the first frame
(%s)""") % "Ctrl+Home"

	var previous_frame : BaseButton = find_node_by_name(root, "PreviousFrame")
	previous_frame.hint_tooltip = tr("""Go to the previous frame
(%s)""") % "Ctrl+Left"

	play_backwards.hint_tooltip = tr("""Play the animation backwards (from end to beginning)
(%s)""") % "F4"

	play_forward.hint_tooltip = tr("""Play the animation forward (from beginning to end)
(%s)""") % "F5"

	var next_frame : BaseButton = find_node_by_name(root, "NextFrame")
	next_frame.hint_tooltip = tr("""Go to the next frame
(%s)""") % "Ctrl+Right"

	var last_frame : BaseButton = find_node_by_name(root, "LastFrame")
	last_frame.hint_tooltip = tr("""Jump to the last frame
(%s)""") % "Ctrl+End"


func create_brush_button(brush_img : Image, brush_type := Brush_Types.CUSTOM, hint_tooltip := "") -> void:
	var brush_container
	var brush_button = load("res://src/UI/BrushButton.tscn").instance()
	brush_button.brush_type = brush_type
	brush_button.custom_brush_index = custom_brushes.size() - 1
	if brush_type == Brush_Types.FILE || brush_type == Brush_Types.RANDOM_FILE:
		brush_container = file_brush_container
	else:
		brush_container = project_brush_container
	var brush_tex := ImageTexture.new()
	brush_tex.create_from_image(brush_img, 0)
	brush_button.get_child(0).texture = brush_tex
	brush_button.hint_tooltip = hint_tooltip
	brush_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if brush_type == Brush_Types.RANDOM_FILE:
		brush_button.random_brushes.append(brush_img)
	brush_container.add_child(brush_button)


func remove_brush_buttons() -> void:
	current_brush_types[0] = Brush_Types.PIXEL
	current_brush_types[1] = Brush_Types.PIXEL
	for child in project_brush_container.get_children():
		child.queue_free()


func undo_custom_brush(_brush_button : BaseButton = null) -> void:
	general_undo()
	var action_name := undo_redo.get_current_action_name()
	if action_name == "Delete Custom Brush":
		project_brush_container.add_child(_brush_button)
		project_brush_container.move_child(_brush_button, _brush_button.custom_brush_index - brushes_from_files)
		_brush_button.get_node("DeleteButton").visible = false


func redo_custom_brush(_brush_button : BaseButton = null) -> void:
	general_redo()
	var action_name := undo_redo.get_current_action_name()
	if action_name == "Delete Custom Brush":
		project_brush_container.remove_child(_brush_button)


func update_custom_brush(mouse_button : int) -> void:
	if current_brush_types[mouse_button] == Brush_Types.PIXEL:
		var pixel := Image.new()
		pixel = preload("res://assets/graphics/pixel_image.png")
		brush_type_buttons[mouse_button].get_child(0).texture.create_from_image(pixel, 0)
	elif current_brush_types[mouse_button] == Brush_Types.CIRCLE:
		var pixel := Image.new()
		pixel = preload("res://assets/graphics/circle_9x9.png")
		brush_type_buttons[mouse_button].get_child(0).texture.create_from_image(pixel, 0)
		left_circle_points = plot_circle(brush_sizes[0])
		right_circle_points = plot_circle(brush_sizes[1])
	elif current_brush_types[mouse_button] == Brush_Types.FILLED_CIRCLE:
		var pixel := Image.new()
		pixel = preload("res://assets/graphics/circle_filled_9x9.png")
		brush_type_buttons[mouse_button].get_child(0).texture.create_from_image(pixel, 0)
		left_circle_points = plot_circle(brush_sizes[0])
		right_circle_points = plot_circle(brush_sizes[1])
	else:
		var custom_brush := Image.new()
		custom_brush.copy_from(custom_brushes[custom_brush_indexes[mouse_button]])
		var custom_brush_size = custom_brush.get_size()
		custom_brush.resize(custom_brush_size.x * brush_sizes[mouse_button], custom_brush_size.y * brush_sizes[mouse_button], Image.INTERPOLATE_NEAREST)
		custom_brush_images[mouse_button] = blend_image_with_color(custom_brush, color_pickers[mouse_button].color, interpolate_spinboxes[mouse_button].value / 100)
		custom_brush_textures[mouse_button].create_from_image(custom_brush_images[mouse_button], 0)

		brush_type_buttons[mouse_button].get_child(0).texture = custom_brush_textures[mouse_button]


func blend_image_with_color(image : Image, color : Color, interpolate_factor : float) -> Image:
	var blended_image := Image.new()
	blended_image.copy_from(image)
	var size := image.get_size()
	blended_image.lock()
	for xx in size.x:
		for yy in size.y:
			if color.a > 0: # If it's the pencil
				var current_color := blended_image.get_pixel(xx, yy)
				if current_color.a > 0:
					var new_color := current_color.linear_interpolate(color, interpolate_factor)
					new_color.a = current_color.a
					blended_image.set_pixel(xx, yy, new_color)
			else: # If color is transparent - if it's the eraser
				blended_image.set_pixel(xx, yy, Color(0, 0, 0, 0))
	return blended_image


# Algorithm based on http://members.chello.at/easyfilter/bresenham.html
# This is not used for drawing, rather for finding the points required
# for the mouse cursor/position indicator
func plot_circle(r : int) -> Array:
	var circle_points := []
	var xm := 0
	var ym := 0
	var x := -r
	var y := 0
	var err := 2 - r * 2
	while x < 0:
		circle_points.append(Vector2(xm - x, ym + y))
		circle_points.append(Vector2(xm - y, ym - x))
		circle_points.append(Vector2(xm + x, ym - y))
		circle_points.append(Vector2(xm + y, ym + x))
		r = err
		if r <= y:
			y += 1
			err += y * 2 + 1
		if r > x || err > y:
			x += 1
			err += x * 2 + 1
	return circle_points


func _exit_tree() -> void:
	config_cache.set_value("window", "screen", OS.current_screen)
	config_cache.set_value("window", "maximized", OS.window_maximized || OS.window_fullscreen)
	config_cache.set_value("window", "position", OS.window_position)
	config_cache.set_value("window", "size", OS.window_size)
	config_cache.save("user://cache.ini")

	# Thanks to qarmin from GitHub for pointing this out
	undo_redo.free()
