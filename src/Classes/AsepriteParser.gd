class_name AsepriteParser
extends RefCounted

# Based on https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md

enum ChunkTypes {
	OLD_PALETTE_1 = 0x0004,
	OLD_PALETTE_2 = 0x0011,
	LAYER = 0x2004,
	CEL = 0x2005,
	CEL_EXTRA = 0x2006,
	COLOR_PROFILE = 0x2007,
	EXTERNAL_FILES = 0x2008,
	MASK = 0x2016,
	PATH = 0x2017,
	TAGS = 0x2018,
	PALETTE = 0x2019,
	USER_DATA = 0x2020,
	SLICE = 0x2022,
	TILESET = 0x2023,
}

enum AsepriteBlendMode {
	NORMAL,
	MULTIPLY,
	SCREEN,
	OVERLAY,
	DARKEN,
	LIGHTEN,
	COLOR_DODGE,
	COLOR_BURN,
	HARD_LIGHT,
	SOFT_LIGHT,
	DIFFERENCE,
	EXCLUSION,
	HUE,
	SATURATION,
	COLOR,
	LUMINOSITY,
	ADD,
	SUBTRACT,
	DIVIDE
}

## The size in bytes of the cel chunks, without the image or tilemap data.
const BASE_CEL_CHUNK_SIZE := 22
const IMAGE_CEL_CHUNK_SIZE := BASE_CEL_CHUNK_SIZE + 4
const TILEMAP_CEL_CHUNK_SIZE := BASE_CEL_CHUNK_SIZE + 32


# gdlint: disable=function-variable-name
static func open_aseprite_file(path: String) -> void:
	var ase_file := FileAccess.open(path, FileAccess.READ)
	if FileAccess.get_open_error() != OK or ase_file == null:
		return
	var _file_size := ase_file.get_32()
	var magic_number := ase_file.get_16()
	if magic_number != 0xA5E0:
		return
	var frames := ase_file.get_16()
	var project_width := ase_file.get_16()
	var project_height := ase_file.get_16()
	var project_size := Vector2i(project_width, project_height)
	var new_project := Project.new([], path.get_file().get_basename(), project_size)
	new_project.fps = 1.0
	var color_depth := ase_file.get_16()
	var image_format := Image.FORMAT_RGBA8
	var pixel_byte := 4
	if color_depth == 16:
		image_format = Image.FORMAT_LA8
		pixel_byte = 2
	elif color_depth == 8:
		pixel_byte = 1
		new_project.color_mode = Project.INDEXED_MODE
	var project_flags := ase_file.get_32()
	var _project_speed := ase_file.get_16()  # Deprecated
	ase_file.get_32()
	ase_file.get_32()
	var palette_entry_index := ase_file.get_8()  # Represents transparent color in indexed mode
	ase_file.get_buffer(3)  # To ignore
	var number_of_colors := ase_file.get_16()
	var _pixel_width := ase_file.get_8()
	var _pixel_height := ase_file.get_8()
	var _grid_position_x := ase_file.get_16()
	var _grid_position_y := ase_file.get_16()
	var _grid_width := ase_file.get_16()
	var _grid_height := ase_file.get_16()
	ase_file.get_buffer(84)  # For future

	for i in frames:
		var _frame_bytes := ase_file.get_32()
		var frame_magic_number := ase_file.get_16()
		if frame_magic_number != 0xF1FA:
			printerr("Error in frame %s" % i)
			continue
		var frame := Frame.new()
		var number_of_chunks := ase_file.get_16()
		var frame_dur := ase_file.get_16()
		frame.set_duration_in_seconds(frame_dur * 0.001, new_project.fps)
		ase_file.get_buffer(2)  # For future
		var new_number_of_chunks := ase_file.get_32()
		if new_number_of_chunks != 0:
			number_of_chunks = new_number_of_chunks
		var previous_chunk_type := 0
		var current_frame_tag := -1
		for j in number_of_chunks:
			var chunk_size := ase_file.get_32()
			var chunk_type := ase_file.get_16()
			if chunk_type != 0x2020:
				previous_chunk_type = chunk_type
			match chunk_type:
				ChunkTypes.OLD_PALETTE_1, ChunkTypes.OLD_PALETTE_2:
					var n_of_packets := ase_file.get_16()
					for packet in n_of_packets:
						var _n_entries_skip := ase_file.get_8()
						var _n_of_colors := ase_file.get_8()
						for color in number_of_colors:
							var _red := ase_file.get_8()
							var _green := ase_file.get_8()
							var _blue := ase_file.get_8()
				ChunkTypes.LAYER:
					var layer_flags := ase_file.get_16()
					var layer_type := ase_file.get_16()
					var layer_child_level := ase_file.get_16()
					var _layer_width := ase_file.get_16()  # ignored
					var _layer_height := ase_file.get_16()  # ignored
					var layer_blend_mode := ase_file.get_16()
					var layer_opacity := 1.0
					if project_flags & 1 == 1:
						layer_opacity = ase_file.get_8() / 255.0
					ase_file.get_buffer(3)  # For future
					var layer_name := parse_aseprite_string(ase_file)
					var layer: BaseLayer
					if layer_type == 0:
						layer = PixelLayer.new(new_project, layer_name)
						layer.blend_mode = match_blend_modes(layer_blend_mode)
						layer.opacity = layer_opacity
					elif layer_type == 1:
						layer = GroupLayer.new(new_project, layer_name)
						layer.expanded = layer_flags & 32 != 32
					elif layer_type == 2:
						var tileset_index := ase_file.get_32()
						var tileset := new_project.tilesets[tileset_index]
						layer = LayerTileMap.new(new_project, tileset, layer_name)
						layer.blend_mode = match_blend_modes(layer_blend_mode)
						layer.opacity = layer_opacity
					layer.visible = layer_flags & 1 == 1
					layer.locked = layer_flags & 2 != 2
					layer.new_cels_linked = layer_flags & 16 == 16
					layer.index = new_project.layers.size()
					new_project.layers.append(layer)
					layer.set_meta(&"layer_child_level", layer_child_level)
				ChunkTypes.CEL:
					var layer_index := ase_file.get_16()
					var layer := new_project.layers[layer_index]
					var cel := layer.new_empty_cel()
					var x_pos := ase_file.get_16()
					var y_pos := ase_file.get_16()
					cel.opacity = ase_file.get_8() / 255.0
					var cel_type := ase_file.get_16()
					cel.z_index = ase_file.get_16()
					ase_file.get_buffer(5)  # For future
					if cel_type == 0 or cel_type == 2:  # Raw uncompressed and compressed image
						var width := ase_file.get_16()
						var height := ase_file.get_16()
						var image_rect := Rect2i(Vector2i.ZERO, Vector2i(width, height))
						var color_bytes := ase_file.get_buffer(chunk_size - IMAGE_CEL_CHUNK_SIZE)
						if cel_type == 2:  # Compressed image
							color_bytes = color_bytes.decompress(
								width * height * pixel_byte, FileAccess.COMPRESSION_DEFLATE
							)
						if color_depth > 8:
							var ase_cel_image := Image.create_from_data(
								width, height, false, image_format, color_bytes
							)
							ase_cel_image.convert(new_project.get_image_format())
							cel.get_image().blit_rect(
								ase_cel_image, image_rect, Vector2i(x_pos, y_pos)
							)
						else:  # Indexed mode
							for k in color_bytes.size():
								color_bytes[k] += 1
								if color_bytes[k] == palette_entry_index + 1:
									color_bytes[k] = 0
							var ase_cel_image := Image.create_from_data(
								width, height, false, Image.FORMAT_R8, color_bytes
							)
							cel.get_image().indices_image.blit_rect(
								ase_cel_image, image_rect, Vector2i(x_pos, y_pos)
							)
							cel.get_image().convert_indexed_to_rgb()
					elif cel_type == 1:  # Linked cel
						var frame_position_to_link_with := ase_file.get_16()
						var cel_to_link := (
							new_project.frames[frame_position_to_link_with].cels[layer_index]
						)
						var link_set = cel_to_link.link_set
						if link_set == null:
							link_set = {}
							layer.link_cel(cel_to_link, link_set)
						layer.link_cel(cel, link_set)
						cel.set_content(cel_to_link.get_content(), cel_to_link.image_texture)
					elif cel_type == 3:  # Compressed tilemap
						var width := ase_file.get_16()
						var height := ase_file.get_16()
						var bits_per_tile := ase_file.get_16()
						var _tile_id_bitmask := ase_file.get_32()
						var _x_flip_bitmask := ase_file.get_32()
						var _y_flip_bitmask := ase_file.get_32()
						var _diagonal_flip_bitmask := ase_file.get_32()
						ase_file.get_buffer(10)  # Reserved
						var tilemap_cel := cel as CelTileMap
						var tileset := tilemap_cel.tileset
						@warning_ignore("integer_division")
						var bytes_per_tile := bits_per_tile / 8
						var tile_data_compressed := ase_file.get_buffer(
							chunk_size - TILEMAP_CEL_CHUNK_SIZE
						)
						var tile_data_size := (
							width * height * tileset.tile_size.x * tileset.tile_size.y * pixel_byte
						)
						var tile_data := tile_data_compressed.decompress(
							tile_data_size, FileAccess.COMPRESSION_DEFLATE
						)
						tilemap_cel.offset = Vector2(x_pos, y_pos)
						for y in height:
							for x in width:
								var cell_pos := x + (y * width)
								var cell_index := tile_data[cell_pos * bytes_per_tile]
								var transformed_bit := 0
								if bits_per_tile == 32:
									transformed_bit = tile_data[cell_pos * bytes_per_tile + 3]
								var cell := tilemap_cel.get_cell_at(Vector2i(x, y))
								var flip_h := transformed_bit & 128 == 128
								var flip_v := transformed_bit & 64 == 64
								var transpose := transformed_bit & 32 == 32
								tilemap_cel.set_index(cell, cell_index, flip_h, flip_v, transpose)

					# Add in-between GroupCels, if there are any.
					# This is needed because Aseprite's group cels do not store any data
					# in Aseprite files, so we need to make our own.
					while layer_index > frame.cels.size():
						var group_layer := new_project.layers[frame.cels.size()]
						var group_cel := group_layer.new_empty_cel()
						frame.cels.append(group_cel)
					frame.cels.append(cel)
				ChunkTypes.CEL_EXTRA:
					var _flags := ase_file.get_32()
					var _x_position := ase_file.get_float()
					var _y_position := ase_file.get_float()
					var _cel_width := ase_file.get_float()
					var _cel_height := ase_file.get_float()
					ase_file.get_buffer(16)  # For future
				ChunkTypes.COLOR_PROFILE:  # TODO: Do we need this?
					var type := ase_file.get_16()
					var _flags := ase_file.get_16()
					var _fixed_gamma := ase_file.get_float()
					ase_file.get_buffer(8)  # For future
					if type == 2:  # ICC
						var icc_profile_data_length := ase_file.get_32()
						ase_file.get_buffer(icc_profile_data_length)
				ChunkTypes.EXTERNAL_FILES:
					var n_of_entries := ase_file.get_32()
					ase_file.get_buffer(8)  # Reserved
					for k in n_of_entries:
						var _entry_id := ase_file.get_32()
						var _entry_type := ase_file.get_8()
						ase_file.get_buffer(7)  # Reserved
						var _external_file_name := parse_aseprite_string(ase_file)
				ChunkTypes.MASK:
					var _position_x := ase_file.get_16()
					var _position_y := ase_file.get_16()
					var mask_width := ase_file.get_16()
					var mask_height := ase_file.get_16()
					ase_file.get_buffer(8)  # For future
					var _mask_name := parse_aseprite_string(ase_file)
					# Read image data
					@warning_ignore("integer_division")
					var byte_data_size := mask_height * ((mask_width + 7) / 8)
					for k in byte_data_size:
						ase_file.get_8()
				ChunkTypes.PATH:  # Never used
					pass
				ChunkTypes.TAGS:
					var n_of_tags := ase_file.get_16()
					ase_file.get_buffer(8)  # For future
					for k in n_of_tags:
						var from_frame := ase_file.get_16()
						var to_frame := ase_file.get_16()
						var _animation_dir := ase_file.get_8()  # Currently not used in Pixelorama
						var _repeat := ase_file.get_16()  # Currently not used in Pixelorama
						ase_file.get_buffer(6)  # For future
						ase_file.get_buffer(3)  # Deprecated RGB values
						ase_file.get_8()  # Extra byte (zero)
						var text := parse_aseprite_string(ase_file)
						var tag := AnimationTag.new(text, Color.WHITE, from_frame + 1, to_frame + 1)
						new_project.animation_tags.append(tag)
				ChunkTypes.PALETTE:
					# TODO: Import palettes into Pixelorama once we support project palettes
					var _palette_size := ase_file.get_32()
					var first_index_to_change := ase_file.get_32()
					var last_index_to_change := ase_file.get_32()
					ase_file.get_buffer(8)  # For future
					for k in range(first_index_to_change, last_index_to_change + 1):
						var flags := ase_file.get_16()
						var _red := ase_file.get_8()
						var _green := ase_file.get_8()
						var _blue := ase_file.get_8()
						var _alpha := ase_file.get_8()
						if flags & 1 == 1:
							var _name := parse_aseprite_string(ase_file)
				ChunkTypes.USER_DATA:
					var flags := ase_file.get_32()
					if previous_chunk_type == ChunkTypes.TAGS:
						current_frame_tag += 1
					if flags & 1 == 1:
						var text := parse_aseprite_string(ase_file)
						if (
							previous_chunk_type == ChunkTypes.OLD_PALETTE_1
							or previous_chunk_type == ChunkTypes.OLD_PALETTE_2
							or previous_chunk_type == ChunkTypes.PALETTE
						):
							new_project.user_data = text
						elif previous_chunk_type == ChunkTypes.CEL:
							frame.cels[-1].user_data = text
						elif previous_chunk_type == ChunkTypes.LAYER:
							new_project.layers[-1].user_data = text
						elif previous_chunk_type == ChunkTypes.TAGS:
							new_project.animation_tags[current_frame_tag].user_data = text
					if flags & 2 == 2:
						var red := ase_file.get_8()
						var green := ase_file.get_8()
						var blue := ase_file.get_8()
						var alpha := ase_file.get_8()
						if previous_chunk_type == ChunkTypes.LAYER:
							new_project.layers[-1].ui_color = Color.from_rgba8(
								red, green, blue, alpha
							)
						elif previous_chunk_type == ChunkTypes.TAGS:
							new_project.animation_tags[current_frame_tag].color = Color.from_rgba8(
								red, green, blue, alpha
							)
					if flags & 4 == 4:
						var _properties_map_size := ase_file.get_32()
						var n_of_properties_maps := ase_file.get_32()
						for k in n_of_properties_maps:
							var _properties_maps_key := ase_file.get_32()
							var n_of_properties := ase_file.get_32()
							for l in n_of_properties:
								var _property_name := parse_aseprite_string(ase_file)
								var property_type := ase_file.get_16()
								var _property = parse_aseprite_variant(ase_file, property_type)
				ChunkTypes.SLICE:
					var slice_keys := ase_file.get_32()
					var slice_flags := ase_file.get_32()
					ase_file.get_32()  # Reserved
					var _slice_name := parse_aseprite_string(ase_file)
					for k in slice_keys:
						# This slice is valid from this frame to the end of the animation
						var _frame_number := ase_file.get_32()
						var _slice_origin_x := ase_file.get_32()
						var _slice_origin_y := ase_file.get_32()
						var _slice_width := ase_file.get_32()
						var _slice_height := ase_file.get_32()
						if slice_flags & 1 == 1:
							var _center_position_x := ase_file.get_32()
							var _center_position_y := ase_file.get_32()
							var _center_width := ase_file.get_32()
							var _center_height := ase_file.get_32()
						if slice_flags & 2 == 2:
							var _pivot_position_x := ase_file.get_32()
							var _pivot_position_y := ase_file.get_32()
				ChunkTypes.TILESET:  # Tileset Chunk
					var _tileset_id := ase_file.get_32()
					var tileset_flags := ase_file.get_32()
					var n_of_tiles := ase_file.get_32()
					var tile_width := ase_file.get_16()
					var tile_height := ase_file.get_16()
					var _base_index := ase_file.get_16()
					ase_file.get_buffer(14)  # Reserved
					var tileset_name := parse_aseprite_string(ase_file)
					var all_tiles_image_data: PackedByteArray
					if tileset_flags & 1 == 1:
						var _external_id := ase_file.get_32()
						var _tileset_id_in_external := ase_file.get_32()
					if tileset_flags & 2 == 2:
						var data_compressed_length := ase_file.get_32()
						var image_data_compressed := ase_file.get_buffer(data_compressed_length)
						var data_length := tile_width * (tile_height * n_of_tiles) * pixel_byte
						all_tiles_image_data = image_data_compressed.decompress(
							data_length, FileAccess.COMPRESSION_DEFLATE
						)
					var tileset := TileSetCustom.new(
						Vector2i(tile_width, tile_height), tileset_name, false
					)
					for k in n_of_tiles:
						var n_of_pixels := tile_width * tile_height * pixel_byte
						var pixel_start := k * n_of_pixels
						var tile_image_data := all_tiles_image_data.slice(
							pixel_start, pixel_start + n_of_pixels
						)
						if color_depth > 8:
							var image := Image.create_from_data(
								tile_width, tile_height, false, image_format, tile_image_data
							)
							image.convert(new_project.get_image_format())
							tileset.add_tile(image, null, 0)
						else:  # Indexed mode
							for l in tile_image_data.size():
								tile_image_data[l] += 1
								if tile_image_data[l] == palette_entry_index + 1:
									tile_image_data[l] = 0
							var indices_image := Image.create_from_data(
								tile_width, tile_height, false, Image.FORMAT_R8, tile_image_data
							)
							var image := ImageExtended.create_custom(
								tile_width, tile_height, false, new_project.get_image_format(), true
							)
							image.indices_image.copy_from(indices_image)
							image.convert_indexed_to_rgb()
							tileset.add_tile(image, null, 0)
					new_project.tilesets.append(tileset)
				_:
					printerr("Unsupported chunk type.")
		new_project.frames.append(frame)
		# Add cels if any are missing. Happens when there are group layers with no children
		# on the top of the layer order.
		var n_of_cels := frame.cels.size()
		if new_project.layers.size() != n_of_cels:
			for j in range(n_of_cels, new_project.layers.size()):
				var layer := new_project.layers[j]
				var cel := layer.new_empty_cel()
				frame.cels.append(cel)
	for i in new_project.layers.size():
		var layer := new_project.layers[i]
		var layer_child_level: int = layer.get_meta(&"layer_child_level", 0)
		if layer_child_level > 0:
			var parent_layer: GroupLayer = null
			var parent_i := 1
			while parent_layer == null:
				var prev_layer := new_project.layers[i - parent_i]
				if prev_layer is GroupLayer:
					if prev_layer.get_meta(&"layer_child_level", 0) == layer_child_level - 1:
						parent_layer = prev_layer
						break
				parent_i += 1
			new_project.move_layers([i], [i - parent_i], [parent_layer])
	for i in new_project.layers.size():
		var layer := new_project.layers[i]
		layer.remove_meta(&"layer_child_level")
		layer.index = i
	new_project.order_layers()
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()


static func parse_aseprite_string(ase_file: FileAccess) -> String:
	var text_length := ase_file.get_16()
	var text_characters := ase_file.get_buffer(text_length)
	return text_characters.get_string_from_utf8()


## Match Aseprite's blend modes to Pixelorama's
static func match_blend_modes(blend_mode: AsepriteBlendMode) -> BaseLayer.BlendModes:
	match blend_mode:
		AsepriteBlendMode.MULTIPLY:
			return BaseLayer.BlendModes.MULTIPLY
		AsepriteBlendMode.SCREEN:
			return BaseLayer.BlendModes.SCREEN
		AsepriteBlendMode.OVERLAY:
			return BaseLayer.BlendModes.OVERLAY
		AsepriteBlendMode.DARKEN:
			return BaseLayer.BlendModes.DARKEN
		AsepriteBlendMode.LIGHTEN:
			return BaseLayer.BlendModes.LIGHTEN
		AsepriteBlendMode.COLOR_DODGE:
			return BaseLayer.BlendModes.COLOR_DODGE
		AsepriteBlendMode.COLOR_BURN:
			return BaseLayer.BlendModes.COLOR_BURN
		AsepriteBlendMode.HARD_LIGHT:
			return BaseLayer.BlendModes.HARD_LIGHT
		AsepriteBlendMode.SOFT_LIGHT:
			return BaseLayer.BlendModes.SOFT_LIGHT
		AsepriteBlendMode.DIFFERENCE:
			return BaseLayer.BlendModes.DIFFERENCE
		AsepriteBlendMode.EXCLUSION:
			return BaseLayer.BlendModes.EXCLUSION
		AsepriteBlendMode.HUE:
			return BaseLayer.BlendModes.HUE
		AsepriteBlendMode.SATURATION:
			return BaseLayer.BlendModes.SATURATION
		AsepriteBlendMode.COLOR:
			return BaseLayer.BlendModes.COLOR
		AsepriteBlendMode.LUMINOSITY:
			return BaseLayer.BlendModes.LUMINOSITY
		AsepriteBlendMode.ADD:
			return BaseLayer.BlendModes.ADD
		AsepriteBlendMode.SUBTRACT:
			return BaseLayer.BlendModes.SUBTRACT
		AsepriteBlendMode.DIVIDE:
			return BaseLayer.BlendModes.DIVIDE
		_:
			return BaseLayer.BlendModes.NORMAL


static func parse_aseprite_variant(ase_file: FileAccess, property_type: int) -> Variant:
	var property: Variant
	match property_type:
		0x0001, 0x0002, 0x0003:  # bool, int8, uint8
			property = ase_file.get_8()
		0x0004, 0x0005:  # int16, uint16
			property = ase_file.get_16()
		0x0006, 0x0007:  # int32, uint32
			property = ase_file.get_32()
		0x0008, 0x0009:  # int64, uint64
			property = ase_file.get_64()
		0x000A, 0x000B:  # Fixed, float
			property = ase_file.get_float()
		0x000C:  # Double
			property = ase_file.get_double()
		0x000D:  # String
			property = parse_aseprite_string(ase_file)
		0x000E, 0x000F:  # Point, size
			property = Vector2(ase_file.get_32(), ase_file.get_32())
		0x0010:  # Rect
			property = Rect2()
			property.position = Vector2(ase_file.get_32(), ase_file.get_32())
			property.size = Vector2(ase_file.get_32(), ase_file.get_32())
		0x0011:  # Vector
			var n_of_elements := ase_file.get_32()
			var element_type := ase_file.get_16()
			property = []
			if element_type == 0:  # All elements are not of the same type
				for i in n_of_elements:
					var subelement_type := ase_file.get_16()
					var subelement = parse_aseprite_variant(ase_file, subelement_type)
					property.append(subelement)
			else:  # All elements are of the same type
				for i in n_of_elements:
					var subelement = parse_aseprite_variant(ase_file, element_type)
					property.append(subelement)
		0x0012:  # Nested properties map
			var n_of_properties := ase_file.get_32()
			property = {}
			for i in n_of_properties:
				var subproperty_name := parse_aseprite_string(ase_file)
				var subproperty_type := ase_file.get_16()
				property[subproperty_name] = parse_aseprite_variant(ase_file, subproperty_type)
		0x0013:  # UUID
			property = ase_file.get_buffer(16)
	return property
