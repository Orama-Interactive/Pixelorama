extends Node2D

enum { PAST, FUTURE }

var type := PAST
var opacity := 0.6
var blue_red_color := Color.BLUE
var rate := Global.onion_skinning_past_rate

@onready var canvas := get_parent() as Canvas


func _draw() -> void:
	var project := Global.current_project
	if !Global.onion_skinning:
		return
	rate = Global.onion_skinning_past_rate if type == PAST else Global.onion_skinning_future_rate
	if rate <= 0:
		return

	var color := blue_red_color if Global.onion_skinning_blue_red else Color.WHITE
	var position_tmp := position
	var scale_tmp := scale
	if Global.mirror_view:
		position_tmp.x += project.size.x
		scale_tmp.x = -1
	draw_set_transform(position_tmp, rotation, scale_tmp)

	for i in range(1, rate + 1):
		var change := project.current_frame
		change += i if type == FUTURE else -i
		if change == clampi(change, 0, project.frames.size() - 1):
			var layer_i := 0
			for cel in project.frames[change].cels:
				var layer := project.layers[layer_i]
				if layer.is_visible_in_hierarchy() and not layer.ignore_onion:
					var parent_bone := BoneLayer.get_parent_bone(layer)
					var bone_offset := Vector2i.ZERO
					if parent_bone:
						if not parent_bone.is_edit_mode():
							var bone_cel := parent_bone.get_current_bone_cel(change)
							bone_offset = bone_cel.start_point
					color.a = opacity / i
					if [change, layer_i] in project.selected_cels:
						draw_texture(
							cel.image_texture, canvas.move_preview_location + bone_offset, color
						)
					else:
						draw_texture(cel.image_texture, bone_offset, color)
				layer_i += 1
	draw_set_transform(position, rotation, scale)
