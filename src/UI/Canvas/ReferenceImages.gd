extends Node2D

## This node contains [ReferenceImage] nodes

signal reference_image_changed(index: int)

enum Mode { SELECT, MOVE, ROTATE, SCALE }

var mode: Mode = Mode.SELECT

var index: int:
	get:
		return Global.current_project.reference_index
var drag_start_pos: Vector2
var dragging := false
var lmb_held := false  ## Holds whether the LBB is being held (use dragging for actual checks)

# Original Transform
var og_pos: Vector2
var og_scale: Vector2
var og_rotation: float

var undo_data: Dictionary

var reference_menu := PopupMenu.new()


func _ready() -> void:
	Global.camera.zoom_changed.connect(_update_on_zoom)
	Global.control.get_node("Dialogs").add_child(reference_menu)

	# Makes sure that the dark overlay disappears when the popup is hidden
	reference_menu.visibility_changed.connect(func(): Global.dialog_open(reference_menu.visible))
	# Emitted when a item is selected from the menu
	reference_menu.id_pressed.connect(_reference_menu_id_pressed)


## Updates the index and configures the "gizmo"
func update_index(new_index: int) -> void:
	index = new_index
	reference_image_changed.emit(new_index)
	queue_redraw()


func _input(event: InputEvent) -> void:
	var local_mouse_pos := get_local_mouse_position()

	# Check if that event was for the quick menu (opened by the shortcut)
	if event.is_action_pressed("reference_quick_menu"):
		var list: Array[ReferenceImage] = Global.current_project.reference_images
		populate_reference_menu(list, true)
		var popup_position := Global.control.get_global_mouse_position()
		reference_menu.popup_on_parent(Rect2i(popup_position, Vector2i.ONE))

	var ri: ReferenceImage = Global.current_project.get_current_reference_image()

	if !ri:
		return

	# Check if want to cancelthe reference transform
	if event.is_action_pressed("cancel_reference_transform") and dragging:
		ri.position = og_pos
		ri.scale = og_scale
		ri.rotation = og_rotation
		dragging = false
		Global.can_draw = true
		commit_undo("Cancel Transform Content", undo_data)
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				dragging = false
				lmb_held = true
				undo_data = get_undo_data()
				Global.can_draw = false
				drag_start_pos = get_local_mouse_position()
				# Set the original positions
				og_pos = ri.position
				og_scale = ri.scale
				og_rotation = ri.rotation

			if !event.is_pressed():
				Global.can_draw = true

				if dragging:
					commit_undo("Transform Content", undo_data)
				else:
					# Overlapping reference images
					var overlapping: Array[ReferenceImage] = []

					for idx: int in Global.current_project.reference_images.size():
						var r := Global.current_project.reference_images[idx]
						# The bounding polygon
						var p := get_reference_polygon(idx)
						if Geometry2D.is_point_in_polygon(local_mouse_pos, p):
							overlapping.append(r)

					# Some special cases
					# 1. There is only one Reference Image
					if overlapping.size() == 1:
						var idx := overlapping[0].get_index()
						Global.current_project.set_reference_image_index(idx)
					# 2. There are more than 1 Reference Images
					elif overlapping.size() > 1:
						populate_reference_menu(overlapping, true)
						var popup_position := Global.control.get_global_mouse_position()
						reference_menu.popup_on_parent(Rect2i(popup_position, Vector2i.ONE))
					# 3. There are no Reference Images
					else:
						Global.current_project.set_reference_image_index(-1)

				undo_data.clear()
				dragging = false
				lmb_held = false

	if event is InputEventMouseMotion:
		# We check if the LMB is pressed and if we're not dragging then we force the
		# dragging state.
		# We dont use timers because it makes more sense to wait for the users mouse to move
		# and that's what defines dragging. It would be smart to add a "deadzone" to determine
		# if the mouse had moved enough.
		if lmb_held and !dragging:
			dragging = true

		if dragging:
			var text := ""

			if mode == Mode.SELECT:
				# Scale
				if Input.is_action_pressed("reference_scale"):
					scale_reference_image(local_mouse_pos, ri)
					text = str(
						"Moving: ", (og_scale * 100).floor(), " -> ", (ri.scale * 100).floor()
					)
				# Rotate
				elif Input.is_action_pressed("reference_rotate"):
					rotate_reference_image(local_mouse_pos, ri)
					text = str(
						"Rotating: ",
						floorf(rad_to_deg(og_rotation)),
						"° -> ",
						floorf(rad_to_deg(ri.rotation)),
						"°"
					)
				else:
					move_reference_image(local_mouse_pos, ri)
					text = str("Moving to: ", og_pos.floor(), " -> ", ri.position.floor())
			elif mode == Mode.MOVE:
				move_reference_image(local_mouse_pos, ri)
				text = str("Moving to: ", og_pos.floor(), " -> ", ri.position.floor())
			elif mode == Mode.ROTATE:
				rotate_reference_image(local_mouse_pos, ri)
				text = str(
					"Rotating: ",
					floorf(rad_to_deg(og_rotation)),
					"° -> ",
					floorf(rad_to_deg(ri.rotation)),
					"°"
				)
			elif mode == Mode.SCALE:
				scale_reference_image(local_mouse_pos, ri)
				text = str("Moving: ", (og_scale * 100).floor(), " -> ", (ri.scale * 100).floor())

			Global.cursor_position_label.text = text

		queue_redraw()


## Uniformly scales the [ReferenceImage] using this nodes "local_mouse_position".
func scale_reference_image(mouse_pos: Vector2, img: ReferenceImage) -> void:
	var s := (
		Vector2.ONE
		* minf(
			float(mouse_pos.x - drag_start_pos.x),
			float(mouse_pos.y - drag_start_pos.y),
		)
	)

	img.scale = (og_scale + (s / 100.0))


## Rotate the [ReferenceImage] using this nodes "local_mouse_position".
func rotate_reference_image(mouse_pos: Vector2, img: ReferenceImage) -> void:
	var starting_angle := og_rotation - og_pos.angle_to_point(drag_start_pos)
	var new_angle := img.position.angle_to_point(mouse_pos)
	var angle := starting_angle + new_angle
	angle = deg_to_rad(floorf(rad_to_deg(wrapf(angle, -PI, PI))))
	img.rotation = angle


## Move the [ReferenceImage] using this nodes "local_mouse_position".
func move_reference_image(mouse_pos: Vector2, img: ReferenceImage) -> void:
	img.position = (mouse_pos - (drag_start_pos - og_pos)).floor()


## Makes a polygon that matches the transformed [ReferenceImage]
func get_reference_polygon(i: int) -> PackedVector2Array:
	if i < 0:
		return []

	var ri: ReferenceImage = Global.current_project.reference_images[i]
	var rect := ri.get_rect()
	var poly := get_transformed_rect_polygon(rect, ri.transform)
	return poly


## Returns a [PackedVector2Array] based on the corners of the [Rect2].
## This function also transforms the polygon.
func get_transformed_rect_polygon(rect: Rect2, t: Transform2D) -> PackedVector2Array:
	# First we scale the Rect2
	rect.position *= t.get_scale()
	rect.size *= t.get_scale()

	# We create a polygon based on the Rect2
	var p: PackedVector2Array = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]

	# Finally rotate and move the polygon
	var final: PackedVector2Array = []
	for v: Vector2 in p:
		var vert := v.rotated(t.get_rotation()) + t.get_origin()
		final.append(vert)

	return final


func populate_reference_menu(items: Array[ReferenceImage], default := false) -> void:
	reference_menu.clear()
	# Default / Reset
	if default:
		reference_menu.add_item("None", 0)
		reference_menu.add_separator()

	for ri: ReferenceImage in items:
		# NOTE: using image_path.get_file() instead of full image_path because usually paths are
		# long and if we are limiting to 22 characters as well, then every entry will end up
		# looking the same
		var idx: int = ri.get_index() + 1
		var label: String = "(%o) %s" % [idx, ri.image_path.get_file()]
		# We trim the length of the title
		label = label.left(22) + "..."
		reference_menu.add_item(label, idx)


# When a id is pressed in the reference menu
func _reference_menu_id_pressed(id: int) -> void:
	Global.can_draw = true
	Global.current_project.set_reference_image_index(id - 1)
	reference_menu.hide()


func remove_reference_image(idx: int) -> void:
	var ri: ReferenceImage = Global.current_project.get_reference_image(idx)
	Global.current_project.reference_images.remove_at(idx)
	ri.queue_free()
	Global.current_project.set_reference_image_index(-1)
	Global.current_project.change_project()


func _update_on_zoom() -> void:
	queue_redraw()


func get_undo_data() -> Dictionary:
	var ri: ReferenceImage = Global.current_project.get_current_reference_image()

	if !ri:
		return {}

	var data := {}
	data["position"] = ri.position
	data["scale"] = ri.scale
	data["rotation"] = ri.rotation
	data["overlay_color"] = ri.overlay_color
	data["filter"] = ri.filter
	data["monochrome"] = ri.monochrome
	data["color_clamping"] = ri.color_clamping
	return data


func commit_undo(action: String, undo_data_tmp: Dictionary) -> void:
	if !undo_data_tmp:
		print("No undo data found for ReferenceImages.gd!")
		return

	var ri: ReferenceImage = Global.current_project.get_current_reference_image()
	if !ri:
		print("No Reference Image ReferenceImages.gd!")
		return

	var redo_data: Dictionary = get_undo_data()
	var project := Global.current_project

	project.undos += 1
	project.undo_redo.create_action(action)

	for key in undo_data_tmp.keys():
		if redo_data.has(key):
			project.undo_redo.add_do_property(ri, key, redo_data.get(key))
			project.undo_redo.add_undo_property(ri, key, undo_data_tmp.get(key))

	project.undo_redo.add_do_method(Global.general_redo.bind(project))
	project.undo_redo.add_do_method(ri.change_properties)
	project.undo_redo.add_undo_method(Global.general_undo.bind(project))
	project.undo_redo.add_undo_method(ri.change_properties)

	project.undo_redo.commit_action()
	undo_data.clear()


func _draw() -> void:
	if index < 0:
		return
	var line_width := 2.0 / Global.camera.zoom.x
	# If we are dragging show where the Reference was coming from
	if dragging:
		var i: ReferenceImage = Global.current_project.get_current_reference_image()
		var prev_transform := Transform2D(og_rotation, og_scale, 0.0, og_pos)
		var prev_poly := get_transformed_rect_polygon(i.get_rect(), prev_transform)
		prev_poly.append(prev_poly[0])
		draw_polyline(prev_poly, Color(1, 0.29, 0.29), line_width)

	# First we highlight the Reference Images under the mouse with yellow
	for ri: ReferenceImage in Global.current_project.reference_images:
		var p := get_transformed_rect_polygon(ri.get_rect(), ri.transform)
		p.append(p[0])
		if ri.get_index() == index:
			draw_polyline(p, Color(0.50, 0.99, 0.29), line_width)
		elif Geometry2D.is_point_in_polygon(get_local_mouse_position(), p) and !dragging:
			draw_polyline(p, Color(0.98, 0.80, 0.29), line_width)
