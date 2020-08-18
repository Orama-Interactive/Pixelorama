extends Reference


var little_endian = preload('./little_endian.gd').new()
var lzw = preload('./gif-lzw/lzw.gd').new()
var used_proc_count: int = 4


class GraphicControlExtension:
	var extension_introducer: int = 0x21
	var graphic_control_label: int = 0xf9

	var block_size: int = 4
	var packed_fields: int = 0b00001000
	var delay_time: int = 0
	var transparent_color_index: int = 0

	func _init(_delay_time: int,
			use_transparency: bool = false,
			_transparent_color_index: int = 0):
		delay_time = _delay_time
		transparent_color_index = _transparent_color_index
		if use_transparency:
			packed_fields = 0b00001001

	func to_bytes() -> PoolByteArray:
		var little_endian = preload('./little_endian.gd').new()
		var result: PoolByteArray = PoolByteArray([])

		result.append(extension_introducer)
		result.append(graphic_control_label)

		result.append(block_size)
		result.append(packed_fields)
		result += little_endian.int_to_2bytes(delay_time)
		result.append(transparent_color_index)

		result.append(0)

		return result

class ImageDescriptor:
	var image_separator: int = 0x2c
	var image_left_position: int = 0
	var image_top_position: int = 0
	var image_width: int
	var image_height: int
	var packed_fields: int = 0b10000000

	func _init(_image_left_position: int,
			_image_top_position: int,
			_image_width: int,
			_image_height: int,
			size_of_local_color_table: int):
		image_left_position = _image_left_position
		image_top_position = _image_top_position
		image_width = _image_width
		image_height = _image_height
		packed_fields = packed_fields | (0b111 & size_of_local_color_table)

	func to_bytes() -> PoolByteArray:
		var little_endian = preload('./little_endian.gd').new()
		var result: PoolByteArray = PoolByteArray([])

		result.append(image_separator)
		result += little_endian.int_to_2bytes(image_left_position)
		result += little_endian.int_to_2bytes(image_top_position)
		result += little_endian.int_to_2bytes(image_width)
		result += little_endian.int_to_2bytes(image_height)
		result.append(packed_fields)

		return result

class LocalColorTable:
	var colors: Array = []

	func log2(value: float) -> float:
		return log(value) / log(2.0)

	func get_size() -> int:
		if colors.size() <= 1:
			return 0
		return int(ceil(log2(colors.size()) - 1))

	func to_bytes() -> PoolByteArray:
		var result: PoolByteArray = PoolByteArray([])

		for v in colors:
			result.append(v[0])
			result.append(v[1])
			result.append(v[2])

		if colors.size() != int(pow(2, get_size() + 1)):
			for i in range(int(pow(2, get_size() + 1)) - colors.size()):
				result += PoolByteArray([0, 0, 0])

		return result

class ApplicationExtension:
	var extension_introducer: int = 0x21
	var extension_label: int = 0xff

	var block_size: int = 11
	var application_identifier: PoolByteArray
	var appl_authentication_code: PoolByteArray

	var application_data: PoolByteArray

	func _init(_application_identifier: String,
			_appl_authentication_code: String):
		application_identifier = _application_identifier.to_ascii()
		appl_authentication_code = _appl_authentication_code.to_ascii()

	func to_bytes() -> PoolByteArray:
		var result: PoolByteArray = PoolByteArray([])

		result.append(extension_introducer)
		result.append(extension_label)
		result.append(block_size)
		result += application_identifier
		result += appl_authentication_code

		result.append(application_data.size())
		result += application_data

		result.append(0)

		return result

class ImageData:
	var lzw_minimum_code_size: int
	var image_data: PoolByteArray

	func to_bytes() -> PoolByteArray:
		var result: PoolByteArray = PoolByteArray([])
		result.append(lzw_minimum_code_size)

		var block_size_index: int = 0
		var i: int = 0
		var data_index: int = 0
		while data_index < image_data.size():
			if i == 0:
				result.append(0)
				block_size_index = result.size() - 1
			result.append(image_data[data_index])
			result[block_size_index] += 1
			data_index += 1
			i += 1
			if i == 254:
				i = 0

		if not image_data.empty():
			result.append(0)

		return result

class ConvertedImage:
	var image_converted_to_codes: PoolByteArray
	var color_table: Array
	var transparency_color_index: int
	var width: int
	var height: int

class ConvertionResult:
	var converted_image: ConvertedImage = ConvertedImage.new()
	var error: int = Error.OK

	func with_error_code(_error: int) -> ConvertionResult:
		error = _error
		return self

class ThreadWriteFrameResult:
	var frame_data: PoolByteArray = PoolByteArray([])
	var error: int = Error.OK

	func with_error_code(_error: int) -> ThreadWriteFrameResult:
		error = _error
		return self

enum Error {
	OK = 0,
	EMPTY_IMAGE = 1,
	BAD_IMAGE_FORMAT = 2
}

# File data and Header
var data: PoolByteArray = 'GIF'.to_ascii() + '89a'.to_ascii()

func _init(_width: int, _height: int):
	# Logical Screen Descriptor
	var width: int = _width
	var height: int = _height
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

	var application_extension: ApplicationExtension = ApplicationExtension.new(
			"NETSCAPE",
			"2.0")
	application_extension.application_data = PoolByteArray([1, 0, 0])
	data += application_extension.to_bytes()

func calc_delay_time(frame_delay: float) -> int:
	return int(ceil(frame_delay / 0.01))

func color_table_to_indexes(colors: Array) -> PoolByteArray:
	var result: PoolByteArray = PoolByteArray([])
	for i in range(colors.size()):
		result.append(i)
	return result

func find_color_table_if_has_less_than_256_colors(image: Image) -> Dictionary:
	image.lock()
	var result: Dictionary = {}
	var image_data: PoolByteArray = image.get_data()

	for i in range(0, image_data.size(), 4):
		var color: Array = [int(image_data[i]), int(image_data[i + 1]), int(image_data[i + 2]), int(image_data[i + 3])]
		if not color in result:
			result[color] = result.size()
		if result.size() > 256:
			break

	image.unlock()
	return result

func change_colors_to_codes(image: Image,
		color_palette: Dictionary,
		transparency_color_index: int) -> PoolByteArray:
	image.lock()
	var image_data: PoolByteArray = image.get_data()
	var result: PoolByteArray = PoolByteArray([])

	for i in range(0, image_data.size(), 4):
		var color: Array = [int(image_data[i]), int(image_data[i + 1]), int(image_data[i + 2]), int(image_data[i + 3])]
		if color in color_palette:
			if color[3] == 0 and transparency_color_index != -1:
				result.append(transparency_color_index)
			else:
				result.append(color_palette[color])
		else:
			result.append(0)
			push_warning('change_colors_to_codes: color not found! [%d, %d, %d, %d]' % color)

	image.unlock()
	return result

func sum_color(color: Array) -> int:
	return color[0] + color[1] + color[2] + color[3]

func find_transparency_color_index(color_table: Dictionary) -> int:
	for color in color_table:
		if sum_color(color) == 0:
			return color_table[color]
	return -1

func find_transparency_color_index_for_quantized_image(color_table: Array) -> int:
	for i in range(color_table.size()):
		if sum_color(color_table[i]) == 0:
			return i
	return -1

func make_sure_color_table_is_at_least_size_4(color_table: Array) -> Array:
	var result := [] + color_table
	if color_table.size() < 4:
		for i in range(4 - color_table.size()):
			result.append([0, 0, 0, 0])
	return result

func convert_image(image: Image, quantizator) -> ConvertionResult:
	var result := ConvertionResult.new()

	# check if image is of good format
	if image.get_format() != Image.FORMAT_RGBA8:
		return result.with_error_code(Error.BAD_IMAGE_FORMAT)

	# check if image isn't empty
	if image.is_empty():
		return result.with_error_code(Error.EMPTY_IMAGE)

	var found_color_table: Dictionary = find_color_table_if_has_less_than_256_colors(
			image)

	var image_converted_to_codes: PoolByteArray
	var transparency_color_index: int = -1
	var color_table: Array
	if found_color_table.size() <= 256: # we don't need to quantize the image.
		# exporter images always try to include transparency because I'm lazy.
		transparency_color_index = find_transparency_color_index(found_color_table)
		if transparency_color_index == -1 and found_color_table.size() <= 255:
			found_color_table[[0, 0, 0, 0]] = found_color_table.size()
			transparency_color_index = found_color_table.size() - 1
		image_converted_to_codes = change_colors_to_codes(
				image, found_color_table, transparency_color_index)
		color_table = make_sure_color_table_is_at_least_size_4(found_color_table.keys())
	else: # we have to quantize the image.
		var quantization_result: Array = quantizator.quantize_and_convert_to_codes(image)
		image_converted_to_codes = quantization_result[0]
		color_table = quantization_result[1]
		# don't find transparency index if the quantization algorithm
		# provides it as third return value
		if quantization_result.size() == 3:
			transparency_color_index = 0 if quantization_result[2] else -1
		else:
			transparency_color_index = find_transparency_color_index_for_quantized_image(quantization_result[1])

	result.converted_image.image_converted_to_codes = image_converted_to_codes
	result.converted_image.color_table = color_table
	result.converted_image.transparency_color_index = transparency_color_index
	result.converted_image.width = image.get_width()
	result.converted_image.height = image.get_height()

	return result.with_error_code(Error.OK)

func write_frame(image: Image, frame_delay: float, quantizator) -> int:
	var converted_image_result := convert_image(image, quantizator)
	if converted_image_result.error != Error.OK:
		return converted_image_result.error

	var converted_image := converted_image_result.converted_image
	return write_frame_from_conv_image(converted_image, frame_delay)

func write_frame_from_conv_image(converted_image: ConvertedImage,
		frame_delay: float) -> int:
	var delay_time := calc_delay_time(frame_delay)

	var color_table_indexes = color_table_to_indexes(converted_image.color_table)
	var compressed_image_result: Array = lzw.compress_lzw(
		converted_image.image_converted_to_codes, color_table_indexes)
	var compressed_image_data: PoolByteArray = compressed_image_result[0]
	var lzw_min_code_size: int = compressed_image_result[1]

	var table_image_data_block: ImageData = ImageData.new()
	table_image_data_block.lzw_minimum_code_size = lzw_min_code_size
	table_image_data_block.image_data = compressed_image_data

	var local_color_table: LocalColorTable = LocalColorTable.new()
	local_color_table.colors = converted_image.color_table

	var image_descriptor: ImageDescriptor = ImageDescriptor.new(0, 0,
			converted_image.width,
			converted_image.height,
			local_color_table.get_size())

	var graphic_control_extension: GraphicControlExtension
	if converted_image.transparency_color_index != -1:
		graphic_control_extension = GraphicControlExtension.new(
				delay_time, true, converted_image.transparency_color_index)
	else:
		graphic_control_extension = GraphicControlExtension.new(
				delay_time, false, 0)

	data += graphic_control_extension.to_bytes()
	data += image_descriptor.to_bytes()
	data += local_color_table.to_bytes()
	data += table_image_data_block.to_bytes()

	return Error.OK

func scale_conv_image(converted_image: ConvertedImage, scale_factor: int) -> ConvertedImage:
	var result = ConvertedImage.new()

	result.image_converted_to_codes = PoolByteArray([])
	result.color_table = converted_image.color_table.duplicate()
	result.transparency_color_index = converted_image.transparency_color_index
	result.width = converted_image.width * scale_factor
	result.height = converted_image.height * scale_factor

	for y in range(converted_image.height):
		var row := PoolByteArray([])
		for x in range(converted_image.width):
			for i in range(scale_factor):
				row.append(converted_image.image_converted_to_codes[(y * converted_image.width) + x])
		for i in range(scale_factor):
			result.image_converted_to_codes += row
		row = PoolByteArray([])

	return result

func export_file_data() -> PoolByteArray:
	return data + PoolByteArray([0x3b])
