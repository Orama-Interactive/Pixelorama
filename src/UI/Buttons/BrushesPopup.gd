class_name Brushes
extends Popup

signal brush_selected(brush)
signal brush_removed(brush)
enum { PIXEL, CIRCLE, FILLED_CIRCLE, FILE, RANDOM_FILE, CUSTOM }

var pixel_image := preload("res://assets/graphics/pixel_image.png")
var circle_image := preload("res://assets/graphics/circle_9x9.png")
var circle_filled_image := preload("res://assets/graphics/circle_filled_9x9.png")


class Brush:
	var type: int
	var image: Image
	var random := []
	var index: int


func _ready() -> void:
	var container = get_node("Background/Brushes/Categories/DefaultBrushContainer")
	var button := create_button(pixel_image)
	button.brush.type = PIXEL
	button.hint_tooltip = "Pixel brush"
	container.add_child(button)
	button.brush.index = button.get_index()

	button = create_button(circle_image)
	button.brush.type = CIRCLE
	button.hint_tooltip = "Circle brush"
	container.add_child(button)
	button.brush.index = button.get_index()

	button = create_button(circle_filled_image)
	button.brush.type = FILLED_CIRCLE
	button.hint_tooltip = "Filled circle brush"
	container.add_child(button)
	button.brush.index = button.get_index()


func select_brush(brush: Brush) -> void:
	emit_signal("brush_selected", brush)
	hide()


static func get_default_brush() -> Brush:
	var brush := Brush.new()
	brush.type = PIXEL
	brush.index = 0
	return brush


static func create_button(image: Image) -> Node:
	var button: BaseButton = preload("res://src/UI/Buttons/BrushButton.tscn").instance()
	var tex := ImageTexture.new()
	tex.create_from_image(image, 0)
	button.get_node("BrushTexture").texture = tex
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


static func add_file_brush(images: Array, hint := "") -> void:
	var button := create_button(images[0])
	button.brush.type = FILE if images.size() == 1 else RANDOM_FILE
	button.brush.image = images[0]
	button.brush.random = images
	button.hint_tooltip = hint
	var container
	if button.brush.type == RANDOM_FILE:
		container = Global.brushes_popup.get_node(
			"Background/Brushes/Categories/RandomFileBrushContainer"
		)
	else:
		container = Global.brushes_popup.get_node(
			"Background/Brushes/Categories/FileBrushContainer"
		)
	container.add_child(button)
	button.brush.index = button.get_index()


static func add_project_brush(image: Image, hint := "") -> void:
	var button := create_button(image)
	button.brush.type = CUSTOM
	button.brush.image = image
	button.hint_tooltip = hint
	var container = Global.brushes_popup.get_node(
		"Background/Brushes/Categories/ProjectBrushContainer"
	)
	container.add_child(button)
	button.brush.index = button.get_index()
	container.visible = true
	Global.brushes_popup.get_node("Background/Brushes/Categories/ProjectLabel").visible = true


static func clear_project_brush() -> void:
	var container = Global.brushes_popup.get_node(
		"Background/Brushes/Categories/ProjectBrushContainer"
	)
	for child in container.get_children():
		child.queue_free()
		Global.brushes_popup.emit_signal("brush_removed", child.brush)


func get_brush(type: int, index: int) -> Brush:
	var container = get_node("Background/Brushes/Categories/DefaultBrushContainer")
	match type:
		CUSTOM:
			container = get_node("Background/Brushes/Categories/ProjectBrushContainer")
		FILE:
			container = get_node("Background/Brushes/Categories/FileBrushContainer")
		RANDOM_FILE:
			container = get_node("Background/Brushes/Categories/RandomFileBrushContainer")

	var brush := get_default_brush()
	if index < container.get_child_count():
		brush = container.get_child(index).brush
	return brush


func remove_brush(brush_button: Node) -> void:
	emit_signal("brush_removed", brush_button.brush)

	var project = Global.current_project
	var undo_brushes: Array = project.brushes.duplicate()
	project.brushes.erase(brush_button.brush.image)

	if project.brushes.size() == 0:
		var container = Global.brushes_popup.get_node(
			"Background/Brushes/Categories/ProjectBrushContainer"
		)
		container.visible = false
		Global.brushes_popup.get_node("Background/Brushes/Categories/ProjectLabel").visible = false

	project.undos += 1
	project.undo_redo.create_action("Delete Custom Brush")
	project.undo_redo.add_do_property(project, "brushes", project.brushes)
	project.undo_redo.add_undo_property(project, "brushes", undo_brushes)
	project.undo_redo.add_do_method(self, "redo_custom_brush", brush_button)
	project.undo_redo.add_undo_method(self, "undo_custom_brush", brush_button)
	project.undo_redo.add_undo_reference(brush_button)
	project.undo_redo.commit_action()


func undo_custom_brush(brush_button: BaseButton = null) -> void:
	Global.general_undo()
	var action_name: String = Global.current_project.undo_redo.get_current_action_name()
	if action_name == "Delete Custom Brush":
		$Background/Brushes/Categories/ProjectBrushContainer.add_child(brush_button)
		$Background/Brushes/Categories/ProjectBrushContainer.move_child(
			brush_button, brush_button.brush.index
		)
		brush_button.get_node("DeleteButton").visible = false


func redo_custom_brush(brush_button: BaseButton = null) -> void:
	Global.general_redo()
	var action_name: String = Global.current_project.undo_redo.get_current_action_name()
	if action_name == "Delete Custom Brush":
		$Background/Brushes/Categories/ProjectBrushContainer.remove_child(brush_button)
