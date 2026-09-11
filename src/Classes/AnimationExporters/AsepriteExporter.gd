class_name AsepriteExporter
extends RefCounted

# Based on:
# https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md
#
# This is the reverse of AsepriteParser.gd:
# AsepriteParser reads the binary structures below
# AsepriteExporter writes them back.

static var chunk_count: int = 0


static func save_aseprite_file(project: Project, path: String) -> Error:
	# https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md#header
	var ase_file := FileAccess.open(path, FileAccess.WRITE)
	if ase_file == null:
		return FileAccess.get_open_error()

	# ASE FILE HEADER  (As used by our AsepriteParser class)
	var file_size_position := ase_file.get_position()
	ase_file.store_32(0)  # File size: Filled in at the end.
	ase_file.store_16(0xA5E0)  # magic number
	ase_file.store_16(project.frames.size())  # frame count
	ase_file.store_16(project.size.x)  # size x
	ase_file.store_16(project.size.y)  # size y

	# Pixelorama normally works in RGBA8. Indexed projects use 8-bit pixels.
	var color_depth := 32
	if project.color_mode == Project.INDEXED_MODE:
		color_depth = 8

	ase_file.store_16(color_depth)
	ase_file.store_32(1)  # project_flags, 1 = Layer opacity has valid value
	ase_file.store_16(0)  # Deprecated speed.
	ase_file.store_32(0)  # Reserved.
	ase_file.store_32(0)  # Reserved.

	# Represents index of transparent color in indexed mode
	ase_file.store_8(0)

	# Ignore 3 bytes (Reserved for future)
	ase_file.store_8(0)
	ase_file.store_8(0)
	ase_file.store_8(0)

	# Number of colors. (check this later)
	if color_depth == 8:
		ase_file.store_16(256)
	else:
		ase_file.store_16(0)

	# Pixel dimensions.
	ase_file.store_8(1)
	ase_file.store_8(1)

	# Grid position.
	ase_file.store_16(Global.grids[0].grid_offset.x)
	ase_file.store_16(Global.grids[0].grid_offset.y)

	# Grid dimensions.
	ase_file.store_16(Global.grids[0].grid_size.x)
	ase_file.store_16(Global.grids[0].grid_size.y)

	# Future/reserved.
	var arr := PackedByteArray([0])
	arr.resize(84)
	ase_file.store_buffer(arr)

	# Ready to write frames
	var layers := get_aseprite_layer_order(project)
	for i: int in project.frames.size():
		_write_frame(ase_file, project, i, color_depth, layers)

	# Setting file size now
	var file_size := ase_file.get_length()
	ase_file.seek(file_size_position)
	ase_file.store_32(file_size)
	ase_file.close()
	return OK


static func get_aseprite_layer_order(project: Project) -> Array[BaseLayer]:
	var arr: Array[BaseLayer] = []
	for layer in project.layers:
		if layer is GroupLayer:
			arr.insert(arr.size() - layer.get_child_count(true), layer)
		else:
			arr.append(layer)
	return arr


static func _write_frame(
	ase_file: FileAccess,
	project: Project,
	frame_index: int,
	color_depth: int,
	ase_layers: Array[BaseLayer]
) -> void:
	var frame: Frame = project.frames[frame_index]

	# NOTE: We don't know the final frame byte count until every chunk
	# has been written, so construct the chunks in memory first.
	var chunks_buffer := StreamPeerBuffer.new()
	chunks_buffer.big_endian = false

	# Header written, start chunk
	chunk_count = 0

	if frame_index == 0:
		# Aseprite currently supports only one project palette
		for i in project.tilesets.size():
			_write_tileset_chunk(chunks_buffer, project.tilesets[i], i, color_depth)
		_write_palette_chunk(chunks_buffer, Palettes.current_palette, color_depth)
		_write_tags_chunk(chunks_buffer, project)
		for tag: AnimationTag in project.animation_tags:
			_write_user_data_chunk(chunks_buffer, AsepriteParser.ChunkTypes.TAGS, tag)

	# Aseprite stores layers globally in each frame's chunk list.
	# The parser attached to this exporter expects that ordering.
	for ase_l_index in ase_layers.size():
		var layer := ase_layers[ase_l_index]
		if not layer is PixelLayer and not layer is GroupLayer and not layer is LayerTileMap:
			continue
		if frame_index == 0:
			_write_layer_chunk(chunks_buffer, project, layer)
			_write_user_data_chunk(chunks_buffer, AsepriteParser.ChunkTypes.LAYER, layer)

		var cel := frame.cels[layer.index]

		if cel != null and not cel is GroupCel:
			var written := _write_cel_chunk(
				chunks_buffer, project, ase_l_index, ase_layers, cel, color_depth
			)
			if written:
				_write_user_data_chunk(chunks_buffer, AsepriteParser.ChunkTypes.CEL, cel)

	# Writing FRAME HEADER. A frame header is 16 bytes
	# https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md#frames
	var output := PackedByteArray()
	output.resize(16)
	var frame_size := chunks_buffer.data_array.size() + 16  # 16 is the header size
	output.encode_u32(0, frame_size)
	output.encode_u16(4, 0xF1FA)  # frame_magic_number
	output.encode_u16(6, chunk_count)  # Old field number of "chunks"
	# Frame duration (in milliseconds)
	var duration_ms := int(frame.get_duration_in_seconds(project.fps) * 1000.0)
	output.encode_u16(8, duration_ms)
	# BYTE[2]   For future (set to zero)
	output.encode_u8(10, 0)
	output.encode_u8(11, 0)
	output.encode_u32(12, chunk_count)

	# Append frame contents.
	output.append_array(chunks_buffer.data_array)
	ase_file.store_buffer(output)


static func _write_layer_chunk(
	buffer: StreamPeerBuffer, project: Project, layer: BaseLayer
) -> void:
	# https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md#layer-chunk-0x2004
	# Chunk contents are built separately so that we can calculate
	# the chunk size before writing its header.

	var data := StreamPeerBuffer.new()
	data.big_endian = false

	var flags := 0
	if layer.visible:
		flags |= 1
	if not layer.locked and layer.visible:
		flags |= 2
	else:
		flags |= 4
	if layer.new_cels_linked:
		flags |= 16
	if layer is GroupLayer and not (layer as GroupLayer).expanded:
		flags |= 32

	var layer_type := 0  # Pixellayer
	if layer is GroupLayer:
		layer_type = 1
	elif layer is LayerTileMap:
		layer_type = 2

	# flags and layer type
	data.put_u16(flags)
	data.put_u16(layer_type)
	# Child level is dealt with in the next chunk.
	data.put_u16(layer.get_hierarchy_depth())
	# Layer width and height
	data.put_u16(project.size.x)
	data.put_u16(project.size.y)

	data.put_u16(_get_aseprite_blend_mode(layer.blend_mode))

	# Opacity.
	data.put_u8(clampi(int(layer.opacity * 255.0), 0, 255))

	# Reserved.
	data.put_data(PackedByteArray([0, 0, 0]))

	# Layer name.
	_write_string(data, layer.name)

	# Tilemap layer has an additional tileset index.
	if layer_type == 2:
		var tileset_index := project.tilesets.find((layer as LayerTileMap).tileset)
		if tileset_index < 0:
			tileset_index = 0
		data.put_u32(tileset_index)

	_write_chunk(buffer, AsepriteParser.ChunkTypes.LAYER, data.data_array)


static func _write_cel_chunk(
	buffer: StreamPeerBuffer,
	project: Project,
	ase_layer_index: int,
	order_layers: Array[BaseLayer],
	cel: BaseCel,
	color_depth: int
) -> bool:
	var data := StreamPeerBuffer.new()
	data.big_endian = false
	data.put_u16(ase_layer_index)  # Store layer index (it is different from Pixelorama convention)
	# Calculate and store offset
	var position := Vector2i.ZERO
	if cel is CelTileMap:
		# NOTE: Aseprite gets offset from the top-right corner of the cropped tilemap
		var used_rect := cel.get_image().get_used_rect()
		var ase_offset = cel.get_pixel_coords(cel.get_cell_position(used_rect.position))
		position = Vector2i(ase_offset)
	data.put_16(position.x)
	data.put_16(position.y)
	# Store opacity
	data.put_u8(clampi(int(cel.opacity * 255.0), 0, 255))
	# Store cel type
	var cel_type: int = 2  # Compressed image
	var is_link_cel := cel.link_set != null
	if is_link_cel and cel.link_set.has("cels"):
		var cels_array: Array = cel.link_set["cels"]
		cels_array.sort()
		if cels_array.size() == 0:
			is_link_cel = false
		if cels_array.size() > 0 and cels_array[0] == cel:
			is_link_cel = false
	if is_link_cel:
		cel_type = 1  # Linked Cel
	elif cel is CelTileMap:
		cel_type = 3  # CelTileMap compressed
	data.put_u16(cel_type)
	# Z-index.
	data.put_16(cel.z_index)
	# Reserved.
	data.put_data(PackedByteArray([0, 0, 0, 0, 0]))
	# Store cel data according to it's type
	match cel_type:
		1:
			var linked_frame := _get_linked_frame_index(project, ase_layer_index, order_layers, cel)
			data.put_u16(linked_frame)
		2:
			var image := cel.get_image()
			if (
				image == null
				or (image.get_used_rect().size == Vector2i.ZERO and cel.link_set == null)
			):
				if color_depth != 8:
					return false
				elif (image as ImageExtended).indices_image.get_data().is_empty():
					return false
			var width := image.get_width()
			var height := image.get_height()
			data.put_u16(width)
			data.put_u16(height)
			var pixel_data := _get_cel_pixel_data(image, color_depth)
			var compressed := pixel_data.compress(FileAccess.COMPRESSION_DEFLATE)
			data.put_data(compressed)
		3:
			var tile_map := cel as CelTileMap
			var image := tile_map.get_image()
			var used_rect := image.get_used_rect()
			if used_rect.size == Vector2i.ZERO:
				return false
			var starting_position := tile_map.get_cell_position(used_rect.position)
			var ending_position := tile_map.get_cell_position(used_rect.end - Vector2i.ONE)
			var size_tiles: Vector2i = (ending_position - starting_position) + Vector2i.ONE
			data.put_u16(size_tiles.x)
			data.put_u16(size_tiles.y)
			data.put_u16(32)  # Bits per tile (at the moment it's always 32-bit per tile)
			data.put_32(0x1FFFFFFF)  # Bitmask for tile ID
			data.put_32(0x80000000)  # Bitmask for X flip
			data.put_32(0x40000000)  # Bitmask for Y flip
			data.put_32(0x20000000)  # Bitmask for diagonal flip (swap X/Y axis)
			data.put_data(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))  # Reserved 10 bytes
			# Store tile IDs and flags.
			var byte_offset := 0
			var tile_data := PackedByteArray()
			# 32 bits per tile = 4 bytes per tile
			tile_data.resize(4 * size_tiles.x * size_tiles.y)
			for y in range(starting_position.y, ending_position.y + 1):
				for x in range(starting_position.x, ending_position.x + 1):
					var cell := tile_map.get_cell_at(Vector2i(x, y))
					var tile_id := cell.index
					var transformed_bit := 0
					if cell.transpose:
						transformed_bit |= 32
					if cell.flip_v:
						transformed_bit |= 64
					if cell.flip_h:
						transformed_bit |= 128
					tile_data.encode_u16(byte_offset, tile_id)
					tile_data.encode_u16(byte_offset + 2, transformed_bit)
					byte_offset += 4
			var tile_data_compressed := tile_data.compress(FileAccess.COMPRESSION_DEFLATE)
			data.put_data(tile_data_compressed)
	_write_chunk(buffer, AsepriteParser.ChunkTypes.CEL, data.data_array)
	return true


static func _write_tags_chunk(buffer: StreamPeerBuffer, project: Project) -> void:
	# https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md#tags-chunk-0x2018
	if project.animation_tags.is_empty():
		return
	var data := StreamPeerBuffer.new()
	data.big_endian = false

	# Number of tags.
	data.put_u16(project.animation_tags.size())
	# Reserved 8 bytes.
	data.put_data(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]))
	# Store tag information
	for tag in project.animation_tags:
		data.put_u16(tag.from - 1)
		data.put_u16(tag.to - 1)
		data.put_u8(project.export_profile.direction)  # currently same for aseprite and Pixelorama.
		data.put_u16(0)  # Repeat count: not used by Pixelorama.
		data.put_data(PackedByteArray([0, 0, 0, 0, 0, 0]))  # Reserved 6 bytes for future.
		data.put_data(PackedByteArray([0, 0, 0]))  # Deprecated RGB values
		data.put_u8(0)  # Extra reserved byte.
		_write_string(data, tag.name)  # Tag name
	_write_chunk(buffer, AsepriteParser.ChunkTypes.TAGS, data.data_array)


static func _write_palette_chunk(buffer: StreamPeerBuffer, palette: Palette, depth: int) -> void:
	# https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md#palette-chunk-0x2019
	var data := StreamPeerBuffer.new()
	data.big_endian = false

	var colors := PackedColorArray()
	var last_color_index := -1

	for i in palette.colors_max:
		var color: Color = Color(0, 0, 0, 0)
		if palette.colors.has(i):
			color = palette.colors[i].color
			last_color_index = colors.size()
		elif depth != 8:  # Ignore empty slots in RGBA mode
			continue
		colors.append(color)
	if depth == 8:
		colors = colors.slice(0, last_color_index + 1)  # trim empty slots in end
		# NOTE: In index mode one additional slot is present in the palette, Aseprite treats it
		# as part of the palette and even includes it in palette exports so we should add it here.
		colors.insert(0, Color.BLACK)
	if colors.is_empty():
		return
	data.put_u32(colors.size())  # Palette Size
	data.put_u32(0)  # Index of the first palette slot
	data.put_u32(colors.size() - 1)  # Last index
	data.put_data(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]))  # Reserved 8 bytes for future.
	for i in colors.size():
		data.put_u16(0)  # color name not used by Pixelorama
		data.put_u8(colors[i].r8)
		data.put_u8(colors[i].g8)
		data.put_u8(colors[i].b8)
		data.put_u8(colors[i].a8)
	_write_chunk(buffer, AsepriteParser.ChunkTypes.PALETTE, data.data_array)


static func _write_tileset_chunk(
	buffer: StreamPeerBuffer, tileset: TileSetCustom, idx: int, color_depth: int
) -> void:
	# https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md#tileset-chunk-0x2023
	var data := StreamPeerBuffer.new()
	data.big_endian = false

	data.put_u32(idx)  # Tileset ID
	var flags := 0
	flags |= 2
	flags |= 4
	flags |= 8
	flags |= 16
	flags |= 32
	data.put_u32(flags)  # Tileset flags
	data.put_u32(tileset.tiles.size())
	data.put_u16(tileset.tile_size.x)
	data.put_u16(tileset.tile_size.y)
	data.put_16(1)  # Default base index
	data.put_data(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))  # Reserved 14 bytes.
	_write_string(data, tileset.name)

	var image: Image = tileset.create_image_atlas(tileset.tiles.size(), false, false)
	if color_depth == 8:
		var index_image := ImageExtended.new()
		index_image.copy_from_custom(image, true)
		image = index_image.indices_image
	var compressed := image.get_data().compress(FileAccess.COMPRESSION_DEFLATE)
	data.put_u32(compressed.size())
	data.put_data(compressed)
	_write_chunk(buffer, AsepriteParser.ChunkTypes.TILESET, data.data_array)


static func _write_user_data_chunk(
	buffer: StreamPeerBuffer, previous_type: AsepriteParser.ChunkTypes, object: RefCounted
) -> void:
	var data := StreamPeerBuffer.new()
	data.big_endian = false

	var flags := 0
	# has text
	if object.get("user_data") and object.get("user_data") != "":
		flags |= 1
	# has color
	if (
		previous_type == AsepriteParser.ChunkTypes.LAYER
		or previous_type == AsepriteParser.ChunkTypes.CEL
		or previous_type == AsepriteParser.ChunkTypes.TAGS
	):
		flags |= 2

	data.put_u32(flags)

	if flags & 1:
		_write_string(data, object.get("user_data"))

	if flags & 2:
		var color := Color.WHITE
		if object is BaseLayer or object is BaseCel:
			color = object.ui_color
		elif object is AnimationTag:
			color = (object as AnimationTag).color
		data.put_u8(color.r8)
		data.put_u8(color.g8)
		data.put_u8(color.b8)
		data.put_u8(color.a8)

	_write_chunk(buffer, AsepriteParser.ChunkTypes.USER_DATA, data.data_array)


## Helper functions


## Common ending of chunk.
static func _write_chunk(buffer: StreamPeerBuffer, chunk_type: int, data: PackedByteArray) -> void:
	# DWORD size (4 is u32 and 2 is u16, so 4 + 2 = 6 bytes extra in addition to data)
	buffer.put_u32(data.size() + 6)
	buffer.put_u16(chunk_type)  # WORD type
	buffer.put_data(data)  # data
	prints("Exported Chunk:", AsepriteParser.ChunkTypes.find_key(chunk_type))
	chunk_count += 1


## procedure to add a string. better to do it separately. in case we need it again.
static func _write_string(buffer: StreamPeerBuffer, text: String) -> void:
	var bytes := text.to_utf8_buffer()
	buffer.put_u16(bytes.size())
	buffer.put_data(bytes)


## Auto calculates and returns the image data for both index and rgba mode.
static func _get_cel_pixel_data(image: Image, color_depth: int) -> PackedByteArray:
	if color_depth == 8 and image is ImageExtended:  # Indexed
		# Pixelorama's indexed image representation. indices_image is an Image with an
		# OpenGL texture format RED with a single component and a bitdepth of 8.
		var indices_image: Image = image.indices_image
		if not indices_image.get_format() == Image.FORMAT_R8:  # Failsafe
			indices_image.convert(Image.FORMAT_R8)
		return image.indices_image.get_data()
	return image.get_data()


static func _get_linked_frame_index(
	project: Project, layer_index: int, order_layers: Array[BaseLayer], cel: BaseCel
) -> int:
	for frame_index in project.frames.size():
		var frame := project.frames[frame_index]
		if layer_index >= frame.cels.size():
			continue
		if frame.cels[order_layers[layer_index].index] in cel.link_set:
			return frame_index
	return 0


static func _get_aseprite_blend_mode(blend_mode: BaseLayer.BlendModes) -> int:
	match blend_mode:
		BaseLayer.BlendModes.MULTIPLY:
			return AsepriteParser.AsepriteBlendMode.MULTIPLY

		BaseLayer.BlendModes.SCREEN:
			return AsepriteParser.AsepriteBlendMode.SCREEN

		BaseLayer.BlendModes.OVERLAY:
			return AsepriteParser.AsepriteBlendMode.OVERLAY

		BaseLayer.BlendModes.DARKEN:
			return AsepriteParser.AsepriteBlendMode.DARKEN

		BaseLayer.BlendModes.LIGHTEN:
			return AsepriteParser.AsepriteBlendMode.LIGHTEN

		BaseLayer.BlendModes.COLOR_DODGE:
			return AsepriteParser.AsepriteBlendMode.COLOR_DODGE

		BaseLayer.BlendModes.COLOR_BURN:
			return AsepriteParser.AsepriteBlendMode.COLOR_BURN

		BaseLayer.BlendModes.HARD_LIGHT:
			return AsepriteParser.AsepriteBlendMode.HARD_LIGHT

		BaseLayer.BlendModes.SOFT_LIGHT:
			return AsepriteParser.AsepriteBlendMode.SOFT_LIGHT

		BaseLayer.BlendModes.DIFFERENCE:
			return AsepriteParser.AsepriteBlendMode.DIFFERENCE

		BaseLayer.BlendModes.EXCLUSION:
			return AsepriteParser.AsepriteBlendMode.EXCLUSION

		BaseLayer.BlendModes.HUE:
			return AsepriteParser.AsepriteBlendMode.HUE

		BaseLayer.BlendModes.SATURATION:
			return AsepriteParser.AsepriteBlendMode.SATURATION

		BaseLayer.BlendModes.COLOR:
			return AsepriteParser.AsepriteBlendMode.COLOR

		BaseLayer.BlendModes.LUMINOSITY:
			return AsepriteParser.AsepriteBlendMode.LUMINOSITY

		BaseLayer.BlendModes.ADD:
			return AsepriteParser.AsepriteBlendMode.ADD

		BaseLayer.BlendModes.SUBTRACT:
			return AsepriteParser.AsepriteBlendMode.SUBTRACT

		BaseLayer.BlendModes.DIVIDE:
			return AsepriteParser.AsepriteBlendMode.DIVIDE
		_:
			return AsepriteParser.AsepriteBlendMode.NORMAL
