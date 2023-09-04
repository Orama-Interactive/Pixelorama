extends RefCounted

enum Error { OK = 0, EMPTY_IMAGE = 1, BAD_IMAGE_FORMAT = 2 }

var little_endian := preload("./little_endian.gd").new()
var lzw := preload("./gif-lzw/lzw.gd").new()
var converter := preload("./converter.gd")

var last_color_table := []
var last_transparency_index := -1

# File data and Header
var data := PackedByteArray([])


func _init(_width: int, _height: int):
	add_header()
	add_logical_screen_descriptor(_width, _height)
	add_application_ext("NETSCAPE", "2.0", [1, 0, 0])


func export_file_data() -> PackedByteArray:
	return data + PackedByteArray([0x3b])


func add_header() -> void:
	data += "GIF".to_ascii_buffer() + "89a".to_ascii_buffer()


func add_logical_screen_descriptor(width: int, height: int) -> void:
	# not Global Color Table Flag
	# Color Resolution = 8 bits
	# Sort Flag = 0, not sorted.
	# Size of Global Color Table set to 0
	# because we'll use only Local Tables
	var packed_fields: int = 0b01110000
	var background_color_index: int = 0
	var pixel_aspect_ratio: int = 0

	data += little_endian.int_to_2bytes(width)
	data += little_endian.int_to_2bytes(height)
	data.append(packed_fields)
	data.append(background_color_index)
	data.append(pixel_aspect_ratio)


func add_application_ext(app_iden: String, app_auth_code: String, _data: Array) -> void:
	var extension_introducer := 0x21
	var extension_label := 0xff

	var block_size := 11

	data.append(extension_introducer)
	data.append(extension_label)
	data.append(block_size)
	data += app_iden.to_ascii_buffer()
	data += app_auth_code.to_ascii_buffer()
	data.append(_data.size())
	data += PackedByteArray(_data)
	data.append(0)


# finds the image color table. Stops if the size gets larger than 256.
func find_color_table(image: Image) -> Dictionary:
	var result: Dictionary = {}
	var image_data: PackedByteArray = image.get_data()

	for i in range(0, image_data.size(), 4):
		var color: Array = [
			int(image_data[i]),
			int(image_data[i + 1]),
			int(image_data[i + 2]),
			int(image_data[i + 3])
		]
		if not color in result:
			result[color] = result.size()
		if result.size() > 256:
			break
	return result


func find_transparency_color_index(color_table: Dictionary) -> int:
	for color in color_table:
		if color[3] == 0:
			return color_table[color]
	return -1


func colors_to_codes(
	img: Image, col_palette: Dictionary, transp_color_index: int
) -> PackedByteArray:
	var image_data: PackedByteArray = img.get_data()
	var result: PackedByteArray = PackedByteArray([])

	for i in range(0, image_data.size(), 4):
		var color: Array = [image_data[i], image_data[i + 1], image_data[i + 2], image_data[i + 3]]

		if color in col_palette:
			if color[3] == 0 and transp_color_index != -1:
				result.append(transp_color_index)
			else:
				result.append(col_palette[color])
		else:
			result.append(0)
			push_warning("colors_to_codes: color not found! [%d, %d, %d, %d]" % color)

	return result


# makes sure that the color table is at least size 4.
func make_proper_size(color_table: Array) -> Array:
	var result := [] + color_table
	if color_table.size() < 4:
		for i in range(4 - color_table.size()):
			result.append([0, 0, 0, 0])
	return result


func calc_delay_time(frame_delay: float) -> int:
	return int(ceili(frame_delay / 0.01))


func color_table_to_indexes(colors: Array) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray([])
	for i in range(colors.size()):
		result.append(i)
	return result


func add_frame(image: Image, frame_delay: float, quantizator: Script) -> int:
	# check if image is of good format
	if image.get_format() != Image.FORMAT_RGBA8:
		return Error.BAD_IMAGE_FORMAT

	# check if image isn't empty
	if image.is_empty():
		return Error.EMPTY_IMAGE

	var found_color_table: Dictionary = find_color_table(image)

	var image_converted_to_codes: PackedByteArray
	var transparency_color_index: int = -1
	var color_table: Array
	if found_color_table.size() <= 256:  # we don't need to quantize the image.
		# try to find transparency color index.
		transparency_color_index = find_transparency_color_index(found_color_table)
		# if didn't find transparency color index but there is at least one
		# place for this color then add it artificially.
		if transparency_color_index == -1 and found_color_table.size() <= 255:
			found_color_table[[0, 0, 0, 0]] = found_color_table.size()
			transparency_color_index = found_color_table.size() - 1
		image_converted_to_codes = colors_to_codes(
			image, found_color_table, transparency_color_index
		)
		color_table = make_proper_size(found_color_table.keys())
	else:  # we have to quantize the image.
		var quantization_result: Array = quantizator.new().quantize(image)
		image_converted_to_codes = quantization_result[0]
		color_table = quantization_result[1]
		# transparency index should always be as the first element of color table.
		transparency_color_index = 0 if quantization_result[2] else -1

	last_color_table = color_table
	last_transparency_index = transparency_color_index

	var delay_time := calc_delay_time(frame_delay)

	var color_table_indexes := color_table_to_indexes(color_table)
	var compressed_image_result: Array = lzw.compress_lzw(
		image_converted_to_codes, color_table_indexes
	)
	var compressed_image_data: PackedByteArray = compressed_image_result[0]
	var lzw_min_code_size: int = compressed_image_result[1]

	add_graphic_constrol_ext(delay_time, transparency_color_index)
	add_image_descriptor(Vector2.ZERO, image.get_size(), color_table_bit_size(color_table))
	add_local_color_table(color_table)
	add_image_data_block(lzw_min_code_size, compressed_image_data)

	return Error.OK


## Adds frame with last color information
func add_frame_with_lci(image: Image, frame_delay: float) -> int:
	# check if image is of good format
	if image.get_format() != Image.FORMAT_RGBA8:
		return Error.BAD_IMAGE_FORMAT

	# check if image isn't empty
	if image.is_empty():
		return Error.EMPTY_IMAGE

	var image_converted_to_codes: PackedByteArray = converter.new().get_similar_indexed_datas(
		image, last_color_table
	)

	var color_table_indexes := color_table_to_indexes(last_color_table)
	var compressed_image_result: Array = lzw.compress_lzw(
		image_converted_to_codes, color_table_indexes
	)
	var compressed_image_data: PackedByteArray = compressed_image_result[0]
	var lzw_min_code_size: int = compressed_image_result[1]

	var delay_time := calc_delay_time(frame_delay)

	add_graphic_constrol_ext(delay_time, last_transparency_index)
	add_image_descriptor(Vector2.ZERO, image.get_size(), color_table_bit_size(last_color_table))
	add_local_color_table(last_color_table)
	add_image_data_block(lzw_min_code_size, compressed_image_data)

	return Error.OK


func add_graphic_constrol_ext(_delay_time: float, tci: int = -1) -> void:
	var extension_introducer: int = 0x21
	var graphic_control_label: int = 0xf9

	var block_size: int = 4
	var packed_fields: int = 0b00001000
	if tci != -1:
		packed_fields = 0b00001001

	var delay_time: int = _delay_time
	var transparent_color_index: int = tci if tci != -1 else 0

	data.append(extension_introducer)
	data.append(graphic_control_label)

	data.append(block_size)
	data.append(packed_fields)
	data += little_endian.int_to_2bytes(delay_time)
	data.append(transparent_color_index)

	data.append(0)


func add_image_descriptor(pos: Vector2, size: Vector2, l_color_table_size: int) -> void:
	var image_separator: int = 0x2c
	var packed_fields: int = 0b10000000 | (0b111 & l_color_table_size)

	data.append(image_separator)
	data += little_endian.int_to_2bytes(int(pos.x))  # left pos
	data += little_endian.int_to_2bytes(int(pos.y))  # top pos
	data += little_endian.int_to_2bytes(int(size.x))  # width
	data += little_endian.int_to_2bytes(int(size.y))  # height
	data.append(packed_fields)


func color_table_bit_size(color_table: Array) -> int:
	if color_table.size() <= 1:
		return 0
	var bit_size := int(ceil(log(color_table.size()) / log(2.0)))
	return bit_size - 1


func add_local_color_table(color_table: Array) -> void:
	for color in color_table:
		data.append(color[0])
		data.append(color[1])
		data.append(color[2])

	var size := color_table_bit_size(color_table)
	var proper_size := int(pow(2, size + 1))

	if color_table.size() != proper_size:
		for i in range(proper_size - color_table.size()):
			data += PackedByteArray([0, 0, 0])


func add_image_data_block(lzw_min_code_size: int, _data: PackedByteArray) -> void:
	data.append(lzw_min_code_size)

	var block_size_index: int = 0
	var i: int = 0
	var data_index: int = 0
	while data_index < _data.size():
		if i == 0:
			data.append(0)
			block_size_index = data.size() - 1
		data.append(_data[data_index])
		data[block_size_index] += 1
		data_index += 1
		i += 1
		if i == 254:
			i = 0

	if not _data.is_empty():
		data.append(0)
