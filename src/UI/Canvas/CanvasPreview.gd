extends Node2D

enum Mode { TIMELINE, SPRITESHEET }
var mode := Mode.TIMELINE
## Use this material only when the animation of the canvas preview is playing
## This way we optimize drawing when the frame being shown is the same as the main canvas
var animation_material := material as ShaderMaterial
var h_frames := 1
var v_frames := 1
var start_sprite_sheet_frame := 1
var end_sprite_sheet_frame := 1
var frame_index := 0:
	set(value):
		frame_index = value
		if mode == Mode.SPRITESHEET:
			return
		if frame_index == Global.current_project.current_frame:  # Animation not playing
			if material != Global.canvas.material:
				material = Global.canvas.material
		else:  # The animation of the canvas preview is playing
			if material != animation_material:
				material = animation_material

@onready var animation_timer := $AnimationTimer as Timer
@onready var transparent_checker = get_parent().get_node("TransparentChecker") as ColorRect


func _ready() -> void:
	Global.cel_switched.connect(_cel_switched)
	material = Global.canvas.material


func _draw() -> void:
	var project := Global.current_project
	match mode:
		Mode.TIMELINE:
			if frame_index >= project.frames.size():
				frame_index = project.current_frame
			if animation_timer.is_stopped():
				frame_index = project.current_frame
			var frame := project.frames[frame_index]
			animation_timer.wait_time = frame.duration * (1.0 / project.fps)
			# If we just use the first cel and it happens to be a GroupCel
			# nothing will get drawn
			var cel_to_draw := Global.current_project.find_first_drawable_cel(frame)
			# Placeholder so we can have a material here
			if is_instance_valid(cel_to_draw):
				draw_texture(cel_to_draw.image_texture, Vector2.ZERO)
			if material == animation_material:
				# Only use a unique material if the animation of the canvas preview is playing
				# Otherwise showing a different frame than the main canvas is impossible
				_draw_layers()
		Mode.SPRITESHEET:
			var image := project.frames[project.current_frame].cels[0].get_image()
			var slices := _split_spritesheet(image, h_frames, v_frames)
			# Limit start and end
			if end_sprite_sheet_frame > slices.size():
				end_sprite_sheet_frame = slices.size()
			if start_sprite_sheet_frame < 0:
				start_sprite_sheet_frame = 0
			if frame_index >= end_sprite_sheet_frame:
				frame_index = start_sprite_sheet_frame - 1
			var src_rect := slices[frame_index]
			var rect := Rect2(Vector2.ZERO, src_rect.size)
			# If we just use the first cel and it happens to be a GroupCel
			# nothing will get drawn
			var cel_to_draw := Global.current_project.find_first_drawable_cel()
			# Placeholder so we can have a material here
			if is_instance_valid(cel_to_draw):
				draw_texture_rect_region(cel_to_draw.image_texture, rect, src_rect)
			transparent_checker.fit_rect(rect)


func _draw_layers() -> void:
	var project := Global.current_project
	var current_frame := project.frames[frame_index]
	var current_cels := current_frame.cels
	var textures: Array[Image] = []
	# Nx4 texture, where N is the number of layers and the first row are the blend modes,
	# the second are the opacities, the third are the origins and the fourth are the
	# clipping mask booleans.
	var metadata_image := Image.create(project.layers.size(), 4, false, Image.FORMAT_R8)
	# Draw current frame layers
	for i in project.ordered_layers:
		var cel := current_cels[i]
		var layer := project.layers[i]
		var cel_image: Image
		if layer.is_blender():
			cel_image = layer.blend_children(
				current_frame, Vector2i.ZERO, Global.display_layer_effects
			)
		else:
			if Global.display_layer_effects:
				cel_image = layer.display_effects(cel)
			else:
				cel_image = cel.get_image()
		textures.append(cel_image)
		DrawingAlgos.set_layer_metadata_image(layer, cel, metadata_image, i)
	var texture_array := Texture2DArray.new()
	texture_array.create_from_images(textures)
	material.set_shader_parameter("layers", texture_array)
	material.set_shader_parameter("metadata", ImageTexture.create_from_image(metadata_image))


func _on_AnimationTimer_timeout() -> void:
	match mode:
		Mode.TIMELINE:
			var project := Global.current_project
			var first_frame := 0
			var last_frame := project.frames.size() - 1

			if Global.play_only_tags:
				for tag in project.animation_tags:
					if project.current_frame + 1 >= tag.from && project.current_frame + 1 <= tag.to:
						first_frame = tag.from - 1
						last_frame = mini(project.frames.size() - 1, tag.to - 1)

			if frame_index < last_frame:
				frame_index += 1
			else:
				frame_index = first_frame
			animation_timer.wait_time = project.frames[frame_index].duration * (1.0 / project.fps)

		Mode.SPRITESHEET:
			frame_index += 1
			animation_timer.wait_time = 1.0 / Global.current_project.fps
	animation_timer.set_one_shot(true)
	animation_timer.start()
	queue_redraw()


func _cel_switched() -> void:
	queue_redraw()


func _split_spritesheet(image: Image, horiz: int, vert: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	horiz = mini(horiz, image.get_size().x)
	vert = mini(vert, image.get_size().y)
	var frame_width := image.get_size().x / horiz
	var frame_height := image.get_size().y / vert
	for yy in range(vert):
		for xx in range(horiz):
			result.append(Rect2(frame_width * xx, frame_height * yy, frame_width, frame_height))
	return result
