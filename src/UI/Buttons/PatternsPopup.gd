class_name Patterns
extends PopupPanel

signal pattern_selected(pattern)

var default_pattern: Pattern = null


class Pattern:
	var image: Image
	var index: int


func _ready() -> void:
	add(Image.new(), "Clipboard")


func select_pattern(pattern: Pattern) -> void:
	emit_signal("pattern_selected", pattern)
	hide()


func create_button(image: Image) -> Node:
	var button: BaseButton = preload("res://src/UI/Buttons/PatternButton.tscn").instance()
	var tex := ImageTexture.new()
	if !image.is_empty():
		tex.create_from_image(image, 0)
	button.get_child(0).texture = tex
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func add(image: Image, hint := "") -> void:
	var button = create_button(image)
	button.pattern.image = image
	button.hint_tooltip = hint
	var container = get_node("ScrollContainer/PatternContainer")
	container.add_child(button)
	button.pattern.index = button.get_index()

	if Global.patterns_popup.default_pattern == null:
		Global.patterns_popup.default_pattern = button.pattern


func get_pattern(index: int) -> Pattern:
	var container = Global.patterns_popup.get_node("ScrollContainer/PatternContainer")
	var pattern = default_pattern
	if index < container.get_child_count():
		pattern = container.get_child(index).pattern
	return pattern
