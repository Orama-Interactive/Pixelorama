extends Node2D

enum Mode { TIMELINE, SPRITESHEET }
var mode = Mode.TIMELINE

var h_frames: int = 1
var v_frames: int = 1
var start_sprite_sheet_frame: int = 1
var end_sprite_sheet_frame: int = 1
var sprite_frames = []

var frame: int = 0

onready var animation_timer: Timer = $AnimationTimer


func _draw() -> void:
	var current_project: Project = Global.current_project
	var texture_to_draw: Texture
	var modulate_color := Color.white
	match mode:
		Mode.TIMELINE:
			if frame >= current_project.frames.size():
				frame = current_project.current_frame

			$AnimationTimer.wait_time = (
				current_project.frames[frame].duration
				* (1 / Global.current_project.fps)
			)

			if animation_timer.is_stopped():
				frame = current_project.current_frame
			var current_cels: Array = current_project.frames[frame].cels

			# Draw current frame layers
			for i in range(current_cels.size()):
				if current_cels[i] is GroupCel:
					continue
				modulate_color = Color(1, 1, 1, current_cels[i].opacity)
				if (
					i < current_project.layers.size()
					and current_project.layers[i].is_visible_in_hierarchy()
				):
					texture_to_draw = current_cels[i].image_texture
		Mode.SPRITESHEET:
			var target_frame = current_project.frames[current_project.current_frame]
			var frame_image = Image.new()
			frame_image.create(
				current_project.size.x, current_project.size.y, false, Image.FORMAT_RGBA8
			)
			Export.blend_all_layers(frame_image, target_frame)
			sprite_frames = split_spritesheet(frame_image, h_frames, v_frames)

			# limit start and end
			if end_sprite_sheet_frame > sprite_frames.size():
				end_sprite_sheet_frame = sprite_frames.size()
			if start_sprite_sheet_frame < 0:
				start_sprite_sheet_frame = 0
			# reset frame if required
			if frame >= end_sprite_sheet_frame:
				frame = start_sprite_sheet_frame - 1
			texture_to_draw = sprite_frames[frame]

	if not texture_to_draw:
		return
	var rect := Rect2(Vector2.ZERO, texture_to_draw.get_data().get_size())
	get_parent().get_node("TransparentChecker").fit_rect(rect)
	draw_texture(texture_to_draw, Vector2.ZERO, modulate_color)


func _on_AnimationTimer_timeout() -> void:
	match mode:
		Mode.TIMELINE:
			var first_frame := 0
			var last_frame: int = Global.current_project.frames.size() - 1
			var current_project: Project = Global.current_project

			if Global.play_only_tags:
				for tag in current_project.animation_tags:
					if (
						current_project.current_frame + 1 >= tag.from
						&& current_project.current_frame + 1 <= tag.to
					):
						first_frame = tag.from - 1
						last_frame = min(current_project.frames.size() - 1, tag.to - 1)

			if frame < last_frame:
				frame += 1
			else:
				frame = first_frame

			$AnimationTimer.wait_time = (
				Global.current_project.frames[frame].duration
				* (1 / Global.current_project.fps)
			)

		Mode.SPRITESHEET:
			frame += 1
			$AnimationTimer.wait_time = (1 / Global.current_project.fps)
	$AnimationTimer.set_one_shot(true)
	$AnimationTimer.start()
	update()


func split_spritesheet(image: Image, horiz: int, vert: int) -> Array:
	var result = []
	horiz = min(horiz, image.get_size().x)
	vert = min(vert, image.get_size().y)
	var frame_width := image.get_size().x / horiz
	var frame_height := image.get_size().y / vert
	for yy in range(vert):
		for xx in range(horiz):
			var tex := ImageTexture.new()
			var cropped_image := Image.new()
			cropped_image = image.get_rect(
				Rect2(frame_width * xx, frame_height * yy, frame_width, frame_height)
			)
			cropped_image.convert(Image.FORMAT_RGBA8)
			tex.create_from_image(cropped_image, 0)
			result.append(tex)
	return result
