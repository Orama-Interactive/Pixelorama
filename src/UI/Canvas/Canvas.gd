class_name Canvas
extends Node2D

enum BlendMode {NORMAL, 
				ADD,
				SUB,
				MUL,
				SCREEN,
				DIFFERENCE,
				BURN,
				DODGE,
				OVERLAY,
				SOFT_LIGHT,
				HARD_LIGHT,
				}

var current_pixel := Vector2.ZERO
var sprite_changed_this_frame := false  # For optimization purposes
var move_preview_location := Vector2.ZERO

onready var currently_visible_frame: Viewport = $CurrentlyVisibleFrame
onready var current_frame_drawer = $CurrentlyVisibleFrame/CurrentFrameDrawer
onready var tile_mode = $TileMode
onready var pixel_grid = $PixelGrid
onready var grid = $Grid
onready var selection = $Selection
onready var indicators = $Indicators
onready var previews = $Previews


func _ready() -> void:
	$OnionPast.type = $OnionPast.PAST
	$OnionPast.blue_red_color = Color.blue
	$OnionFuture.type = $OnionFuture.FUTURE
	$OnionFuture.blue_red_color = Color.red
	yield(get_tree(), "idle_frame")
	camera_zoom()
	
	generate_shader()


func _draw() -> void:
	Global.second_viewport.get_child(0).get_node("CanvasPreview").update()
	Global.small_preview_viewport.get_child(0).get_node("CanvasPreview").update()

	var current_cels: Array = Global.current_project.frames[Global.current_project.current_frame].cels
	var current_layer: int = Global.current_project.current_layer
	var position_tmp := position
	var scale_tmp := scale
	if Global.mirror_view:
		position_tmp.x = position_tmp.x + Global.current_project.size.x
		scale_tmp.x = -1
	draw_set_transform(position_tmp, rotation, scale_tmp)
	# Draw current frame layers
	for i in range(Global.current_project.layers.size()):
		var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
		if Global.current_project.layers[i].visible:  # if it's visible
			if i == current_layer:
				draw_texture(current_cels[i].image_texture, Vector2.ZERO, modulate_color)
			else:
				draw_texture(current_cels[i].image_texture, Vector2.ZERO, modulate_color)
#move_preview_location,

	for i in range(Global.current_project.layers.size()):
		if Global.current_project.layers[i].visible:  # if it's visible
			material.set_shader_param("tex%s" % i, current_cels[i].image_texture)

	if Global.onion_skinning:
		refresh_onion()
	currently_visible_frame.size = Global.current_project.size
	current_frame_drawer.update()
	if Global.current_project.tile_mode != Global.TileMode.NONE:
		tile_mode.update()
	draw_set_transform(position, rotation, scale)


func _input(event: InputEvent) -> void:
	# Don't process anything below if the input isn't a mouse event, or Shift/Ctrl.
	# This decreases CPU/GPU usage slightly.
	if not event is InputEventMouse:
		if not event is InputEventKey:
			return
		elif not event.scancode in [KEY_SHIFT, KEY_CONTROL]:
			return
#	elif not get_viewport_rect().has_point(event.position):
#		return

	# Do not use self.get_local_mouse_position() because it return unexpected
	# value when shrink parameter is not equal to one. At godot version 3.2.3
	var tmp_transform = get_canvas_transform().affine_inverse()
	var tmp_position = Global.main_viewport.get_local_mouse_position()
	current_pixel = tmp_transform.basis_xform(tmp_position) + tmp_transform.origin

	if Global.has_focus:
		update()

	sprite_changed_this_frame = false

	Tools.handle_draw(current_pixel.floor(), event)

	if sprite_changed_this_frame:
		update_selected_cels_textures()


func camera_zoom() -> void:
	# Set camera zoom based on the sprite size
	var bigger_canvas_axis = max(Global.current_project.size.x, Global.current_project.size.y)
	var zoom_max := Vector2(bigger_canvas_axis, bigger_canvas_axis) * 0.01

	for camera in Global.cameras:
		if zoom_max > Vector2.ONE:
			camera.zoom_max = zoom_max
		else:
			camera.zoom_max = Vector2.ONE

		if camera == Global.camera_preview:
			Global.preview_zoom_slider.max_value = -camera.zoom_min.x
			Global.preview_zoom_slider.min_value = -camera.zoom_max.x

		camera.fit_to_frame(Global.current_project.size)
		camera.save_values_to_project()

	Global.transparent_checker.update_rect()


func generate_shader() -> void:
#	var current_cels: Array = Global.current_project.frames[Global.current_project.current_frame].cels
	var current_layers: Array = Global.current_project.layers

	var uniforms := ""
	var draws := ""
	for i in range(Global.current_project.layers.size()):
#		var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
		if Global.current_project.layers[i].visible:  # if it's visible
			uniforms += "uniform sampler2D tex%s;" % i
			
			var tex := "texture(tex%s, UV)" % i
			var normal := "mix(col.rgb, {tex}.rgb, {tex}.a).rgb".format({"tex": tex})
			var blend := ""
			match current_layers[i].blend_mode:
				BlendMode.NORMAL:
					blend = "mix(col.rgb, {tex}.rgb, {tex}.a)"
				BlendMode.ADD:
					blend = "mix(col.rgb, clamp(col.rgb + {tex}.rgb, 0.0, 1.0).rgb, {tex}.a).rgb"
				BlendMode.SUB:
					blend = "mix(col.rgb, clamp(col.rgb - {tex}.rgb, 0.0, 1.0).rgb, {tex}.a).rgb"
				BlendMode.MUL:
					blend = "mix(col.rgb, clamp(col.rgb * {tex}.rgb, 0.0, 1.0).rgb, {tex}.a).rgb"
				BlendMode.SCREEN:
					blend = "mix(col.rgb, clamp(mix(col.rgb, 1.0 - (1.0 - col.rgb) * (1.0 - {tex}.rgb), {tex}.a), 0.0, 1.0).rgb, {tex}.a).rgb"
				BlendMode.DIFFERENCE:
					blend = "mix(col.rgb, clamp(abs(col.rgb - {tex}.rgb), 0.0, 1.0).rgb, {tex}.a).rgb"
				BlendMode.BURN:
					blend = "mix(col.rgb, clamp(1.0 - (1.0 - col.rgb) / {tex}.rgb, 0.0, 1.0).rgb, {tex}.a).rgb"
				BlendMode.DODGE:
					blend = "mix(col.rgb, clamp(col.rgb / (1.0 - {tex}.rgb), 0.0, 1.0).rgb, {tex}.a).rgb"
				BlendMode.OVERLAY:
					blend = "mix(col.rgb, clamp(mix(2.0 * col.rgb * {tex}.rgb, 1.0 - 2.0 * (1.0 - {tex}.rgb) * (1.0 - col.rgb), round(col.rgb)), 0.0, 1.0).rgb, {tex}.a).rgb"
				BlendMode.SOFT_LIGHT:
					blend = "mix(col.rgb, clamp(mix(2.0 * col.rgb * {tex}.rgb + col.rgb * col.rgb * (1.0 - 2.0 * {tex}.rgb), sqrt(col.rgb) * (2.0 * {tex}.rgb - 1.0) + (2.0 * col.rgb) * (1.0 - {tex}.rgb), round(col.rgb)), 0.0, 1.0).rgb, {tex}.a).rgb"
				BlendMode.HARD_LIGHT:
					blend = "mix(col.rgb, clamp(mix(2.0 * {tex}.rgb * col.rgb, 1.0 - 2.0 * (1.0 - col.rgb) * (1.0 - {tex}.rgb), round(col.rgb)), 0.0, 1.0).rgb, {tex}.a).rgb"

			blend = blend.format({"tex": tex})
			draws += "col.rgb = mix({normal}, {blend}, col.a);".format({"normal": normal, "blend": blend})
			draws += "col.a = mix(col.a, 1.0, {tex}.a);".format({"tex": tex})

	var code : String = """
shader_type canvas_item;

{uniforms}

void fragment() {
	vec4 col;
	{draws}
	COLOR = col;
}"""
	code = code.format({"uniforms": uniforms, "draws": draws})
	material.shader.code = code


func update_texture(layer_i: int, frame_i := -1, project: Project = Global.current_project) -> void:
	if frame_i == -1:
		frame_i = project.current_frame

	if frame_i < project.frames.size() and layer_i < project.layers.size():
		var current_cel: Cel = project.frames[frame_i].cels[layer_i]
		current_cel.image_texture.set_data(current_cel.image)

		if project == Global.current_project:
			var container_index = Global.frames_container.get_child_count() - 1 - layer_i
			var layer_cel_container = Global.frames_container.get_child(container_index)
			var cel_button = layer_cel_container.get_child(frame_i)
			var cel_texture_rect: TextureRect
			cel_texture_rect = cel_button.find_node("CelTexture")
			cel_texture_rect.texture = current_cel.image_texture


func update_selected_cels_textures(project: Project = Global.current_project) -> void:
	for cel_index in project.selected_cels:
		var frame_index: int = cel_index[0]
		var layer_index: int = cel_index[1]
		if frame_index < project.frames.size() and layer_index < project.layers.size():
			var current_cel: Cel = project.frames[frame_index].cels[layer_index]
			current_cel.image_texture.set_data(current_cel.image)

			if project == Global.current_project:
				var container_index = Global.frames_container.get_child_count() - 1 - layer_index
				var layer_cel_container = Global.frames_container.get_child(container_index)
				var cel_button = layer_cel_container.get_child(frame_index)
				var cel_texture_rect: TextureRect = cel_button.find_node("CelTexture")
				cel_texture_rect.texture = current_cel.image_texture


func refresh_onion() -> void:
	$OnionPast.update()
	$OnionFuture.update()
