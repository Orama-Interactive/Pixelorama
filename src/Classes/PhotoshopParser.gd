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
	# Layer info
	var layer_info_length := psd_file.get_32()
	var layer_count := psd_file.get_16()
	print("Layer count: ", layer_count)
	var layers_channels: Array[int] = []
	layers_channels.resize(layer_count)
	var layer_rectangles: Array[PackedByteArray] = []
	layer_rectangles.resize(layer_count)
	# Layer records
	for i in layer_count:
		var layer_rectangle := psd_file.get_buffer(16)
		layer_rectangles[i] = layer_rectangle
		var layer_channels := psd_file.get_16()
		layers_channels[i] = layer_channels
		var channel_information := psd_file.get_buffer(6 * layer_channels)
		var blend_mode_signature := psd_file.get_buffer(4).get_string_from_utf8()
		if blend_mode_signature != "8BIM":
			return
		var blend_mode_key := psd_file.get_buffer(4).get_string_from_utf8()
		var opacity := psd_file.get_8()
		var clipping := psd_file.get_8()
		var flags := psd_file.get_8()
		var _filler := psd_file.get_8()
		var extra_data_field_length := psd_file.get_32()
		var _all_extra_data_fields := psd_file.get_buffer(extra_data_field_length)
		#print("length: ", extra_data_field_length)
		# Layer mask / adjustment layer data
		#var layer_mask_data_size := psd_file.get_32()
		#if layer_mask_data_size != 0:
			#var layer_mask_rectangle := psd_file.get_buffer(16)
			#var layer_mask_default_color := psd_file.get_8()
			#var layer_mask_flags := psd_file.get_8()
			#if layer_mask_flags & 4 == 4:
				#var layer_mask_parameters := psd_file.get_8()
				#if layer_mask_parameters & 0 == 0:
					#var user_mask_density := psd_file.get_8()
				#if layer_mask_parameters & 1 == 1:
					#var user_mask_feather := psd_file.get_buffer(8)
				#if layer_mask_parameters & 2 == 2:
					#var vector_mask_density := psd_file.get_8()
				#if layer_mask_parameters & 3 == 3:
					#var vector_mask_feather := psd_file.get_buffer(8)
			#if layer_mask_data_size == 20:
				#var padding := psd_file.get_16()
			#else:
				#var real_flags := psd_file.get_8()
				#var real_mask_bg := psd_file.get_8()
				#var layer_mask_rectangle_2 := psd_file.get_buffer(16)
		## Layer blending ranges data
		#var layer_blending_ranged_data_length := psd_file.get_32()
		#var composite_gray_blend_source := psd_file.get_32()
		#var composite_gray_blend_destination_range := psd_file.get_32()
		#for j in n_of_channels:
			#var channel_source_range := psd_file.get_32()
			#var channel_destination_range := psd_file.get_32()
	# Channel image data
	for i in layer_count:
		var image := read_channel_image_data(psd_file, layers_channels[i], layer_rectangles[i])
		if is_instance_valid(image):
			var layer := PixelLayer.new(new_project)
			var cel := layer.new_cel_from_image(image)
			frame.cels.append(cel)
			new_project.layers.append(layer)
	#var layer_and_mask_info_section := psd_file.get_buffer(layer_and_mask_info_section_length - 6-16)
	#prints(layer_info, layer_count)
	psd_file.close()

	new_project.frames.append(frame)
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()


static func read_channel_image_data(psd_file: FileAccess, n_of_channels: int, layer_rectangle: PackedByteArray) -> Image:
	var top_buffer := layer_rectangle.slice(0, 4)
	var left_buffer := layer_rectangle.slice(4, 8)
	var bottom_buffer := layer_rectangle.slice(8, 12)
	var right_buffer := layer_rectangle.slice(12, 16)
	top_buffer.reverse()
	left_buffer.reverse()
	bottom_buffer.reverse()
	right_buffer.reverse()
	var top := top_buffer.decode_u32(0)
	var left := left_buffer.decode_u32(0)
	var bottom := bottom_buffer.decode_u32(0)
	var right := right_buffer.decode_u32(0)
	var width := right - left
	var height := bottom - top
	var compression := psd_file.get_16()
	prints(compression, n_of_channels, layer_rectangle, top, left, bottom, right, height)

	var _image: Image
	if compression == 0:
		var byte_size := n_of_channels * height * width
		var image_data := psd_file.get_buffer(byte_size)
		var _data: PackedByteArray = []
		# Raw data is stored by channel: [RRR...][GGG...][BBB...][AAA...]
		for y in range(height):
			for x in range(width):
				var pixel_index := y * width + x
				for c in range(n_of_channels):
					var byte_index := c * width * height + pixel_index
					if byte_index >= image_data.size():
						push_error("byte_index out of bounds: %d / %d" % [byte_index, image_data.size()])
						break
					_data.append(image_data.decode_u8(byte_index))

		# Pick correct format based on channel count
		if n_of_channels == 3:
			_image = Image.create_from_data(width, height, false, Image.FORMAT_RGB8, _data)
		elif n_of_channels == 4:
			_image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, _data)

	elif compression == 1:
		# Step 1: Read RLE line byte counts
		var rle_line_counts: PackedInt32Array
		for c in n_of_channels:
			for y in height:
				var count_bytes := psd_file.get_buffer(2)
				count_bytes.reverse()
				var count := count_bytes.decode_u16(0)
				rle_line_counts.append(count)

		# Step 2: Sum total data size
		var total_rle_data_size := 0
		for count in rle_line_counts:
			total_rle_data_size += count

		# Step 3: Read actual image data
		var image_data := psd_file.get_buffer(total_rle_data_size)
		var decoded_data: PackedByteArray = []
		var index := 0
		while index < image_data.size():
			var _d := image_data.decode_u8(index)
			if _d >= 0x80:  # Run-length encoded
				index += 1
				for i in range(256 - _d + 1):
					decoded_data.append(image_data.decode_u8(index))
			else:  # Raw data
				for i in range(_d + 1):
					index += 1
					decoded_data.append(image_data.decode_u8(index))
			index += 1
		var _data: PackedByteArray = []
		index = 0
		while index < width * height:
			for i in range(n_of_channels):
				var byte_offset := index + width * height * i
				if byte_offset <= decoded_data.size():
					var _d := decoded_data.decode_u8(byte_offset)
					_data.append(_d)
			index += 1

		if n_of_channels == 3:
			_image = Image.create_from_data(width, height, false, Image.FORMAT_RGB8, _data)
		elif n_of_channels == 4:
			_image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, _data)

	return _image


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
	var len := psd_file.get_length()
	#print("File Size: ", len)
	var pos := psd_file.get_position()
	#print("Current Position: ", pos)
	var image_data := psd_file.get_buffer(len - pos)

	var _image: Image
	if compression == 0:
		var _data:PackedByteArray = []
		var index = 0
		while index < width * height:
			for i in range(4):
				var _d = image_data.decode_u8(index + width * height * i)
				_data.append(_d)
			index += 1
		_image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, _data)

	elif compression == 1:
		# Skip per-row RLE headers (2 bytes per channel per row)
		image_data = image_data.slice(n_of_channels * 2 * height)
		var decoded_data:PackedByteArray = []
		var index := 0
		while index < image_data.size():
			var _d := image_data.decode_u8(index)
			if _d >= 0x80:  # Run-length encoded
				index += 1
				for i in range(256 - _d + 1):
					decoded_data.append(image_data.decode_u8(index))
			else:  # Raw data
				for i in range(_d + 1):
					index += 1
					decoded_data.append(image_data.decode_u8(index))
			index += 1
		var _data: PackedByteArray = []
		index = 0
		while index < width * height:
			for i in range(n_of_channels):
				var _d := decoded_data.decode_u8(index + width * height * i)
				_data.append(_d)
			index += 1

		if n_of_channels == 3:
			_image = Image.create_from_data(width, height, false, Image.FORMAT_RGB8, _data)
		elif n_of_channels == 4:
			_image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, _data)
	psd_file.close()
	var layer := PixelLayer.new(new_project)
	var cel := layer.new_cel_from_image(_image)
	frame.cels.append(cel)
	new_project.layers.append(layer)
	new_project.frames.append(frame)
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()
