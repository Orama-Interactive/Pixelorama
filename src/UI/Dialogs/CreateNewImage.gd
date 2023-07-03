extends ConfirmationDialog

var aspect_ratio := 1.0
var recent_sizes := []
var templates := [
	# Basic
	Template.new(Vector2(16, 16)),
	Template.new(Vector2(32, 32)),
	Template.new(Vector2(64, 64)),
	Template.new(Vector2(128, 128)),
	# Nintendo
	Template.new(Vector2(160, 144), "GB"),
	Template.new(Vector2(240, 160), "GBA"),
	Template.new(Vector2(256, 224), "NES (NTSC)"),
	Template.new(Vector2(256, 240), "NES (PAL)"),
	Template.new(Vector2(512, 448), "SNES (NTSC)"),
	Template.new(Vector2(512, 480), "SNES (PAL)"),
	Template.new(Vector2(646, 486), "N64 (NTSC)"),
	Template.new(Vector2(786, 576), "N64 (PAL)"),
	# Sega
	Template.new(Vector2(256, 192), "SMS (NTSC)"),
	Template.new(Vector2(256, 224), "SMS (PAL)"),
	Template.new(Vector2(160, 144), "GG"),
	Template.new(Vector2(320, 224), "MD (NTSC)"),
	Template.new(Vector2(320, 240), "MD (PAL)"),
	# NEC
	Template.new(Vector2(256, 239), "PC Engine"),  #256×224 to 512×242 (mostly 256×239)
	# DOS
	Template.new(Vector2(320, 200), "DOS EGA"),
	Template.new(Vector2(320, 200), "DOS VGA"),
	Template.new(Vector2(620, 480), "DOS SVGA"),
	Template.new(Vector2(640, 200), "DOS CGA (2-Colour)"),
	Template.new(Vector2(320, 200), "DOS CGA (4-Colour)"),
	Template.new(Vector2(160, 240), "DOS CGA (Composite)"),
	Template.new(Vector2(160, 240), "Tandy"),
	# Commodore
	Template.new(Vector2(320, 200), "Amiga OCS LowRes (NTSC)"),
	Template.new(Vector2(320, 256), "Amiga OCS LowRes (PAL)"),
	Template.new(Vector2(640, 200), "Amiga OCS HiRes  (NTSC)"),
	Template.new(Vector2(640, 256), "Amiga OCS HiRes  (PAL)"),
	Template.new(Vector2(1280, 200), "Amiga ECS Super-HiRes  (NTSC)"),
	Template.new(Vector2(1280, 256), "Amiga ECS SuperHiRes  (PAL)"),
	Template.new(Vector2(640, 480), "Amiga ECS Multiscan"),
	Template.new(Vector2(320, 200), "C64"),
	# Sinclair
	Template.new(Vector2(256, 192), "ZX Spectrum"),
]

onready var recent_templates_list = find_node("RecentTemplates")
onready var templates_options = find_node("TemplatesOptions")
onready var ratio_box = find_node("AspectRatioButton")
onready var width_value = find_node("WidthValue")
onready var height_value = find_node("HeightValue")
onready var portrait_button = find_node("PortraitButton")
onready var landscape_button = find_node("LandscapeButton")
onready var fill_color_node = find_node("FillColor")


class Template:
	var resolution: Vector2
	var name: String

	func _init(_resolution: Vector2, _name := "") -> void:
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
	for size in recent_sizes:
		recent_templates_list.add_item(
			"{width}x{height}".format({"width": size.x, "height": size.y})
		)


func _on_CreateNewImage_confirmed() -> void:
	var width: int = width_value.value
	var height: int = height_value.value
	var size = Vector2(width, height)
	if size in recent_sizes:
		recent_sizes.erase(size)
	recent_sizes.insert(0, size)
	if recent_sizes.size() > 10:
		recent_sizes.resize(10)
	Global.config_cache.set_value("templates", "recent_sizes", recent_sizes)
	var fill_color: Color = fill_color_node.color

	var proj_name: String = $VBoxContainer/ProjectName/NameInput.text
	if !proj_name.is_valid_filename():
		proj_name = tr("untitled")

	var new_project := Project.new([], proj_name, Vector2(width, height).floor())
	new_project.layers.append(PixelLayer.new(new_project))
	new_project.fill_color = fill_color
	new_project.frames.append(new_project.new_empty_frame())
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()


func _on_AspectRatioButton_toggled(_button_pressed: bool) -> void:
	aspect_ratio = width_value.value / height_value.value


func _on_SizeValue_value_changed(value: float) -> void:
	if ratio_box.pressed:
		if width_value.value == value:
			height_value.value = width_value.value / aspect_ratio
		if height_value.value == value:
			width_value.value = height_value.value * aspect_ratio

	toggle_size_buttons()


func toggle_size_buttons() -> void:
	portrait_button.disconnect("toggled", self, "_on_PortraitButton_toggled")
	landscape_button.disconnect("toggled", self, "_on_LandscapeButton_toggled")
	portrait_button.pressed = width_value.value < height_value.value
	landscape_button.pressed = width_value.value > height_value.value

	portrait_button.connect("toggled", self, "_on_PortraitButton_toggled")
	landscape_button.connect("toggled", self, "_on_LandscapeButton_toggled")


func _on_TemplatesOptions_item_selected(id: int) -> void:
	#if a template is chosen while "ratio button" is pressed then temporarily release it
	var temporary_release = false
	if ratio_box.pressed:
		ratio_box.pressed = false
		temporary_release = true

	if id > 0:
		width_value.value = templates[id - 1].resolution.x
		height_value.value = templates[id - 1].resolution.y
	else:
		width_value.value = Global.default_width
		height_value.value = Global.default_height

	if temporary_release:
		ratio_box.pressed = true


func _on_RecentTemplates_item_selected(id):
	#if a template is chosen while "ratio button" is pressed then temporarily release it
	var temporary_release = false
	if ratio_box.pressed:
		ratio_box.pressed = false
		temporary_release = true

	width_value.value = recent_sizes[id].x
	height_value.value = recent_sizes[id].y

	if temporary_release:
		ratio_box.pressed = true


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
	width_value.disconnect("value_changed", self, "_on_SizeValue_value_changed")
	height_value.disconnect("value_changed", self, "_on_SizeValue_value_changed")

	var height = height_value.value
	height_value.value = width_value.value
	width_value.value = height
	toggle_size_buttons()

	width_value.connect("value_changed", self, "_on_SizeValue_value_changed")
	height_value.connect("value_changed", self, "_on_SizeValue_value_changed")
