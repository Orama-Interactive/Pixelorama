extends PanelContainer

var layer_3d: Layer3D
var _object_names: Dictionary[Layer3D.ObjectType, String] = {
	Layer3D.ObjectType.BOX: "Box",
	Layer3D.ObjectType.SPHERE: "Sphere",
	Layer3D.ObjectType.CAPSULE: "Capsule",
	Layer3D.ObjectType.CYLINDER: "Cylinder",
	Layer3D.ObjectType.PRISM: "Prism",
	Layer3D.ObjectType.TORUS: "Torus",
	Layer3D.ObjectType.PLANE: "Plane",
	Layer3D.ObjectType.TEXT: "Text",
	Layer3D.ObjectType.ARRAY_MESH: "Custom model",
	Layer3D.ObjectType.DIR_LIGHT: "Directional light",
	Layer3D.ObjectType.SPOT_LIGHT: "Spotlight",
	Layer3D.ObjectType.OMNI_LIGHT: "Point light",
}

@onready var object_tree: Tree = $VBoxContainer/ObjectTree
@onready var new_object_menu_button := $"%NewObjectMenuButton" as MenuButton
@onready var remove_object_button := $"%RemoveObject" as Button
@onready var load_model_dialog := $LoadModelDialog as FileDialog


func _ready() -> void:
	Global.cel_switched.connect(_on_cel_switched)
	var new_object_popup := new_object_menu_button.get_popup()
	for object in _object_names:
		new_object_popup.add_item(_object_names[object], object)
	new_object_popup.id_pressed.connect(_new_object_popup_id_pressed)
	load_model_dialog.use_native_dialog = Global.use_native_file_dialogs


func _on_cel_switched() -> void:
	if is_instance_valid(layer_3d):
		if layer_3d.selected_object_changed.is_connected(_on_selected_object):
			layer_3d.selected_object_changed.disconnect(_on_selected_object)
	if Global.current_project.layers[Global.current_project.current_layer] is not Layer3D:
		remove_object_button.disabled = true
		layer_3d = null
		return
	layer_3d = Global.current_project.layers[Global.current_project.current_layer]
	layer_3d.selected_object_changed.connect(_on_selected_object)
	remove_object_button.disabled = not is_instance_valid(layer_3d.selected)
	_setup_tree()


func _setup_tree() -> void:
	object_tree.clear()
	var root := object_tree.create_item()
	root.set_text(0, "Root")
	for child in layer_3d.parent_node.get_children():
		var tree_item := object_tree.create_item()
		tree_item.set_text(0, child.name)


func _new_object_popup_id_pressed(id: Layer3D.ObjectType) -> void:
	if id == Layer3D.ObjectType.ARRAY_MESH:
		load_model_dialog.popup_centered_clamped()
		Global.dialog_open(true, true)
	else:
		_add_object(id)


func _add_object(type: Layer3D.ObjectType, custom_mesh: Mesh = null) -> void:
	var node3d := Layer3D.create_node(type, custom_mesh)
	var undo_redo := layer_3d.project.undo_redo
	undo_redo.create_action("Add 3D object")
	undo_redo.add_do_method(layer_3d.parent_node.add_child.bind(node3d, true))
	undo_redo.add_do_property(node3d, &"owner", layer_3d.viewport)
	undo_redo.add_do_reference(node3d)
	undo_redo.add_do_method(_setup_tree)
	undo_redo.add_undo_method(layer_3d.parent_node.remove_child.bind(node3d))
	undo_redo.add_undo_method(_setup_tree)
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.add_do_method(sprite_changed_this_frame)
	undo_redo.add_undo_method(sprite_changed_this_frame)
	undo_redo.commit_action()


func _on_object_tree_item_selected() -> void:
	if layer_3d == null:
		return
	var node := layer_3d.parent_node.get_node_or_null(object_tree.get_selected().get_text(0))
	if is_instance_valid(node):
		layer_3d.selected = node
	else:
		layer_3d.selected = null


func _on_remove_object_pressed() -> void:
	if layer_3d == null:
		return
	if not is_instance_valid(layer_3d.selected):
		return

	var undo_redo := layer_3d.project.undo_redo
	undo_redo.create_action("Remove 3D object")
	var tracks_removed := 0
	for i in layer_3d.animation.get_track_count():
		var track_np := layer_3d.animation.track_get_path(i)
		var node := layer_3d.viewport.get_node_or_null(track_np)
		if node == layer_3d.selected:
			var idx := i - tracks_removed
			tracks_removed += 1
			undo_redo.add_do_method(layer_3d.animation.remove_track.bind(idx))
			undo_redo.add_undo_method(layer_3d.animation.add_track.bind(layer_3d.animation.track_get_type(i), idx))
			undo_redo.add_undo_method(layer_3d.animation.track_set_path.bind(idx, track_np))
			undo_redo.add_undo_method(layer_3d.animation.track_set_interpolation_type.bind(idx, layer_3d.animation.track_get_interpolation_type(i)))
			for j in layer_3d.animation.track_get_key_count(i):
				var key_time := layer_3d.animation.track_get_key_time(i, j)
				var key_value = layer_3d.animation.track_get_key_value(i, j)
				var key_transition := layer_3d.animation.track_get_key_transition(i, j)
				undo_redo.add_undo_method(layer_3d.animation.track_insert_key.bind(idx, key_time, key_value, key_transition))

	undo_redo.add_do_method(layer_3d.parent_node.remove_child.bind(layer_3d.selected))
	undo_redo.add_do_method(_setup_tree)
	undo_redo.add_undo_method(layer_3d.parent_node.add_child.bind(layer_3d.selected))
	undo_redo.add_undo_reference(layer_3d.selected)
	undo_redo.add_undo_method(_setup_tree)
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.add_do_method(sprite_changed_this_frame)
	undo_redo.add_undo_method(sprite_changed_this_frame)
	undo_redo.commit_action()


func _on_selected_object(object: Node3D, _old_object: Node3D) -> void:
	remove_object_button.disabled = not is_instance_valid(object)


func sprite_changed_this_frame() -> void:
	layer_3d.project.get_current_cel().update_texture()
	Global.canvas.sprite_changed_this_frame = true


func _on_load_model_dialog_files_selected(paths: PackedStringArray) -> void:
	for path in paths:
		var mesh := ObjParse.from_path(path)
		_add_object(Layer3D.ObjectType.ARRAY_MESH, mesh)


func _on_load_model_dialog_visibility_changed() -> void:
	Global.dialog_open(false, true)
