class_name PhotoshopParser
extends RefCounted


# https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/
# https://github.com/gaoyan2659365465/Godot4Library/blob/main/addons/psd/psd.gd
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
	print("version: ", version)
	psd_file.get_buffer(6)  # Reserved
	var n_of_channels := psd_file.get_16()
	var height := psd_file.get_32()
	var width := psd_file.get_32()
	var project_size := Vector2i(width, height)
	var new_project := Project.new([], path.get_file().get_basename(), project_size)
	var frame := Frame.new()
	prints(width, height)
	var depth := psd_file.get_16()
	# Color Mode Data
	var color_mode := psd_file.get_16()
	var color_data_length := psd_file.get_32()
	print("Color data length: ", color_data_length)
	if color_data_length > 0:
		var color_data := psd_file.get_buffer(color_data_length)
	# Image Resources
	var image_resources_length := psd_file.get_32()
	print("Image resources length: ", image_resources_length)
	if image_resources_length > 0:
		var image_resources := psd_file.get_buffer(image_resources_length)
	# Layer and Mask Information Section
	var layer_and_mask_info_section_length := psd_file.get_32()
	# Layer info
	var layer_info_length := psd_file.get_32()
	var layer_count_buffer := psd_file.get_buffer(2)
	layer_count_buffer.reverse()
	var layer_count := layer_count_buffer.decode_s16(0)
	if layer_count < 0:
		layer_count = -layer_count
	print("Layer count: ", layer_count)
	var layer_child_level := 0
	var psd_layers: Array[Dictionary] = []
	# Layer records
	for i in layer_count:
		var layer := {}
		layer.top = psd_file.get_32()
		layer.left = psd_file.get_32()
		layer.bottom = psd_file.get_32()
		layer.right = psd_file.get_32()
		layer.width = layer.right - layer.left
		layer.height = layer.bottom - layer.top
		layer.name = "Layer %s" % i
		layer.group_type = "layer"

		var num_channels := psd_file.get_16()
		layer.channels = []

		for j in range(num_channels):
			var channel := {}
			var channel_id_buffer := psd_file.get_buffer(2)
			channel_id_buffer.reverse()
			channel.id = channel_id_buffer.decode_s16(0)
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
		var padded_length := (((name_length + 4) / 4) * 4) - 1
		layer.name = psd_file.get_buffer(padded_length).get_string_from_utf8()

		# Remaining: Additional Layer Information blocks
		while psd_file.get_position() < extra_end:
			var sig := psd_file.get_buffer(4).get_string_from_utf8()  # Should be "8BIM"
			var key := psd_file.get_buffer(4).get_string_from_utf8()
			var length := psd_file.get_32()
			var data_start := psd_file.get_position()

			if key == "lsct":
				var section_type := psd_file.get_32()
				match section_type:
					1, 2:
						layer.group_type = "start"
						layer_child_level -= 1
					3:
						layer.group_type = "end"
						layer_child_level += 1
					_:
						layer.group_type = "layer"
			elif key == "luni":
				# Unicode layer name (UTF-16 string length, then UTF-16 content)
				name_length = psd_file.get_32()
				var name_utf16 := psd_file.get_buffer(name_length * 2)
				#layer.name = name_utf16.get_string_from_utf16()

			# Move to next block (align length to even)
			psd_file.seek(data_start + ((length + 1) & ~1))

		layer.layer_child_level = layer_child_level
		prints(layer.name, layer.group_type, layer.layer_child_level)
		psd_layers.append(layer)

	# Track file offset for each layer's image data at Channel Image Data block
	for layer in psd_layers:
		for channel in layer.channels:
			channel.data_offset = psd_file.get_position()
			psd_file.seek(psd_file.get_position() + channel.length)

	var layer_index := 0
	for psd_layer in psd_layers:
		if psd_layer.group_type == "end":
			continue
		if psd_layer.group_type == "start":
			var layer := GroupLayer.new(new_project, psd_layer.name)
			layer.visible = psd_layer.visible
			layer.opacity = psd_layer.opacity / 255.0
			layer.index = layer_index
			layer.set_meta(&"layer_child_level", psd_layer.layer_child_level)
			var cel := layer.new_empty_cel()
			frame.cels.append(cel)
			new_project.layers.append(layer)
			layer_index += 1
		else:
			var layer := PixelLayer.new(new_project, psd_layer.name)
			layer.visible = psd_layer.visible
			layer.opacity = psd_layer.opacity / 255.0
			layer.index = layer_index
			layer.set_meta(&"layer_child_level", psd_layer.layer_child_level)
			new_project.layers.append(layer)
			layer_index += 1
			var image := decode_psd_layer(psd_file, psd_layer)
			if is_instance_valid(image) and not image.is_empty():
				image.crop(width, height)
				var img_copy := Image.new()
				img_copy.copy_from(image)
				image.fill(Color(0, 0, 0, 0))
				var offset := Vector2i(psd_layer.left, psd_layer.top)
				image.blit_rect(img_copy, Rect2i(Vector2i.ZERO, image.get_size()), offset)
				prints(image.get_size(), image.get_format())
				var cel := layer.new_cel_from_image(image)
				frame.cels.append(cel)
			else:
				var cel := layer.new_empty_cel()
				frame.cels.append(cel)

	psd_file.close()
	organize_layer_child_levels(new_project)
	new_project.frames.append(frame)
	new_project.order_layers()
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()


static func decode_psd_layer(psd_file: FileAccess, layer: Dictionary) -> Image:
	var img_channels := {}
	for channel in layer.channels:
		psd_file.seek(channel.data_offset)

		var compression := psd_file.get_16()
		var width: int = layer.width
		var height: int = layer.height
		var size: int = width * height

		var raw_data := PackedByteArray()

		if compression == 0:  # Raw Data
			raw_data = psd_file.get_buffer(size)
		elif compression == 1:  # RLE
			var scanline_counts: PackedInt32Array = []
			for i in range(height):
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


static func open_photoshop_file_single_image(path: String) -> void:
	var psd_file := FileAccess.open(path, FileAccess.READ)
	if FileAccess.get_open_error() != OK or psd_file == null:
		return
	psd_file.big_endian = true
	# File header
	var signature := psd_file.get_buffer(4).get_string_from_utf8()
	if signature != "8BPS":
		return
	var version := psd_file.get_16()
	print("version: ", version)
	psd_file.get_buffer(6)  # Reserved
	var n_of_channels := psd_file.get_16()
	var width := psd_file.get_32()
	var height := psd_file.get_32()
	var project_size := Vector2i(width, height)
	var new_project := Project.new([], path.get_file().get_basename(), project_size)
	new_project.fps = 1.0
	var frame := Frame.new()
	prints(width, height)
	var depth := psd_file.get_16()
	# Color Mode Data
	var color_mode := psd_file.get_16()
	var color_data_length := psd_file.get_32()
	print("Color data length: ", color_data_length)
	if color_data_length > 0:
		var color_data := psd_file.get_buffer(color_data_length)
	# Image Resources
	var image_resources_length := psd_file.get_32()
	print("Image resources length: ", image_resources_length)
	if image_resources_length > 0:
		var image_resources := psd_file.get_buffer(image_resources_length)
	# Layer and Mask Information Section
	var layer_and_mask_info_section_length := psd_file.get_32()
	var layer_and_mask_info_section := psd_file.get_buffer(layer_and_mask_info_section_length)
	# Image data
	var compression := psd_file.get_16()
	print("Compression: ", compression)
	# Remaining image data
	var length := psd_file.get_length()
	#print("File Size: ", len)
	var pos := psd_file.get_position()
	#print("Current Position: ", pos)
	var image_data := psd_file.get_buffer(length - pos)

	var image: Image
	if compression == 0:
		var _data: PackedByteArray = []
		var index = 0
		while index < width * height:
			for i in range(4):
				var d := image_data.decode_u8(index + width * height * i)
				_data.append(d)
			index += 1
		image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, _data)

	elif compression == 1:
		# Skip per-row RLE headers (2 bytes per channel per row)
		image_data = image_data.slice(n_of_channels * 2 * height)
		var decoded_data: PackedByteArray = []
		var index := 0
		while index < image_data.size():
			var d := image_data.decode_u8(index)
			if d >= 0x80:  # Run-length encoded
				index += 1
				for i in range(256 - d + 1):
					decoded_data.append(image_data.decode_u8(index))
			else:  # Raw data
				for i in range(d + 1):
					index += 1
					decoded_data.append(image_data.decode_u8(index))
			index += 1
		var data: PackedByteArray = []
		index = 0
		while index < width * height:
			for i in range(n_of_channels):
				var d := decoded_data.decode_u8(index + width * height * i)
				data.append(d)
			index += 1

		if n_of_channels == 3:
			image = Image.create_from_data(width, height, false, Image.FORMAT_RGB8, data)
		elif n_of_channels == 4:
			image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
	psd_file.close()
	var layer := PixelLayer.new(new_project)
	var cel := layer.new_cel_from_image(image)
	frame.cels.append(cel)
	new_project.layers.append(layer)
	new_project.frames.append(frame)
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()
