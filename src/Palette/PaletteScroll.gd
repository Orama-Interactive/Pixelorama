extends VBoxContainer

var scroll := Vector2.ZERO
var drag_started := false
var drag_start_position := Vector2.ZERO

onready var h_slider := $"%HScrollBar"
onready var v_slider := $"%VScrollBar"
onready var palette_grid := $"%PaletteGrid"
onready var scroll_container := $"%ScrollContainer"


func _ready() -> void:
	# Hide default scollbars
	scroll_container.get_h_scrollbar().rect_scale = Vector2.ZERO
	scroll_container.get_v_scrollbar().rect_scale = Vector2.ZERO


func _input(event) -> void:
	# Stops dragging even if middle mouse is released outside of this container
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_MIDDLE and not event.pressed:
			drag_started = false


func set_sliders(palette: Palette, origin: Vector2) -> void:
	h_slider.value = origin.x
	h_slider.max_value = palette.width
	h_slider.page = palette_grid.grid_size.x
	h_slider.visible = false if h_slider.max_value <= palette_grid.grid_size.x else true

	v_slider.value = origin.y
	v_slider.max_value = palette.height
	v_slider.page = palette_grid.grid_size.y
	v_slider.visible = false if v_slider.max_value <= palette_grid.grid_size.y else true


func reset_sliders() -> void:
	set_sliders(palette_grid.current_palette, palette_grid.grid_window_origin)


func resize_grid() -> void:
	palette_grid.resize_grid(rect_size - Vector2(v_slider.rect_size.x, h_slider.rect_size.y))


func scroll_grid() -> void:
	palette_grid.scroll_palette(scroll)


func _on_VSlider_value_changed(value) -> void:
	scroll.y = value
	scroll_grid()


func _on_HSlider_value_changed(value: int) -> void:
	scroll.x = value
	scroll_grid()


func _on_PaletteGrid_gui_input(event) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_MIDDLE and event.pressed:
			drag_started = true
			# Keeps position where the dragging started
			drag_start_position = (
				event.position
				+ Vector2(h_slider.value, v_slider.value) * palette_grid.swatch_size
			)

	if event is InputEventMouseMotion and drag_started:
		h_slider.value = (drag_start_position.x - event.position.x) / palette_grid.swatch_size.x
		v_slider.value = (drag_start_position.y - event.position.y) / palette_grid.swatch_size.y


func _on_PaletteScroll_resized() -> void:
	resize_grid()
	reset_sliders()


func _on_PaletteScroll_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		var scroll_vector = Vector2.ZERO
		if event.button_index == BUTTON_WHEEL_UP:
			if event.control:
				palette_grid.change_swatch_size(Vector2.ONE)
			else:
				scroll_vector = Vector2.LEFT if event.shift else Vector2.UP
		if event.button_index == BUTTON_WHEEL_DOWN:
			if event.control:
				palette_grid.change_swatch_size(-Vector2.ONE)
			else:
				scroll_vector = Vector2.RIGHT if event.shift else Vector2.DOWN
		resize_grid()
		set_sliders(palette_grid.current_palette, palette_grid.grid_window_origin + scroll_vector)
