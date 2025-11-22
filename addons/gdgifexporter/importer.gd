class_name GIFImporter
extends GIFDataTypes


class GifFrame:
	var image: Image
	var delay: float
	var disposal_method: int
	var transparent_color_index := -1
	var x: int
	var y: int
	var w: int
	var h: int


enum Error { OK, FILE_IS_EMPTY, FILE_SMALLER_MINIMUM, NOT_A_SUPPORTED_FILE }

const R: int = 0
const G: int = 1
const B: int = 2

var lzw := preload("./gif-lzw/lzw.gd").new()
## If true, dispose method 2 disposes to transparent color instead of a background color,
## if the gif uses any transparency at all.
var dispose_to_transparent := false

var header: PackedByteArray
var logical_screen_descriptor: PackedByteArray

var import_file: FileAccess
var frames: Array[GifFrame]

var background_color_index: int
var pixel_aspect_ratio: int
var global_color_table: Array[PackedByteArray]
var is_animated: bool = false

var last_graphic_control_extension: GraphicControlExtension = null
var transparency_found := false
var curr_canvas: Image
var previous_canvas: Image


func _init(file: FileAccess):
	import_file = file


func skip_bytes(amount: int) -> void:
	import_file.seek(import_file.get_position() + amount)


func load_header() -> void:
	header = import_file.get_buffer(6)


func get_gif_ver() -> String:
	return header.get_string_from_ascii()


func load_logical_screen_descriptor() -> void:
	logical_screen_descriptor = import_file.get_buffer(7)
	background_color_index = get_background_color_index()


func get_logical_screen_width() -> int:
	return logical_screen_descriptor.decode_s16(0)


func get_logical_screen_height() -> int:
	return logical_screen_descriptor.decode_s16(2)


func get_packed_fields() -> int:
	return logical_screen_descriptor[4]


func has_global_color_table() -> bool:
	return (get_packed_fields() >> 7) == 1


func get_color_resolution() -> int:
	return ((get_packed_fields() >> 4) & 0b0111) + 1


func get_size_of_global_color_table() -> int:
	return int(pow(2, (get_packed_fields() & 0b111) + 1))


func get_background_color_index() -> int:
	return logical_screen_descriptor[5]


func get_pixel_aspect_ratio() -> int:
	return logical_screen_descriptor[6]


func load_global_color_table() -> void:
	global_color_table = []
	global_color_table.resize(get_size_of_global_color_table())
	for i in global_color_table.size():
		var color_bytes := PackedByteArray(
			[import_file.get_8(), import_file.get_8(), import_file.get_8()]
		)
		global_color_table[i] = color_bytes


func load_local_color_table(size: int) -> Array[PackedByteArray]:
	var result: Array[PackedByteArray] = []
	result.resize(size)
	for i in range(size):
		var color_bytes := PackedByteArray(
			[import_file.get_8(), import_file.get_8(), import_file.get_8()]
		)
		result[i] = color_bytes
	return result


func load_data_subblocks() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray([])

	while true:
		var block_size: int = import_file.get_8()
		if block_size == 0:
			break
		result.append_array(import_file.get_buffer(block_size))

	return result


func skip_data_subblocks() -> void:
	while true:
		var block_size: int = import_file.get_8()
		if block_size == 0:
			break
		import_file.seek(import_file.get_position() + block_size)


func load_compressed_image_data() -> PackedByteArray:
	var lzw_min_code_size: int = import_file.get_8()
	var image_data: PackedByteArray = PackedByteArray([])

	# loading data sub-blocks
	image_data = load_data_subblocks()

	var decompressed_image_data: PackedByteArray = lzw.decompress_lzw(lzw_min_code_size, image_data)
	return decompressed_image_data


func indexes_to_rgba(
	encrypted_img_data: PackedByteArray,
	color_table: Array[PackedByteArray],
	transparency_index: int
) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray([])
	result.resize(encrypted_img_data.size() * 4)  # because RGBA format

	for i in range(encrypted_img_data.size()):
		var j: int = 4 * i
		var color_index: int = encrypted_img_data[i]
		result[j] = color_table[color_index][R]
		result[j + 1] = color_table[color_index][G]
		result[j + 2] = color_table[color_index][B]
		# alpha channel
		if color_index == transparency_index:
			result[j + 3] = 0
		else:
			result[j + 3] = 255

	return result


func load_interlaced_image_data(
	color_table: Array, w: int, h: int, transparency_index: int = -1
) -> Image:
	var image_data: PackedByteArray = load_compressed_image_data()
	var deinterlaced_data := deinterlace(image_data, w, h)
	var decrypted_image_data: PackedByteArray = indexes_to_rgba(
		deinterlaced_data, color_table, transparency_index
	)
	var result_image := Image.create_from_data(
		w, h, false, Image.FORMAT_RGBA8, decrypted_image_data
	)
	return result_image


func deinterlace(indexes: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var output := PackedByteArray()
	output.resize(width * height)

	var passes: Array[Dictionary] = [
		{"start": 0, "step": 8},
		{"start": 4, "step": 8},
		{"start": 2, "step": 4},
		{"start": 1, "step": 2},
	]

	var pos := 0
	for p in passes:
		var row: int = p.start
		while row < height:
			var row_start := row * width
			for x in range(width):
				if pos >= indexes.size():
					return output
				output[row_start + x] = indexes[pos]
				pos += 1
			row += p.step
	return output


func load_progressive_image_data(
	color_table: Array, w: int, h: int, transparency_index: int = -1
) -> Image:
	var encrypted_image_data: PackedByteArray = load_compressed_image_data()

	var decrypted_image_data: PackedByteArray = indexes_to_rgba(
		encrypted_image_data, color_table, transparency_index
	)

	var result_image := Image.create_from_data(
		w, h, false, Image.FORMAT_RGBA8, decrypted_image_data
	)

	return result_image


func handle_image_descriptor() -> int:
	var x: int = import_file.get_buffer(2).decode_s16(0)
	var y: int = import_file.get_buffer(2).decode_s16(0)
	var w: int = import_file.get_buffer(2).decode_s16(0)
	var h: int = import_file.get_buffer(2).decode_s16(0)
	var packed_field: int = import_file.get_8()

	var has_local_color_table: bool = (packed_field >> 7) == 1
	var is_interlace_flag_on: bool = ((packed_field >> 6) & 0b01) == 1
	# Skipping sort flag
	# Skipping reserved bits
	var size_of_local_color_table: int = pow(2, (packed_field & 0b111) + 1)
	var local_color_table: Array[PackedByteArray] = []
	var color_table: Array[PackedByteArray]
	if has_local_color_table:
		local_color_table = load_local_color_table(size_of_local_color_table)
		color_table = local_color_table
	else:
		color_table = global_color_table

	var transparent_color_index: int = -1
	var new_frame := GifFrame.new()
	if last_graphic_control_extension != null:
		if last_graphic_control_extension.uses_transparency:
			transparent_color_index = last_graphic_control_extension.transparent_color_index
			transparency_found = true
		new_frame.delay = last_graphic_control_extension.delay_time
		new_frame.disposal_method = last_graphic_control_extension.disposal_method
		last_graphic_control_extension = null
	else:
		# -1 because Image Descriptor didn't have Graphics Control Extension
		# before it with frame delay value, so we want to set it as -1 because we
		# want to tell end user that this frame has no delay.
		new_frame.delay = -1
		new_frame.disposal_method = DisposalMethod.RESTORE_TO_BACKGROUND

	var image: Image
	if is_interlace_flag_on:
		image = load_interlaced_image_data(color_table, w, h, transparent_color_index)
	else:
		image = load_progressive_image_data(color_table, w, h, transparent_color_index)
	if frames.size() > 0:
		var prev_frame := frames[frames.size() - 1]
		if prev_frame.disposal_method == DisposalMethod.RESTORE_TO_BACKGROUND:
			var should_use_transparency := transparency_found and dispose_to_transparent
			if global_color_table.is_empty():
				should_use_transparency = true
			if not should_use_transparency:
				var bg_image := Image.create_empty(w, h, false, image.get_format())
				var r := global_color_table[background_color_index][R]
				var g := global_color_table[background_color_index][G]
				var b := global_color_table[background_color_index][B]
				var a := 255
				if background_color_index == transparent_color_index:
					a = 0
				var background_color := Color.from_rgba8(r, g, b, a)
				bg_image.fill(background_color)
				curr_canvas.fill(Color(0, 0, 0, 0))
				curr_canvas.blit_rect(bg_image, Rect2i(x, y, w, h), Vector2i(x, y))
			else:
				curr_canvas.fill(Color(0, 0, 0, 0))
		elif prev_frame.disposal_method == DisposalMethod.RESTORE_TO_PREVIOUS:
			if is_instance_valid(previous_canvas):
				curr_canvas.copy_from(previous_canvas)
		if new_frame.disposal_method == DisposalMethod.RESTORE_TO_PREVIOUS:
			previous_canvas = Image.new()
			previous_canvas.copy_from(curr_canvas)
		else:
			previous_canvas = null
		curr_canvas.blit_rect_mask(
			image, image, Rect2i(Vector2i.ZERO, curr_canvas.get_size()), Vector2i(x, y)
		)
	else:
		curr_canvas = image
	new_frame.image = Image.new()
	new_frame.image.copy_from(curr_canvas)
	new_frame.transparent_color_index = transparent_color_index
	new_frame.x = x
	new_frame.y = y
	new_frame.w = w
	new_frame.h = h

	frames.append(new_frame)

	return Error.OK


func handle_graphics_control_extension() -> int:
	var block_size: int = import_file.get_8()
	if block_size != 4:
		printerr("Graphics extension block size isn't equal to 4!")
	var packed_fields: int = import_file.get_8()
	var delay_time: int = import_file.get_buffer(2).decode_s16(0)
	var transparent_color_index: int = import_file.get_8()
	var block_terminator: int = import_file.get_8()
	if block_terminator != 0:
		printerr("Block terminator in graphics control extensions should be 0.")

	var graphic_control_extension: GraphicControlExtension = GraphicControlExtension.new()
	graphic_control_extension.set_delay_time_from_export(delay_time)
	graphic_control_extension.set_packed_fields(packed_fields)
	graphic_control_extension.transparent_color_index = transparent_color_index

	last_graphic_control_extension = graphic_control_extension

	return Error.OK


func check_if_is_animation(
	application_identifier: String, appl_authentication_code: String, appl_data: PackedByteArray
) -> void:
	var proper_appl_data: PackedByteArray = PackedByteArray([1, 0, 0])
	if (
		application_identifier == "NETSCAPE"
		and appl_authentication_code == "2.0"
		and appl_data == proper_appl_data
	):
		is_animated = true


func handle_application_extension() -> int:
	var block_size: int = import_file.get_8()
	if block_size != 11:
		printerr("Application extension's block size isn't equal to 11!")
	var application_identifier: String = import_file.get_buffer(8).get_string_from_ascii()
	var appl_authentication_code: String = import_file.get_buffer(3).get_string_from_ascii()
	var appl_data: PackedByteArray = load_data_subblocks()
	check_if_is_animation(application_identifier, appl_authentication_code, appl_data)
	return Error.OK


func handle_comment_extension() -> int:
	skip_data_subblocks()
	return Error.OK


func handle_plain_text_extension() -> int:
	var block_size := import_file.get_8()
	skip_bytes(block_size)
	skip_data_subblocks()
	return Error.OK


func handle_extension_introducer() -> int:
	var label: int = import_file.get_8()
	match label:
		0xF9:  # Graphics Control Extension
			return handle_graphics_control_extension()
		0xFF:  # Application Extension
			return handle_application_extension()
		0xFE:  # Comment Extension
			return handle_comment_extension()
		0x01:  # Plain Text Extension
			return handle_plain_text_extension()
	return Error.OK


func import() -> int:
	# Reset state
	frames = []
	is_animated = false
	global_color_table = []
	last_graphic_control_extension = null

	# File checks
	if import_file.get_length() == 0:
		return Error.FILE_IS_EMPTY
	if import_file.get_length() < 13:
		return Error.FILE_SMALLER_MINIMUM

	# HEADER
	load_header()
	var gif_ver: String = get_gif_ver()
	if gif_ver != "GIF87a" and gif_ver != "GIF89a":
		printerr("Not a supported gif file.")
		return Error.NOT_A_SUPPORTED_FILE

	# LOGICAL SCREEN DESCRIPTOR
	load_logical_screen_descriptor()
	if has_global_color_table():
		load_global_color_table()

	curr_canvas = Image.create_empty(
		get_logical_screen_width(), get_logical_screen_height(), false, Image.FORMAT_RGBA8
	)
	# GifFrame loading loop
	while import_file.get_position() < import_file.get_length():
		if import_file.eof_reached():
			break

		var label: int = import_file.get_8()
		var error: int = Error.OK

		match label:
			0x2C:  # Image Descriptor
				error = handle_image_descriptor()
			0x21:  # Extension Introducer
				error = handle_extension_introducer()
			0x3B:  # Trailer
				break
			_:
				printerr("Unknown block label: ", label)
				error = Error.OK

		if error != Error.OK:
			return error

	return Error.OK
