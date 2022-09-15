extends Node2D

enum { PAST, FUTURE }

var type := PAST
var blue_red_color := Color.blue
var rate := Global.onion_skinning_past_rate


func _draw() -> void:
	if !Global.onion_skinning:
		return
	rate = Global.onion_skinning_past_rate if type == PAST else Global.onion_skinning_future_rate
	if rate <= 0:
		return

	var color := blue_red_color if Global.onion_skinning_blue_red else Color.white
	var position_tmp := position
	var scale_tmp := scale
	if Global.mirror_view:
		position_tmp.x += Global.current_project.size.x
		scale_tmp.x = -1
	draw_set_transform(position_tmp, rotation, scale_tmp)

	for i in range(1, rate + 1):
		var change: int = Global.current_project.current_frame
		change += i if type == FUTURE else -i
		if change == clamp(change, 0, Global.current_project.frames.size() - 1):
			var layer_i := 0
			for cel in Global.current_project.frames[change].cels:
				var layer: BaseLayer = Global.current_project.layers[layer_i]
				if layer.is_visible_in_hierarchy():
					# Ignore layer if it has the "_io" suffix in its name (case in-sensitive)
					if not (layer.name.to_lower().ends_with("_io")):
						color.a = 0.6 / i
						draw_texture(cel.image_texture, Vector2.ZERO, color)
				layer_i += 1
	draw_set_transform(position, rotation, scale)
