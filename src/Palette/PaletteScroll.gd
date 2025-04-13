extends VBoxContainer

var scroll := Vector2i.ZERO
var drag_started := false
var drag_start_position := Vector2i.ZERO

@onready var h_slider := %HScrollBar as HScrollBar
@onready var v_slider := %VScrollBar as VScrollBar
@onready var palette_grid := %PaletteGrid as PaletteGrid


func _input(event: InputEvent) -> void:
	# Stops dragging even if middle mouse is released outside of this container
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			drag_started = false


func set_sliders(palette: Palette, origin: Vector2i) -> void:
	if is_instance_valid(palette):
		h_slider.value = origin.x
		h_slider.max_value = palette.width
		h_slider.page = palette_grid.grid_size.x
		v_slider.value = origin.y
		v_slider.max_value = palette.height
		v_slider.page = palette_grid.grid_size.y
	else:
		h_slider.value = 0
		h_slider.max_value = 0
		h_slider.page = 0
		v_slider.value = 0
		v_slider.max_value = 0
		v_slider.page = 0
	h_slider.visible = false if h_slider.max_value <= palette_grid.grid_size.x else true
	v_slider.visible = false if v_slider.max_value <= palette_grid.grid_size.y else true


func reset_sliders() -> void:
	set_sliders(palette_grid.current_palette, palette_grid.grid_window_origin)


func resize_grid() -> void:
	palette_grid.resize_grid(size - Vector2(v_slider.size.x, h_slider.size.y))


func scroll_grid() -> void:
	palette_grid.scroll_palette(scroll)


func _on_VSlider_value_changed(value: int) -> void:
	scroll.y = value
	scroll_grid()


func _on_HSlider_value_changed(value: int) -> void:
	scroll.x = value
	scroll_grid()


func _on_PaletteGrid_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			drag_started = true
			# Keeps position where the dragging started
			drag_start_position = (
				event.position + Vector2(h_slider.value, v_slider.value) * palette_grid.swatch_size
			)

	if event is InputEventMouseMotion and drag_started:
		h_slider.value = (drag_start_position.x - event.position.x) / palette_grid.swatch_size.x
		v_slider.value = (drag_start_position.y - event.position.y) / palette_grid.swatch_size.y


func _on_PaletteScroll_resized() -> void:
	if not is_instance_valid(palette_grid):
		return
	resize_grid()
	reset_sliders()


func _on_PaletteScroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var scroll_vector := Vector2i.ZERO
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if event.ctrl_pressed:
				palette_grid.change_swatch_size(Vector2i.ONE)
			else:
				scroll_vector = Vector2i.LEFT if event.shift_pressed else Vector2i.UP
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.ctrl_pressed:
				palette_grid.change_swatch_size(-Vector2i.ONE)
			else:
				scroll_vector = Vector2i.RIGHT if event.shift_pressed else Vector2i.DOWN
		else:
			return
		resize_grid()
		set_sliders(palette_grid.current_palette, palette_grid.grid_window_origin + scroll_vector)
		get_window().set_input_as_handled()
