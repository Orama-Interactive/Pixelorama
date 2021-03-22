extends VBoxContainer

var scroll := Vector2.ZERO
var drag_started := false
var drag_start_position := Vector2.ZERO

onready var h_slider := $MarginContainer/HScrollBar
onready var v_slider := $HBoxContainer/CenterContainer/HBoxContainer/VScrollBar
onready var palette_grid := $HBoxContainer/CenterContainer/HBoxContainer/PaletteGrid


func _input(event) -> void:
	# Stops dragging even if middle mouse is released outside of this container
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_MIDDLE and not event.pressed:
			drag_started = false


func set_sliders(palette: Palette, origin: Vector2) -> void:
	h_slider.value = origin.x
	v_slider.value = origin.y
	h_slider.max_value = palette.width
	if h_slider.max_value <= PaletteGrid.MAX_GRID_SIZE.x:
		h_slider.visible = false
	else:
		h_slider.visible = true
	v_slider.max_value = palette.height
	if v_slider.max_value <= PaletteGrid.MAX_GRID_SIZE.y:
		v_slider.visible = false
	else:
		v_slider.visible = true


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
			drag_start_position = event.position + Vector2(h_slider.value, v_slider.value) * PaletteSwatch.SWATCH_SIZE

	if event is InputEventMouseMotion and drag_started:
		h_slider.value = (drag_start_position.x - event.position.x) / PaletteSwatch.SWATCH_SIZE.x
		v_slider.value = (drag_start_position.y - event.position.y) / PaletteSwatch.SWATCH_SIZE.y
