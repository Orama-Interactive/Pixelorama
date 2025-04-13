extends Node2D

const FONT_SIZE = 16

var users := 1
var enabled: bool = false:
	set(value):
		enabled = value
		queue_redraw()


func _ready() -> void:
	Global.camera.zoom_changed.connect(queue_redraw)


func _draw() -> void:
	if not enabled:
		return
	# when we zoom out there is a visual issue that inverts the text
	# (kind of how you look through a magnifying glass)
	# so we should restrict the rendering distance of this preview.
	var zoom_percentage := 100.0 * Global.camera.zoom.x
	if zoom_percentage < Global.pixel_grid_show_at_zoom:
		return
	var project = ExtensionsApi.project.current_project
	var size: Vector2i = project.size
	var cel: BaseCel = project.frames[project.current_frame].cels[project.current_layer]
	if not cel is PixelCel:
		return
	var index_image: Image = cel.image.indices_image
	if index_image.get_size() != size or not cel.image.is_indexed:
		return

	var font: Font = ExtensionsApi.theme.get_theme().default_font
	draw_set_transform(position, rotation, Vector2(0.05, 0.05))
	for x in range(size.x):
		for y in range(size.y):
			var index := index_image.get_pixel(x, y).r8
			if index == 0:
				continue
			draw_string(
				font,
				Vector2(x, y) * 20 + Vector2.DOWN * 16,
				str(index),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				FONT_SIZE if (index < 100) else int(FONT_SIZE / 1.5)
			)
	draw_set_transform(position, rotation, scale)
