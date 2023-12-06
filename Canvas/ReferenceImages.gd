extends Node2D
# Make it so that we only save the positions / rotation / scale when we release the button
# Make a cancel transform like in Selection.gd
## This node contains [ReferenceImage] nodes and handles the reference image gizmo

var index := -1
var holding_ri := false
var holding_start_pos : Vector2

var original_position : Vector2
var original_scale : Vector2
var original_rotation : float

## Updates the index and configures the "gizmo"
func update_index(new_index: int) -> void:
	index = new_index
	if index < 0:
		# DO something :<
		pass
	else:
		# DO something :<
		pass
	
	queue_redraw()

## Fore updates the gizmo drawing.
func update() -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	var poly := get_current_ri_polygon()
	
	if poly.size() < 3:
		return
	
	var ri : ReferenceImage = Global.current_project.reference_images[index]
	
	
	# The mouse is over the ReferenceImage
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed() and Geometry2D.is_point_in_polygon(get_local_mouse_position(), poly):
				Global.can_draw = false
				holding_start_pos = get_local_mouse_position()
				holding_ri = true
				
				# Set the original positions
				original_position = ri.position
				original_scale = ri.scale
				original_rotation = ri.rotation
				
			if !event.is_pressed():
				Global.can_draw = true
				holding_ri = false
		
		# This code was a proof of concept
		# To be implemented with a shortcut instead
		# If the rmb is pressed we create a menu of all the [ReferenceImage]'s
		#elif event.button_index == MOUSE_BUTTON_RIGHT:
			#var menu = PopupMenu.new()
			#menu.add_item("None", 0)
			#menu.add_separator()
			## Create the list
			#var reference_images := Global.current_project.reference_images
			#for idx : int in reference_images.size():
				#var i = reference_images[idx]
				#var title = "(%o) %s" %[idx, i.image_path]
				#menu.add_item(title, idx + 1)
			#
			## If a id is pressed we want to select a ReferenceImage and delete the menu
			#menu.id_pressed.connect(_menu_id_pressed.bind(menu))
			## If the menu gets hidden we want to delete the menu
			#menu.visibility_changed.connect(_menu_visibility_changed.bind(menu))
			## Add the menu directly to the root Control node
			#Global.control.add_child(menu)
			#menu.position = get_global_mouse_position() + Vector2(10, 10)
			#menu.popup()
				
			
	if event is InputEventMouseMotion:
		if holding_ri:
			ri.position = original_position
			ri.scale = original_scale
			ri.rotation = original_rotation
			# Scale
			if event.get_modifiers_mask() == KEY_MASK_ALT:
				ri.scale = original_scale + ((get_global_mouse_position() - holding_start_pos) / 100)
			# Rotate
			elif event.get_modifiers_mask() == KEY_MASK_CTRL:
				ri.look_at(get_global_mouse_position())
				ri.rotation = wrapf(ri.rotation, -PI, PI)
				ri.change_properties()
			# Move
			else:
				ri.set_global_position(get_global_mouse_position() - (holding_start_pos - original_position))
				ri.change_properties()
			
			queue_redraw()
			

func get_current_ri_polygon() -> PackedVector2Array:
	return get_ri_polygon(index)

## Makes a polygon that matches the transformed [ReferenceImage]
func get_ri_polygon(i: int) -> PackedVector2Array:
	if index < 0:
		return []
		
	var ri : ReferenceImage = Global.current_project.reference_images[index]
	var rect := ri.get_rect() * Transform2D(0.0, ri.scale, 0.0, Vector2.ZERO)
	#rect.position -= rect.position
	var poly : PackedVector2Array = [rect.position, Vector2(rect.end.x, rect.position.y),
									rect.end, Vector2(rect.position.x, rect.end.y)]
	poly = poly * Transform2D(-ri.rotation, Vector2.ONE, 0.0, Vector2.ZERO)
	
	var final : PackedVector2Array = []
	for p in poly:
		final.append(p + ri.position)
	
	return final

# When a id is pressed in the reference menu
func _menu_id_pressed(id: int, menu: PopupMenu) -> void:
	print(id - 1)
	Global.control.find_child("Reference Images").reference_image_clicked.emit(id - 1)
	menu.queue_free()
# When the menus visibility is changed
func _menu_visibility_changed(menu: PopupMenu) -> void:
	if !menu.visible:
		menu.queue_free()


func _draw() -> void:
	draw_colored_polygon(get_current_ri_polygon(), Color(Color.WHITE, 0.3))
