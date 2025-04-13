extends ConfirmationDialog

var aspect_ratio := 1.0
var recent_sizes := []
var templates: Array[Template] = [
	# Basic
	Template.new(Vector2i(16, 16)),
	Template.new(Vector2i(32, 32)),
	Template.new(Vector2i(64, 64)),
	Template.new(Vector2i(128, 128)),
	# Nintendo
	Template.new(Vector2i(160, 144), "GB"),
	Template.new(Vector2i(240, 160), "GBA"),
	Template.new(Vector2i(256, 224), "NES (NTSC)"),
	Template.new(Vector2i(256, 240), "NES (PAL)"),
	Template.new(Vector2i(512, 448), "SNES (NTSC)"),
	Template.new(Vector2i(512, 480), "SNES (PAL)"),
	Template.new(Vector2i(646, 486), "N64 (NTSC)"),
	Template.new(Vector2i(786, 576), "N64 (PAL)"),
	# Sega
	Template.new(Vector2i(256, 192), "SMS (NTSC)"),
	Template.new(Vector2i(256, 224), "SMS (PAL)"),
	Template.new(Vector2i(160, 144), "GG"),
	Template.new(Vector2i(320, 224), "MD (NTSC)"),
	Template.new(Vector2i(320, 240), "MD (PAL)"),
	# NEC
	Template.new(Vector2i(256, 239), "PC Engine"),  #256×224 to 512×242 (mostly 256×239)
	# DOS
	Template.new(Vector2i(320, 200), "DOS EGA"),
	Template.new(Vector2i(320, 200), "DOS VGA"),
	Template.new(Vector2i(620, 480), "DOS SVGA"),
	Template.new(Vector2i(640, 200), "DOS CGA (2-Colour)"),
	Template.new(Vector2i(320, 200), "DOS CGA (4-Colour)"),
	Template.new(Vector2i(160, 240), "DOS CGA (Composite)"),
	Template.new(Vector2i(160, 240), "Tandy"),
	# Commodore
	Template.new(Vector2i(320, 200), "Amiga OCS LowRes (NTSC)"),
	Template.new(Vector2i(320, 256), "Amiga OCS LowRes (PAL)"),
	Template.new(Vector2i(640, 200), "Amiga OCS HiRes  (NTSC)"),
	Template.new(Vector2i(640, 256), "Amiga OCS HiRes  (PAL)"),
	Template.new(Vector2i(1280, 200), "Amiga ECS Super-HiRes  (NTSC)"),
	Template.new(Vector2i(1280, 256), "Amiga ECS SuperHiRes  (PAL)"),
	Template.new(Vector2i(640, 480), "Amiga ECS Multiscan"),
	Template.new(Vector2i(320, 200), "C64"),
	# Sinclair
	Template.new(Vector2i(256, 192), "ZX Spectrum"),
]

@onready var templates_options := %TemplatesOptions as OptionButton
@onready var ratio_box := %AspectRatioButton as TextureButton
@onready var width_value := %WidthValue as SpinBox
@onready var height_value := %HeightValue as SpinBox
@onready var portrait_button := %PortraitButton as Button
@onready var landscape_button := %LandscapeButton as Button
@onready var name_input := $VBoxContainer/FillColorContainer/NameInput as LineEdit
@onready var fill_color_node := %FillColor as ColorPickerButton
@onready var color_mode := $VBoxContainer/FillColorContainer/ColorMode as OptionButton
@onready var recent_templates_list := %RecentTemplates as ItemList


class Template:
	var resolution: Vector2i
	var name: String

	func _init(_resolution: Vector2i, _name := "") -> void:
		resolution = _resolution
		name = _name


func _ready() -> void:
	width_value.value = Global.default_width
	height_value.value = Global.default_height
	aspect_ratio = width_value.value / height_value.value
	fill_color_node.color = Global.default_fill_color
	fill_color_node.get_picker().presets_visible = false

	_create_option_list()


func _on_CreateNewImage_about_to_show():
	recent_sizes = Global.config_cache.get_value("templates", "recent_sizes", [])
	_create_recent_list()


func _create_option_list() -> void:
	var i := 1
	for template in templates:
		if template.name != "":
			templates_options.add_item(
				"{width}x{height} - {name}".format(
					{
						"width": template.resolution.x,
						"height": template.resolution.y,
						"name": template.name
					}
				),
				i
			)
		else:
			templates_options.add_item(
				"{width}x{height}".format(
					{"width": template.resolution.x, "height": template.resolution.y}
				),
				i
			)

		i += 1


func _create_recent_list() -> void:
	recent_templates_list.clear()
	for recent_size in recent_sizes:
		recent_templates_list.add_item(
			"{width}x{height}".format({"width": recent_size.x, "height": recent_size.y})
		)


func _on_CreateNewImage_confirmed() -> void:
	var width: int = width_value.value
	var height: int = height_value.value
	var image_size := Vector2i(width, height)
	if image_size in recent_sizes:
		recent_sizes.erase(image_size)
	recent_sizes.insert(0, image_size)
	if recent_sizes.size() > 10:
		recent_sizes.resize(10)
	Global.config_cache.set_value("templates", "recent_sizes", recent_sizes)
	var fill_color := fill_color_node.color
	var proj_name := name_input.text
	if !proj_name.is_valid_filename():
		proj_name = tr("untitled")

	var new_project := Project.new([], proj_name, image_size)
	if color_mode.selected == 1:
		new_project.color_mode = Project.INDEXED_MODE
	new_project.layers.append(PixelLayer.new(new_project))
	new_project.fill_color = fill_color
	new_project.frames.append(new_project.new_empty_frame())
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()


func _on_AspectRatioButton_toggled(_button_pressed: bool) -> void:
	aspect_ratio = width_value.value / height_value.value


func _on_SizeValue_value_changed(value: float) -> void:
	if ratio_box.button_pressed:
		if width_value.value == value:
			height_value.value = width_value.value / aspect_ratio
		if height_value.value == value:
			width_value.value = height_value.value * aspect_ratio

	toggle_size_buttons()


func toggle_size_buttons() -> void:
	portrait_button.toggled.disconnect(_on_PortraitButton_toggled)
	landscape_button.toggled.disconnect(_on_LandscapeButton_toggled)
	portrait_button.button_pressed = width_value.value < height_value.value
	landscape_button.button_pressed = width_value.value > height_value.value

	portrait_button.toggled.connect(_on_PortraitButton_toggled)
	landscape_button.toggled.connect(_on_LandscapeButton_toggled)


func _on_TemplatesOptions_item_selected(id: int) -> void:
	# If a template is chosen while "ratio button" is pressed then temporarily release it
	var temporary_release := false
	if ratio_box.button_pressed:
		ratio_box.button_pressed = false
		temporary_release = true

	if id > 0:
		width_value.value = templates[id - 1].resolution.x
		height_value.value = templates[id - 1].resolution.y
	else:
		width_value.value = Global.default_width
		height_value.value = Global.default_height

	if temporary_release:
		ratio_box.button_pressed = true


func _on_RecentTemplates_item_selected(id):
	#if a template is chosen while "ratio button" is pressed then temporarily release it
	var temporary_release = false
	if ratio_box.button_pressed:
		ratio_box.button_pressed = false
		temporary_release = true

	width_value.value = recent_sizes[id].x
	height_value.value = recent_sizes[id].y

	if temporary_release:
		ratio_box.button_pressed = true


func _on_PortraitButton_toggled(button_pressed: bool) -> void:
	if !button_pressed or height_value.value > width_value.value:
		toggle_size_buttons()
		return
	switch_width_height()


func _on_LandscapeButton_toggled(button_pressed: bool) -> void:
	if !button_pressed or width_value.value > height_value.value:
		toggle_size_buttons()
		return
	switch_width_height()


func switch_width_height() -> void:
	width_value.value_changed.disconnect(_on_SizeValue_value_changed)
	height_value.value_changed.disconnect(_on_SizeValue_value_changed)

	var height := height_value.value
	height_value.value = width_value.value
	width_value.value = height
	toggle_size_buttons()

	width_value.value_changed.connect(_on_SizeValue_value_changed)
	height_value.value_changed.connect(_on_SizeValue_value_changed)


func _on_visibility_changed() -> void:
	if not visible:
		Global.dialog_open(false)
