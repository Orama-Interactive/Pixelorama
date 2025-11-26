class_name GIFDataTypes
extends RefCounted

enum DisposalMethod {
	NO_SPECIFIED = 0, DO_NOT_DISPOSE = 1, RESTORE_TO_BACKGROUND = 2, RESTORE_TO_PREVIOUS = 3
}

const LittleEndian := preload("./little_endian.gd")

const EXTENSION_INTRODUCER: int = 0x21
const GRAPHIC_CONTROL_LABEL: int = 0xf9


class GraphicControlExtension:
	var delay_time: float = 0.0
	var disposal_method: int = DisposalMethod.DO_NOT_DISPOSE
	var uses_transparency: bool = false
	var transparent_color_index: int = 0

	func set_delay_time_from_export(_delay_time: int) -> void:
		delay_time = float(_delay_time) / 100.0

	func set_packed_fields(packed_fields: int) -> void:
		disposal_method = (packed_fields & 0b0001_1100) >> 2
		uses_transparency = true if packed_fields & 1 == 1 else false

	func get_delay_time_for_export() -> int:
		return ceili(delay_time / 0.01)

	func get_packed_fields() -> int:
		var result: int = 1 if uses_transparency else 0
		result = result | (disposal_method << 2)
		return result

	func to_bytes() -> PackedByteArray:
		var little_endian := LittleEndian.new()
		var result: PackedByteArray = PackedByteArray([])
		var block_size: int = 4

		result.append(EXTENSION_INTRODUCER)
		result.append(GRAPHIC_CONTROL_LABEL)

		result.append(block_size)
		result.append(get_packed_fields())
		result += little_endian.int_to_word(get_delay_time_for_export())
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

	func _init(
		_image_left_position: int,
		_image_top_position: int,
		_image_width: int,
		_image_height: int,
		size_of_local_color_table: int
	):
		image_left_position = _image_left_position
		image_top_position = _image_top_position
		image_width = _image_width
		image_height = _image_height
		packed_fields = packed_fields | (0b111 & size_of_local_color_table)

	func to_bytes() -> PackedByteArray:
		var little_endian = LittleEndian.new()
		var result: PackedByteArray = PackedByteArray([])

		result.append(image_separator)
		result += little_endian.int_to_word(image_left_position)
		result += little_endian.int_to_word(image_top_position)
		result += little_endian.int_to_word(image_width)
		result += little_endian.int_to_word(image_height)
		result.append(packed_fields)

		return result


class LocalColorTable:
	var colors: Array = []

	func log2(value: float) -> float:
		return log(value) / log(2.0)

	func get_size() -> int:
		if colors.size() <= 1:
			return 0
		return ceili(log2(colors.size()) - 1)

	func to_bytes() -> PackedByteArray:
		var result: PackedByteArray = PackedByteArray([])

		for v in colors:
			result.append(v[0])
			result.append(v[1])
			result.append(v[2])

		if colors.size() != int(pow(2, get_size() + 1)):
			for i in range(int(pow(2, get_size() + 1)) - colors.size()):
				result += PackedByteArray([0, 0, 0])

		return result


class ApplicationExtension:
	var extension_introducer: int = 0x21
	var extension_label: int = 0xff

	var block_size: int = 11
	var application_identifier: PackedByteArray
	var appl_authentication_code: PackedByteArray

	var application_data: PackedByteArray

	func _init(_application_identifier: String, _appl_authentication_code: String):
		application_identifier = _application_identifier.to_ascii_buffer()
		appl_authentication_code = _appl_authentication_code.to_ascii_buffer()

	func to_bytes() -> PackedByteArray:
		var result: PackedByteArray = PackedByteArray([])

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
	var image_data: PackedByteArray

	func to_bytes() -> PackedByteArray:
		var result: PackedByteArray = PackedByteArray([])
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

		if not image_data.is_empty():
			result.append(0)

		return result
