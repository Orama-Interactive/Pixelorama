class_name PhotoshopParser
extends RefCounted

const PSB_EIGHT_BYTE_ADDITIONAL_LAYER_KEYS: PackedStringArray = [
	"LMsk",
	"Lr16",
	"Lr32",
	"Layr",
	"Mt16",
	"Mt32",
	"Mtrn",
	"Alph",
	"FMsk",
	"lnk2",
	"FEid",
	"FXid",
	"PxSD"
]


class PhotoshopProject:
	var layers: Array[PhotoshopLayer] = []
	var guides: Array[Dictionary] = []
	var frames: Dictionary[int, PhotoshopFrame] = {}
	var size := Vector2i()
	var path: String


class PhotoshopFrame:
	var index := 0
	var delay_cs := 100  ## Delay in centiseconds.
	var layer_data: Dictionary[int, Dictionary] = {}

	func _init(
		_index := 0, _delay_cs := 100, _layer_data: Dictionary[int, Dictionary] = {}
	) -> void:
		index = _index
		delay_cs = _delay_cs
		layer_data = _layer_data

	func _to_string() -> String:
		return "Index: %s, Delay: %s, Layer Data: %s" % [index, delay_cs, layer_data]


class PhotoshopLayer:
	var index := 0
	var name := "Layer 0"
	var top := 0
	var left := 0
	var bottom := 0
	var right := 0
	var width := 0
	var height := 0
	var group_type := "layer"
	var blend_mode := "norm"
	var channels: Array[Dictionary] = []
	var visible := true
	var opacity := 255.0
	var clipping := false
	var color := Color(0, 0, 0, 0)
	var image: Image
	var layer_child_level := 0


# https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/
# https://github.com/layervault/psd.rb/wiki/Anatomy-of-a-PSD-File
# https://github.com/gaoyan2659365465/Godot4Library/blob/main/addons/psd/psd.gd
# gdlint: disable=function-variable-name
static func open_photoshop_file(path: String) -> void:
	var psd_file := FileAccess.open(path, FileAccess.READ)
	if FileAccess.get_open_error() != OK or psd_file == null:
		return
	psd_file.big_endian = true
	# File header
	var signature := psd_file.get_buffer(4).get_string_from_utf8()
	if signature != "8BPS":
		return
	var version := psd_file.get_16()
	if version != 1 and version != 2:
		return
	var is_psb := version == 2
	psd_file.get_buffer(6)  # Reserved
	var _n_of_channels := psd_file.get_16()
	var height := psd_file.get_32()
	var width := psd_file.get_32()
	var _depth := psd_file.get_16()
	# Color Mode Data
	var _color_mode := psd_file.get_16()
	var color_data_length := psd_file.get_32()
	if color_data_length > 0:
		var data_start := psd_file.get_position()
		psd_file.seek(data_start + color_data_length)
	var guides: Array[Dictionary] = []
	# Image Resources
	var image_resources_length := psd_file.get_32()
	var frames: Dictionary[int, PhotoshopFrame] = {}
	if image_resources_length > 0:
		var data_start := psd_file.get_position()
		var data_end := data_start + image_resources_length
		while psd_file.get_position() < data_end:
			var image_resources_signature := psd_file.get_buffer(4).get_string_from_ascii()
			if image_resources_signature != "8BIM":
				return
			var resource_id := psd_file.get_16()
			var name_len := psd_file.get_8()
			var _name := psd_file.get_buffer(name_len).get_string_from_utf8()
			# Pad to even byte count
			if (name_len + 1) % 2 != 0:
				psd_file.get_8()  # Padding byte

			var size := psd_file.get_32()
			if resource_id == 4000:  # Plug-in resource
				var plugin_data_start := psd_file.get_position()
				psd_file.get_buffer(12)  # Not sure what these are for
				var plugin_signature := psd_file.get_buffer(4).get_string_from_ascii()
				if plugin_signature == "8BIM":
					var plugin_key := psd_file.get_buffer(4).get_string_from_ascii()
					if plugin_key == "AnDs":  # Read frame data
						# Not sure if these are indeed a size and a version
						# because this part is not documented, but it would make the most sense.
						var _ands_size := psd_file.get_32()
						var _ands_version := psd_file.get_32()  # Seems to be 16.
						var descriptor := parse_descriptor(psd_file)
						if descriptor.has("FrIn"):
							var frin: Array = descriptor["FrIn"]
							for i in frin.size():
								var frame = frin[i]
								if not frame.has("FrID") or not frame.has("FrDl"):
									continue
								var frame_id = frame["FrID"]
								var frame_delay = frame["FrDl"]
								frames[frame_id] = PhotoshopFrame.new(i, frame_delay, {})
				psd_file.seek(plugin_data_start + ((size + 1) & ~1))
			else:
				var data := psd_file.get_buffer(size)
				if resource_id == 1032:  # Grid and guides
					var gg_version_buffer := data.slice(0, 4)
					gg_version_buffer.reverse()
					var _gg_version := gg_version_buffer.decode_s32(0)
					var guide_count_buffer := data.slice(12, 16)
					guide_count_buffer.reverse()
					var guide_count := guide_count_buffer.decode_s32(0)
					var byte_index := 16
					for i in guide_count:
						var guide_location_buffer := data.slice(byte_index, byte_index + 4)
						guide_location_buffer.reverse()
						var guide_location := guide_location_buffer.decode_s32(0)
						var guide_direction := data[byte_index + 4]
						byte_index += 5
						guides.append(
							{"position": guide_location / 32.0, "direction": guide_direction}
						)
				if size % 2 != 0:
					psd_file.get_8()  # Padding byte
		psd_file.seek(data_end)
	# Layer and Mask Information Section
	var _layer_and_mask_info_section_length: int
	if is_psb:
		_layer_and_mask_info_section_length = psd_file.get_64()
	else:
		_layer_and_mask_info_section_length = psd_file.get_32()
	# Layer info
	var _layer_info_length: int
	if is_psb:
		_layer_info_length = psd_file.get_64()
	else:
		_layer_info_length = psd_file.get_32()
	var layer_count := get_signed_16(psd_file)
	if layer_count < 0:
		layer_count = -layer_count
	var layer_child_level := 0
	var psd_layers: Array[PhotoshopLayer] = []
	# Layer records
	for i in layer_count:
		var layer := PhotoshopLayer.new()
		layer.index = i
		layer.top = get_signed_32(psd_file)
		layer.left = get_signed_32(psd_file)
		layer.bottom = get_signed_32(psd_file)
		layer.right = get_signed_32(psd_file)
		layer.width = layer.right - layer.left
		layer.height = layer.bottom - layer.top
		layer.name = "Layer %s" % i
		layer.group_type = "layer"

		var num_channels := psd_file.get_16()
		layer.channels = []

		for j in range(num_channels):
			var channel := {}
			channel.id = get_signed_16(psd_file)
			if is_psb:
				channel.length = psd_file.get_64()
			else:
				channel.length = psd_file.get_32()
			layer.channels.append(channel)
		var blend_mode_signature := psd_file.get_buffer(4).get_string_from_utf8()
		if blend_mode_signature != "8BIM":
			return
		var blend_mode_key := psd_file.get_buffer(4).get_string_from_utf8()
		layer.blend_mode = blend_mode_key
		var opacity := psd_file.get_8()
		layer.opacity = opacity
		var clipping := psd_file.get_8()
		layer.clipping = clipping
		var flags := psd_file.get_8()
		layer.visible = flags & 2 != 2
		var _filler := psd_file.get_8()
		var extra_data_field_length := psd_file.get_32()
		var extra_start := psd_file.get_position()
		var extra_end := extra_start + extra_data_field_length

		# First 4 bytes: Layer mask data length (skip it)
		var layer_mask_data_len := psd_file.get_32()
		psd_file.seek(psd_file.get_position() + layer_mask_data_len)

		# Next 4 bytes: Layer blending ranges data length (skip it)
		var blend_range_len := psd_file.get_32()
		psd_file.seek(psd_file.get_position() + blend_range_len)

		# Next: Pascal string (layer name)
		var name_length := psd_file.get_8()
		@warning_ignore("integer_division") var padded_length := (((name_length + 4) / 4) * 4) - 1
		layer.name = psd_file.get_buffer(padded_length).get_string_from_utf8()

		# Remaining: Additional Layer Information blocks
		while psd_file.get_position() < extra_end:
			var _sig := psd_file.get_buffer(4).get_string_from_utf8()
			var key := psd_file.get_buffer(4).get_string_from_utf8()
			var length: int
			if is_psb and key in PSB_EIGHT_BYTE_ADDITIONAL_LAYER_KEYS:
				length = psd_file.get_64()
			else:
				length = psd_file.get_32()
			var data_start := psd_file.get_position()
			if key == "lsct":
				var section_type := psd_file.get_32()
				match section_type:
					1:
						layer.group_type = "start"
						layer_child_level -= 1
					2:
						layer.group_type = "start_closed"
						layer_child_level -= 1
					3:
						layer.group_type = "end"
						layer_child_level += 1
					_:
						layer.group_type = "layer"
				if length >= 12:
					var _section_signature := psd_file.get_buffer(4).get_string_from_utf8()
					var section_blend_mode_key := psd_file.get_buffer(4).get_string_from_utf8()
					layer.blend_mode = section_blend_mode_key
					if length >= 16:
						# 0 = normal, 1 = scene group, affects the animation timeline.
						var _sub_type := psd_file.get_32()
			elif key == "luni":
				var unicode_layer_name := parse_unicode_string(psd_file)
				layer.name = unicode_layer_name
			elif key == "lclr":
				layer.color = parse_lclr_block(psd_file.get_buffer(8))
			elif key == "shmd":
				var metadata_items := psd_file.get_32()
				for metadata_item in metadata_items:
					var _metadata_signature := psd_file.get_buffer(4).get_string_from_utf8()
					var metadata_key := psd_file.get_buffer(4).get_string_from_utf8()
					var _metadata_copy_on_sheet_duplication := psd_file.get_8()
					var _metadata_padding := psd_file.get_buffer(3)
					var metadata_length := psd_file.get_32()
					var metadata_start := psd_file.get_position()
					if metadata_key == "mlst":
						var _mlst_version := psd_file.get_32()  # Should be equal to 16.
						var descriptor := parse_descriptor(psd_file)
						if descriptor.has("LaSt"):
							var layer_state: Array = descriptor["LaSt"]
							var layer_enabled := layer.visible
							for layer_state_frame in layer_state:
								if layer_state_frame.has("FrLs"):
									var frame_id = layer_state_frame["FrLs"][0]
									if not frames.has(frame_id):
										frames[frame_id] = PhotoshopFrame.new(frames.size())
									layer_enabled = layer_state_frame.get("enab", layer_enabled)
									var layer_fxrf = layer_state_frame.get("FXRf", {})
									var layer_offset = layer_state_frame.get("Ofst", {})
									var layer_dict := {
										"enab": layer_enabled,
										"FXRf": layer_fxrf,
										"Ofst": layer_offset
									}
									frames[frame_id].layer_data[layer.index] = layer_dict
					psd_file.seek(metadata_start + ((metadata_length + 1) & ~1))

			# Move to next block (align length to even)
			psd_file.seek(data_start + ((length + 1) & ~1))

		layer.layer_child_level = layer_child_level
		psd_layers.append(layer)

	# Track file offset for each layer's image data at Channel Image Data block
	for layer in psd_layers:
		for channel in layer.channels:
			channel.data_offset = psd_file.get_position()
			psd_file.seek(psd_file.get_position() + channel.length)

	# Decode images in the PSD's layers.
	# This is the most important part of the whole process.
	for layer in psd_layers:
		if layer.group_type == "layer":
			var image := decode_psd_layer(psd_file, layer, is_psb)
			if is_instance_valid(image) and not image.is_empty():
				layer.image = image

	psd_file.close()
	var psd_project := PhotoshopProject.new()
	psd_project.size = Vector2i(width, height)
	psd_project.layers = psd_layers
	psd_project.frames = frames
	psd_project.guides = guides
	psd_project.path = path
	psd_to_pxo_project(psd_project, true)


static func psd_to_pxo_project(psd_project: PhotoshopProject, add_frames := true) -> void:
	var project_size := psd_project.size
	var new_project := Project.new([], psd_project.path.get_file().get_basename(), project_size)
	new_project.fps = 1
	# Initialize frames
	if psd_project.frames.size() == 0 or not add_frames:
		psd_project.frames = {0: PhotoshopFrame.new()}
	var frames: Array[Frame]
	for frame_id in psd_project.frames:
		var psd_frame := psd_project.frames[frame_id]
		var frame := Frame.new()
		var delay_cs := psd_frame.delay_cs
		frame.duration = delay_cs / 100.0
		frames.append(frame)

	# Initialize layers
	if psd_project.layers.size() == 0:
		var layer := PhotoshopLayer.new()
		layer.name = "Layer 0"
		layer.group_type = "layer"
		layer.right = project_size.x
		layer.width = project_size.x
		layer.bottom = project_size.y
		layer.height = project_size.y
		layer.layer_child_level = 0
		psd_project.layers = [layer]
	var layer_index := 0
	for psd_layer in psd_project.layers:
		if psd_layer.group_type == "end":
			continue
		if psd_layer.group_type.begins_with("start"):
			var layer := GroupLayer.new(new_project, psd_layer.name)
			layer.visible = psd_layer.visible
			layer.opacity = psd_layer.opacity / 255.0
			layer.clipping_mask = psd_layer.clipping
			layer.blend_mode = match_blend_modes(psd_layer.blend_mode)
			layer.ui_color = psd_layer.get("color")
			layer.index = layer_index
			layer.set_meta(&"psd_layer", psd_layer)
			layer.expanded = psd_layer.group_type == "start"
			new_project.layers.append(layer)
			layer_index += 1
		else:
			var layer := PixelLayer.new(new_project, psd_layer.name)
			layer.visible = psd_layer.visible
			layer.opacity = psd_layer.opacity / 255.0
			layer.clipping_mask = psd_layer.clipping
			layer.blend_mode = match_blend_modes(psd_layer.blend_mode)
			layer.ui_color = psd_layer.color
			layer.index = layer_index
			layer.set_meta(&"psd_layer", psd_layer)
			new_project.layers.append(layer)
			layer_index += 1

	organize_layer_child_levels(new_project)

	# Initialize cels.
	# Needs to happen after initializing layers so we can look into the layer's parents
	# to see if they are being animated.
	for layer in new_project.layers:
		var psd_layer: PhotoshopLayer = layer.get_meta(&"psd_layer")
		if layer is GroupLayer:
			for frame in frames:
				var cel := layer.new_empty_cel()
				frame.cels.append(cel)
		elif layer is PixelLayer:
			if is_instance_valid(psd_layer.image) and not psd_layer.image.is_empty():
				var psd_layer_index := psd_layer.index
				var visible_layer_in_frames := get_layer_visibility_per_frame(
					psd_project.frames, psd_layer_index, layer.visible
				)
				var animated_layer := layer
				if (
					visible_layer_in_frames.size() == 0
					or visible_layer_in_frames.size() == psd_project.frames.size()
				):
					# First, loop through parent layer groups in case they are being animated.
					for ancestor in layer.get_ancestors():
						var psd_ancestor: PhotoshopLayer = ancestor.get_meta(&"psd_layer")
						var psd_ancestor_index := psd_ancestor.index
						visible_layer_in_frames = get_layer_visibility_per_frame(
							psd_project.frames, psd_ancestor_index, ancestor.visible
						)
						if (
							visible_layer_in_frames.size() > 0
							and visible_layer_in_frames.size() < psd_project.frames.size()
						):
							# We found animated data.
							animated_layer = ancestor
							break
				if (
					visible_layer_in_frames.size() == 0
					or visible_layer_in_frames.size() == psd_project.frames.size()
				):
					# If the layer is not visible in any frame or it is visible in all frames,
					# it means that it is not being animated.
					for frame_i in psd_project.frames.size():
						var image := offset_cel_image(psd_layer.image, layer, psd_project, frame_i)
						var frame := frames[frame_i]
						var cel := (layer as PixelLayer).new_cel_from_image(image)
						frame.cels.append(cel)
				else:
					# Layers that are not visible in the first frame will be treated as invisible
					# in general. So we need to set them to be visible.
					animated_layer.visible = true
					for frame_i in psd_project.frames.size():
						var frame := frames[frame_i]
						if frame_i in visible_layer_in_frames:
							var image := offset_cel_image(
								psd_layer.image, layer, psd_project, frame_i
							)
							var cel := (layer as PixelLayer).new_cel_from_image(image)
							frame.cels.append(cel)
						else:
							var cel := layer.new_empty_cel()
							frame.cels.append(cel)
			else:
				for frame in frames:
					var cel := layer.new_empty_cel()
					frame.cels.append(cel)

	new_project.frames = frames
	for layer in new_project.layers:
		layer.remove_meta(&"psd_layer")
	new_project.order_layers()
	# Initialize guides.
	for psd_guide in psd_project.guides:
		var guide := Guide.new()
		if psd_guide.direction == 0:
			guide.type = Guide.Types.VERTICAL
			guide.add_point(Vector2(psd_guide.position, -99999))
			guide.add_point(Vector2(psd_guide.position, 99999))
		else:
			guide.type = Guide.Types.HORIZONTAL
			guide.add_point(Vector2(-99999, psd_guide.position))
			guide.add_point(Vector2(99999, psd_guide.position))
		guide.has_focus = false
		guide.project = new_project
		new_project.guides.append(guide)
		Global.canvas.add_child(guide)

	new_project.save_path = psd_project.path.get_basename() + ".pxo"
	new_project.file_name = new_project.name
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()


static func offset_cel_image(
	image: Image, layer: BaseLayer, psd_project: PhotoshopProject, frame_index: int
) -> Image:
	var result_image := Image.new()
	result_image.copy_from(image)
	var project_size := psd_project.size
	result_image.crop(project_size.x, project_size.y)
	var img_copy := Image.new()
	img_copy.copy_from(result_image)
	result_image.fill(Color(0, 0, 0, 0))
	var psd_layer: PhotoshopLayer = layer.get_meta(&"psd_layer")
	var left := psd_layer.left
	var top := psd_layer.top
	var offset := Vector2i(left, top)
	for frame_id in psd_project.frames:
		var frame := psd_project.frames[frame_id]
		if frame.index != frame_index:
			continue
		var psd_layer_index := psd_layer.index
		if frame.layer_data.has(psd_layer_index):
			var offset_dict: Dictionary = frame.layer_data[psd_layer_index].get("Ofst", {})
			offset.x += offset_dict.get("Hrzn", 0)
			offset.y += offset_dict.get("Vrtc", 0)
	result_image.blit_rect(img_copy, Rect2i(Vector2i.ZERO, result_image.get_size()), offset)
	return result_image


static func get_layer_visibility_per_frame(
	frames: Dictionary[int, PhotoshopFrame], layer_index: int, layer_visible: bool
) -> PackedInt32Array:
	var visible_layer_in_frames: PackedInt32Array
	for frame_id in frames:
		var frame := frames[frame_id]
		var layer_enabled: bool = layer_visible
		if frame.layer_data.has(layer_index):
			var layer_data := frame.layer_data[layer_index]
			layer_enabled = layer_data.get("enab", layer_visible)
		if layer_enabled:
			visible_layer_in_frames.append(frame.index)
	return visible_layer_in_frames


static func get_signed_16(file: FileAccess) -> int:
	var buffer := file.get_buffer(2)
	if file.big_endian:
		buffer.reverse()
	return buffer.decode_s16(0)


static func get_signed_32(file: FileAccess) -> int:
	var buffer := file.get_buffer(4)
	if file.big_endian:
		buffer.reverse()
	return buffer.decode_s32(0)


static func get_signed_64(file: FileAccess) -> int:
	var buffer := file.get_buffer(8)
	if file.big_endian:
		buffer.reverse()
	return buffer.decode_s32(0)


static func decode_psd_layer(psd_file: FileAccess, layer: PhotoshopLayer, is_psb: bool) -> Image:
	var img_channels := {}
	for channel in layer.channels:
		psd_file.seek(channel.data_offset)

		var compression := psd_file.get_16()
		var width: int = layer.width
		var height: int = layer.height
		var size: int = width * height
		if size <= 0:
			continue

		var raw_data := PackedByteArray()

		if compression == 0:  # Raw Data
			raw_data = psd_file.get_buffer(size)
		elif compression == 1:  # RLE
			var scanline_counts: PackedInt32Array = []
			for i in range(height):
				if is_psb:
					scanline_counts.append(psd_file.get_32())
				else:
					scanline_counts.append(psd_file.get_16())

			for i in range(height):
				var scanline := PackedByteArray()
				var bytes_remaining := scanline_counts[i]
				while scanline.size() < width and bytes_remaining > 0:
					var n := psd_file.get_8()
					bytes_remaining -= 1
					if n >= 128:
						var count := 257 - n
						var val := psd_file.get_8()
						bytes_remaining -= 1
						for j in range(count):
							scanline.append(val)
					else:
						var count := n + 1
						for j in range(count):
							var val := psd_file.get_8()
							scanline.append(val)
						bytes_remaining -= count
				raw_data.append_array(scanline)
		else:
			push_error("Unsupported compression: %d" % compression)
			continue

		if not raw_data.is_empty():
			img_channels[channel.id] = raw_data

	# Rebuild image
	var img_data := PackedByteArray()
	for i in range(layer.width * layer.height):
		var r = img_channels[0][i] if img_channels.has(0) else 255
		var g = img_channels[1][i] if img_channels.has(1) else 255
		var b = img_channels[2][i] if img_channels.has(2) else 255
		var a = img_channels[-1][i] if img_channels.has(-1) else 255
		img_data.append_array([r, g, b, a])

	var image: Image
	if layer.width > 0 and layer.height > 0:
		image = Image.create_from_data(
			layer.width, layer.height, false, Image.FORMAT_RGBA8, img_data
		)
	return image


## Match Photoshop's blend modes to Pixelorama's
static func match_blend_modes(blend_mode: String) -> BaseLayer.BlendModes:
	match blend_mode:
		"pass":  # Only used for group layers
			return BaseLayer.BlendModes.PASS_THROUGH
		"norm":
			return BaseLayer.BlendModes.NORMAL
		"eras":
			return BaseLayer.BlendModes.ERASE
		"dark":
			return BaseLayer.BlendModes.DARKEN
		"mul ":
			return BaseLayer.BlendModes.MULTIPLY
		"burn":
			return BaseLayer.BlendModes.COLOR_BURN
		"ldbr":
			return BaseLayer.BlendModes.LINEAR_BURN
		"lite":
			return BaseLayer.BlendModes.LIGHTEN
		"scrn":
			return BaseLayer.BlendModes.SCREEN
		"div ":
			return BaseLayer.BlendModes.DIVIDE
		"diff":
			return BaseLayer.BlendModes.DIFFERENCE
		"smud":  # Not used here, legacy
			return BaseLayer.BlendModes.NORMAL
		"idiv":
			return BaseLayer.BlendModes.DIVIDE
		"dodg":
			return BaseLayer.BlendModes.COLOR_DODGE
		"add ":
			return BaseLayer.BlendModes.ADD
		"over":
			return BaseLayer.BlendModes.OVERLAY
		"sLit":
			return BaseLayer.BlendModes.SOFT_LIGHT
		"hLit":
			return BaseLayer.BlendModes.HARD_LIGHT
		"excl":
			return BaseLayer.BlendModes.EXCLUSION
		"sub ":
			return BaseLayer.BlendModes.SUBTRACT
		"hue ":
			return BaseLayer.BlendModes.HUE
		"sat ":
			return BaseLayer.BlendModes.SATURATION
		"colr":
			return BaseLayer.BlendModes.COLOR
		"lum ":
			return BaseLayer.BlendModes.LUMINOSITY
		_:
			return BaseLayer.BlendModes.NORMAL


## Used to determine the color of the layer in the UI.
static func parse_lclr_block(buffer: PackedByteArray) -> Color:
	if buffer.size() < 8:
		return Color(0, 0, 0, 0)
	var color_index := buffer[1]
	match color_index:
		0:
			return Color(0, 0, 0, 0)
		1:
			return Color.RED
		2:
			return Color.ORANGE
		3:
			return Color.YELLOW
		4:
			return Color.GREEN
		5:
			return Color.BLUE
		6:
			return Color.VIOLET
		7:
			return Color.GRAY
		_:
			return Color(0, 0, 0, 0)


static func parse_unicode_string(f: FileAccess) -> String:
	var length := f.get_32()
	if length == 0:
		return ""
	var bytes := f.get_buffer(length * 2)
	var s := ""
	for i in range(length):
		var hi := int(bytes[i * 2])
		var lo := int(bytes[i * 2 + 1])
		s += char((hi << 8) | lo)
	return s


static func parse_class_id(f: FileAccess) -> String:
	var length := f.get_32()
	if length == 0:
		return f.get_buffer(4).get_string_from_utf8()
	return f.get_buffer(length).get_string_from_utf8()


static func parse_descriptor(f: FileAccess) -> Dictionary:
	var desc := {}
	var _name := parse_unicode_string(f)
	var _class_id := parse_class_id(f)
	var item_count := f.get_32()
	for i in range(item_count):
		var key := parse_class_id(f)
		var type_key := f.get_buffer(4).get_string_from_utf8()
		var value = parse_descriptor_value(f, type_key)
		desc[key] = value
	return desc


static func parse_descriptor_value(f: FileAccess, type_key: String) -> Variant:
	match type_key:
		"long":
			return get_signed_32(f)
		"comp":
			return get_signed_64(f)
		"doub":
			return f.get_double()
		"bool":
			return f.get_8() != 0
		"TEXT":
			return parse_unicode_string(f)
		"enum":
			var type := parse_class_id(f)  # enum type
			var value := parse_class_id(f)  # enum value
			return {"enum_type": type, "enum_value": value}
		"Objc", "GlbO":
			return parse_descriptor(f)
		"VlLs":
			var count := f.get_32()
			var arr := []
			for i in range(count):
				var key := f.get_buffer(4).get_string_from_utf8()
				arr.append(parse_descriptor_value(f, key))
			return arr
		"UntF":
			return parse_unit(f, true)
		"UnFl":
			return parse_unit(f, false)
		_:
			# Skip unknown types
			print("Unknown descriptor type:", type_key)
			return null


static func parse_unit(f: FileAccess, double := true) -> Dictionary:
	var unit_id := f.get_buffer(4).get_string_from_utf8()
	var value: float
	if double:
		value = f.get_double()
	else:
		value = f.get_float()
	return {"id": unit_id, "value": value}


static func organize_layer_child_levels(project: Project) -> void:
	for i in project.layers.size():
		var layer := project.layers[i]
		var psd_layer: PhotoshopLayer = layer.get_meta(&"psd_layer")
		var layer_child_level := psd_layer.layer_child_level
		if layer_child_level > 0:
			var parent_layer: GroupLayer = null
			var parent_i := 1
			while parent_layer == null and i + parent_i < project.layers.size():
				var prev_layer := project.layers[i + parent_i]
				if prev_layer is GroupLayer:
					var prev_psd_layer: PhotoshopLayer = prev_layer.get_meta(&"psd_layer")
					var prev_layer_child_level := prev_psd_layer.layer_child_level
					if prev_layer_child_level == layer_child_level - 1:
						parent_layer = prev_layer
						break
				parent_i += 1
			if is_instance_valid(parent_layer):
				layer.parent = parent_layer
	for i in project.layers.size():
		var layer := project.layers[i]
		layer.index = i
