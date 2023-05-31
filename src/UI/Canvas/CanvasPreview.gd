extends Node2D

enum Mode { TIMELINE, SPRITESHEET }
var mode: int = Mode.TIMELINE

var h_frames := 1
var v_frames := 1
var start_sprite_sheet_frame := 1
var end_sprite_sheet_frame := 1
var sprite_frames := []
var frame_index := 0

@onready var animation_timer := $AnimationTimer as Timer
@onready var transparent_checker = get_parent().get_node("TransparentChecker") as ColorRect


func _ready() -> void:
	Global.connect("cel_changed", Callable(self, "_cel_changed"))


func _draw() -> void:
	var current_project: Project = Global.current_project
	match mode:
		Mode.TIMELINE:
			var modulate_color := Color.WHITE
			if frame_index >= current_project.frames.size():
				frame_index = current_project.current_frame
			if animation_timer.is_stopped():
				frame_index = current_project.current_frame
			var frame: Frame = current_project.frames[frame_index]
			animation_timer.wait_time = frame.duration * (1.0 / current_project.fps)
			var current_cels: Array = frame.cels

			# Draw current frame layers
			for i in range(current_cels.size()):
				var cel: BaseCel = current_cels[i]
				if cel is GroupCel:
					continue
				modulate_color = Color(1, 1, 1, cel.opacity)
				if (
					i < current_project.layers.size()
					and current_project.layers[i].is_visible_in_hierarchy()
				):
					draw_texture(cel.image_texture, Vector2.ZERO, modulate_color)
		Mode.SPRITESHEET:
			var texture_to_draw: ImageTexture
			var target_frame: Frame = current_project.frames[current_project.current_frame]
			var frame_image := Image.new()
			frame_image.create(
				current_project.size.x, current_project.size.y, false, Image.FORMAT_RGBA8
			)
			Export.blend_all_layers(frame_image, target_frame)
			sprite_frames = _split_spritesheet(frame_image, h_frames, v_frames)

			# limit start and end
			if end_sprite_sheet_frame > sprite_frames.size():
				end_sprite_sheet_frame = sprite_frames.size()
			if start_sprite_sheet_frame < 0:
				start_sprite_sheet_frame = 0
			# reset frame if required
			if frame_index >= end_sprite_sheet_frame:
				frame_index = start_sprite_sheet_frame - 1
			texture_to_draw = sprite_frames[frame_index]
			draw_texture(texture_to_draw, Vector2.ZERO)

			var rect := Rect2(Vector2.ZERO, texture_to_draw.get_data().get_size())
			transparent_checker.fit_rect(rect)


func _on_AnimationTimer_timeout() -> void:
	match mode:
		Mode.TIMELINE:
			var current_project: Project = Global.current_project
			var first_frame := 0
			var last_frame: int = current_project.frames.size() - 1

			if Global.play_only_tags:
				for tag in current_project.animation_tags:
					if (
						current_project.current_frame + 1 >= tag.from
						&& current_project.current_frame + 1 <= tag.to
					):
						first_frame = tag.from - 1
						last_frame = min(current_project.frames.size() - 1, tag.to - 1)

			if frame_index < last_frame:
				frame_index += 1
			else:
				frame_index = first_frame

			animation_timer.wait_time = (
				current_project.frames[frame_index].duration
				* (1.0 / current_project.fps)
			)

		Mode.SPRITESHEET:
			frame_index += 1
			animation_timer.wait_time = (1.0 / Global.current_project.fps)
	animation_timer.set_one_shot(true)
	animation_timer.start()
	update()


func _cel_changed() -> void:
	update()


func _split_spritesheet(image: Image, horiz: int, vert: int) -> Array:
	var result := []
	horiz = min(horiz, image.get_size().x)
	vert = min(vert, image.get_size().y)
	var frame_width := image.get_size().x / horiz
	var frame_height := image.get_size().y / vert
	for yy in range(vert):
		for xx in range(horiz):
			var tex := ImageTexture.new()
			var cropped_image := Image.new()
			var rect := Rect2(frame_width * xx, frame_height * yy, frame_width, frame_height)
			cropped_image = image.get_rect(rect)
			cropped_image.convert(Image.FORMAT_RGBA8)
			tex.create_from_image(cropped_image) #,0
			result.append(tex)
	return result
