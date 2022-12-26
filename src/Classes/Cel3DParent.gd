#class_name Cel3DParent
#extends Spatial
#
#signal selected_object(object)
#
#var cel  #: Cel3D
#var hovering: Cel3DObject = null
#var selected: Cel3DObject = null setget _set_selected
#var dragging := false
#var has_been_dragged := false
#var prev_mouse_pos := Vector2.ZERO
#
#onready var camera := get_viewport().get_camera()
#
#
#func _ready() -> void:
#	Global.connect("cel_changed", self, "_cel_changed")
#
#
#func _inputo(event: InputEvent) -> void:
#	if event.is_action_pressed("delete") and is_instance_valid(selected):
#		selected.delete()
#		self.selected = null
#	if not event is InputEventMouse:
#		return
#	if not cel.layer.can_layer_get_drawn():
#		return
#	var found_cel := false
#	for frame_layer in Global.current_project.selected_cels:
#		if cel == Global.current_project.frames[frame_layer[0]].cels[frame_layer[1]]:
#			found_cel = true
#	if not found_cel:
#		return
#	var mouse_pos: Vector2 = event.position
#	if event is InputEventMouseButton:
#		if event.button_index == BUTTON_LEFT and event.pressed == true:
#			if is_instance_valid(hovering):
#				self.selected = hovering
#				dragging = true
#				prev_mouse_pos = mouse_pos
#			else:
#				# We're not hovering
#				if is_instance_valid(selected):
#					# If we're not clicking on a gizmo, unselect
#					if selected.applying_gizmos == Cel3DObject.Gizmos.NONE:
#						self.selected = null
#					else:
#						dragging = true
#						prev_mouse_pos = mouse_pos
#		elif event.button_index == BUTTON_LEFT and event.pressed == false:
#			dragging = false
#			if is_instance_valid(selected) and has_been_dragged:
#				selected.finish_changing_property()
#			has_been_dragged = false
#
#	var ray_from := camera.project_ray_origin(mouse_pos)
#	var ray_to := ray_from + camera.project_ray_normal(mouse_pos) * 20
#	var space_state := get_world().direct_space_state
#	var selection := space_state.intersect_ray(ray_from, ray_to)
#
#	if dragging and event is InputEventMouseMotion:
#		has_been_dragged = true
#		var proj_mouse_pos := camera.project_position(mouse_pos, camera.translation.z)
#		var proj_prev_mouse_pos := camera.project_position(prev_mouse_pos, camera.translation.z)
#		selected.change_transform(proj_mouse_pos, proj_prev_mouse_pos)
#		prev_mouse_pos = mouse_pos
#
#	# Hover logic
#	if selection.empty():
#		if is_instance_valid(hovering):
#			hovering.unhover()
#			hovering = null
#	else:
#		if is_instance_valid(hovering):
#			hovering.unhover()
#		hovering = selection["collider"].get_parent()
#		hovering.hover()
#
#
#func _set_selected(value: Cel3DObject) -> void:
#	if value == selected:
#		return
#	if is_instance_valid(selected):  # Unselect previous object if we selected something else
#		selected.unselect()
#	selected = value
#	if is_instance_valid(selected):  # Select new object
#		selected.select()
#	emit_signal("selected_object", value)
#
#
#func _cel_changed() -> void:
#	self.selected = null
