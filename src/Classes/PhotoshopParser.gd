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


# https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/
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
			var data := psd_file.get_buffer(size)
			if size % 2 != 0:
				psd_file.get_8()  # Padding byte
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
					guides.append({"position": guide_location / 32.0, "direction": guide_direction})
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
	print("Layer count: ", layer_count)
	var layer_child_level := 0
	var psd_layers: Array[Dictionary] = []
	# Layer records
	for i in layer_count:
		var layer := {}
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
				# Unicode layer name (UTF-16 string length, then UTF-16 content)
				name_length = psd_file.get_32()
				var _name_utf16 := psd_file.get_buffer(name_length * 2)
				#layer.name = name_utf16.get_string_from_utf16()
			elif key == "lclr":
				layer.color = parse_lclr_block(psd_file.get_buffer(8))

			# Move to next block (align length to even)
			psd_file.seek(data_start + ((length + 1) & ~1))

		layer.layer_child_level = layer_child_level
		psd_layers.append(layer)

	# Track file offset for each layer's image data at Channel Image Data block
	for layer in psd_layers:
		for channel in layer.channels:
			channel.data_offset = psd_file.get_position()
			psd_file.seek(psd_file.get_position() + channel.length)

	var project_size := Vector2i(width, height)
	var new_project := Project.new([], path.get_file().get_basename(), project_size)
	var frame := Frame.new()
	var layer_index := 0
	for psd_layer in psd_layers:
		if psd_layer.group_type == "end":
			continue
		if psd_layer.group_type.begins_with("start"):
			var layer := GroupLayer.new(new_project, psd_layer.name)
			layer.visible = psd_layer.visible
			layer.opacity = psd_layer.opacity / 255.0
			layer.clipping_mask = psd_layer.clipping
			layer.blend_mode = match_blend_modes(psd_layer.blend_mode)
			layer.ui_color = psd_layer.color
			layer.index = layer_index
			layer.set_meta(&"layer_child_level", psd_layer.layer_child_level)
			layer.expanded = psd_layer.group_type == "start"
			var cel := layer.new_empty_cel()
			frame.cels.append(cel)
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
			layer.set_meta(&"layer_child_level", psd_layer.layer_child_level)
			new_project.layers.append(layer)
			layer_index += 1
			var image := decode_psd_layer(psd_file, psd_layer, is_psb)
			if is_instance_valid(image) and not image.is_empty():
				image.crop(width, height)
				var img_copy := Image.new()
				img_copy.copy_from(image)
				image.fill(Color(0, 0, 0, 0))
				var offset := Vector2i(psd_layer.left, psd_layer.top)
				image.blit_rect(img_copy, Rect2i(Vector2i.ZERO, image.get_size()), offset)
				var cel := layer.new_cel_from_image(image)
				frame.cels.append(cel)
			else:
				var cel := layer.new_empty_cel()
				frame.cels.append(cel)

	psd_file.close()
	if new_project.layers.size() == 0:
		var layer := PixelLayer.new(new_project)
		layer.index = 0
		new_project.layers.append(layer)
		var cel := layer.new_empty_cel()
		frame.cels.append(cel)
	organize_layer_child_levels(new_project)
	new_project.frames.append(frame)
	new_project.order_layers()
	for psd_guide in guides:
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

	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()


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


static func decode_psd_layer(psd_file: FileAccess, layer: Dictionary, is_psb: bool) -> Image:
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


static func organize_layer_child_levels(project: Project) -> void:
	for i in project.layers.size():
		var layer := project.layers[i]
		var layer_child_level: int = layer.get_meta(&"layer_child_level", 0)
		if layer_child_level > 0:
			var parent_layer: GroupLayer = null
			var parent_i := 1
			while parent_layer == null and i + parent_i < project.layers.size():
				var prev_layer := project.layers[i + parent_i]
				if prev_layer is GroupLayer:
					if prev_layer.get_meta(&"layer_child_level", 0) == layer_child_level - 1:
						parent_layer = prev_layer
						break
				parent_i += 1
			if is_instance_valid(parent_layer):
				layer.parent = parent_layer
	for i in project.layers.size():
		var layer := project.layers[i]
		layer.remove_meta(&"layer_child_level")
		layer.index = i
