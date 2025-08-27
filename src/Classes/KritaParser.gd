class_name KritaParser
extends RefCounted


# https://invent.kde.org/documentation/docs-krita-org/-/merge_requests/105/diffs
# https://github.com/2shady4u/godot-kra-psd-importer/blob/master/docs/KRA_FORMAT.md
static func open_kra_file(path: String) -> void:
	var zip_reader := ZIPReader.new()
	var err := zip_reader.open(path)
	if err != OK:
		print("Error opening kra file: ", error_string(err))
		return
	var data_xml := zip_reader.read_file("maindoc.xml")
	var parser := XMLParser.new()
	err = parser.open_buffer(data_xml)
	if err != OK:
		print("Error parsing XML from kra file: ", error_string(err))
		zip_reader.close()
		return
	var new_project := Project.new([Frame.new()], path.get_file().get_basename())
	var selected_layer: BaseLayer
	var group_layer_found := false
	var current_stack: Array[GroupLayer] = []
	var is_parsing_horizontal_guides := false
	var is_parsing_vertical_guides := false
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			if node_name == "IMAGE":
				var width := parser.get_named_attribute_value_safe("width")
				if not width.is_empty():
					new_project.size.x = str_to_var(width)
				var height := parser.get_named_attribute_value_safe("height")
				if not height.is_empty():
					new_project.size.y = str_to_var(height)
				var project_name := parser.get_named_attribute_value_safe("name")
				if not project_name.is_empty():
					new_project.name = project_name
				var xres := parser.get_named_attribute_value_safe("x-res")
				var yres := parser.get_named_attribute_value_safe("y-res")
				new_project.set_meta(&"xres", str_to_var(xres))
				new_project.set_meta(&"yres", str_to_var(yres))
			elif node_name == "framerate":
				var framerate_type := parser.get_named_attribute_value_safe("type")
				if framerate_type == "value":
					var framerate := parser.get_named_attribute_value_safe("value")
					if not framerate.is_empty():
						new_project.fps = str_to_var(framerate)
			elif node_name == "layer":
				var layer_type := parser.get_named_attribute_value_safe("nodetype")
				for prev_layer in new_project.layers:
					prev_layer.index += 1
				var layer_name := parser.get_named_attribute_value_safe("name")
				var layer: BaseLayer
				var is_shape_layer := false
				if layer_type == "grouplayer":
					group_layer_found = true
					layer = GroupLayer.new(new_project, layer_name)
					if current_stack.size() > 0:
						layer.parent = current_stack[-1]
					layer.expanded = parser.get_named_attribute_value_safe("collapsed") == "0"
					var passthrough := parser.get_named_attribute_value_safe("passthrough")
					if passthrough == "1":
						layer.blend_mode = BaseLayer.BlendModes.PASS_THROUGH
					current_stack.append(layer)
				elif layer_type == "paintlayer":
					layer = PixelLayer.new(new_project, layer_name)
					if current_stack.size() > 0:
						layer.parent = current_stack[-1]
				## TODO: Change to VectorLayer once we support them.
				elif layer_type == "shapelayer":
					is_shape_layer = true
					layer = PixelLayer.new(new_project, layer_name)
					if current_stack.size() > 0:
						layer.parent = current_stack[-1]
				if not is_instance_valid(layer):
					continue
				new_project.layers.insert(0, layer)
				if new_project.layers.size() == 1:
					selected_layer = layer
				layer.index = 0
				layer.opacity = float(parser.get_named_attribute_value_safe("opacity")) / 255.0
				if parser.get_named_attribute_value_safe("selected") == "true":
					selected_layer = layer
				layer.visible = parser.get_named_attribute_value_safe("visible") == "1"
				layer.locked = parser.get_named_attribute_value_safe("locked") == "1"
				if layer.blend_mode != BaseLayer.BlendModes.PASS_THROUGH:
					var blend_mode := parser.get_named_attribute_value_safe("compositeop")
					layer.blend_mode = match_blend_modes(blend_mode)
				var image_x := int(parser.get_named_attribute_value("x"))
				var image_y := int(parser.get_named_attribute_value("y"))
				# Create cel
				var cel := layer.new_empty_cel()
				if cel is PixelCel:
					var image_filename := parser.get_named_attribute_value_safe("filename")
					var image_path := new_project.name.path_join("layers").path_join(image_filename)
					var image: Image
					if is_shape_layer:
						image_path += ".shapelayer".path_join("content.svg")
						var svg_binary := zip_reader.read_file(image_path)
						image = Image.new()
						image.load_svg_from_buffer(svg_binary)
					else:
						var image_data := zip_reader.read_file(image_path)
						image = read_krita_image(image_data)
					if not image.is_empty():
						var image_rect := Rect2i(Vector2i.ZERO, image.get_size())
						cel.get_image().blit_rect(image, image_rect, Vector2i(image_x, image_y))
				new_project.frames[0].cels.insert(0, cel)
			elif node_name == "layers" and group_layer_found:
				group_layer_found = false
			elif node_name == "horizontalGuides":
				is_parsing_horizontal_guides = true
			elif node_name == "verticalGuides":
				is_parsing_vertical_guides = true
			elif node_name.begins_with("item_"):
				if is_parsing_horizontal_guides:
					var value_str := parser.get_named_attribute_value_safe("value")
					var position_units: float = str_to_var(value_str)
					var dpi = new_project.get_meta(&"xres")
					var position: float = position_units * (dpi / 72.0)
					var guide := Guide.new()
					guide.type = Guide.Types.HORIZONTAL
					guide.add_point(Vector2(-99999, position))
					guide.add_point(Vector2(99999, position))
					guide.has_focus = false
					guide.project = new_project
					new_project.guides.append(guide)
					Global.canvas.add_child(guide)
				elif is_parsing_vertical_guides:
					var value_str := parser.get_named_attribute_value_safe("value")
					var position_units: float = str_to_var(value_str)
					var dpi = new_project.get_meta(&"xres")
					var position: float = position_units * (dpi / 72.0)
					var guide := Guide.new()
					guide.type = Guide.Types.VERTICAL
					guide.add_point(Vector2(position, -99999))
					guide.add_point(Vector2(position, 99999))
					guide.has_focus = false
					guide.project = new_project
					new_project.guides.append(guide)
					Global.canvas.add_child(guide)
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			var node_name := parser.get_node_name()
			if node_name == "layers":
				current_stack.pop_back()
			elif node_name == "horizontalGuides":
				is_parsing_horizontal_guides = false
			elif node_name == "verticalGuides":
				is_parsing_vertical_guides = false

	zip_reader.close()
	new_project.order_layers()
	new_project.selected_cels.clear()
	new_project.change_cel(0, new_project.layers.find(selected_layer))
	new_project.save_path = path.get_basename() + ".pxo"
	new_project.file_name = new_project.name
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()


# gdlint: ignore=max-line-length
# https://github.com/Grum999/BuliCommander/blob/tool_repair_file/bulicommander/bulicommander/bc/bcrepairfiles.py#L633
static func read_krita_image(image_data: PackedByteArray) -> Image:
	var number_of_tiles := -1
	var byte_offset := 0
	@warning_ignore("unused_variable")
	var version := 0
	var tile_width := 0
	var tile_height := 0
	var pixel_size := 0
	# Parse ASCII header lines up to "DATA N"
	for i in image_data.size():
		var byte := image_data[i]
		if byte == 10:  # Line break
			var slice := image_data.slice(byte_offset, i)
			var text := slice.get_string_from_ascii()
			byte_offset = i + 1
			if text.begins_with("VERSION"):
				version = int(text.replace("VERSION ", ""))
			elif text.begins_with("TILEWIDTH"):
				tile_width = int(text.replace("TILEWIDTH ", ""))
			elif text.begins_with("TILEHEIGHT"):
				tile_height = int(text.replace("TILEHEIGHT ", ""))
			elif text.begins_with("PIXELSIZE"):
				pixel_size = int(text.replace("PIXELSIZE ", ""))
			elif text.begins_with("DATA"):
				number_of_tiles = int(text.replace("DATA ", ""))
				break
	var decompressed_size := pixel_size * tile_width * tile_height
	var max_left := 0
	var max_top := 0
	var tile_infos := []
	# First pass: get info for each tile.
	for tile in number_of_tiles:
		var left := -1
		var top := -1
		var compressed_size := -1
		var n_of_bytes := range(byte_offset, image_data.size())
		for i in n_of_bytes:
			var byte := image_data[i]
			var slice := image_data.slice(byte_offset, i)
			var text := slice.get_string_from_ascii()
			if byte == 44:  # Comma
				if left == -1:
					left = int(text.replace(",", ""))
				elif top == -1:
					top = int(text.replace(",", ""))
				byte_offset = i + 1
			elif byte == 10:  # Line break
				compressed_size = int(text.replace("LZF,", ""))
				byte_offset = i + 1
				break
		tile_infos.append(
			{"left": left, "top": top, "offset": byte_offset, "size": compressed_size}
		)
		max_left = maxi(max_left, left)
		max_top = maxi(max_top, top)
		byte_offset += compressed_size

	# Create final image.
	var full_w := max_left + tile_width
	var full_h := max_top + tile_height
	var image := Image.create(full_w, full_h, false, Image.FORMAT_RGBA8)

	# Second pass: decompress and blit tiles.
	for t in tile_infos:
		var decompressed_data: PackedByteArray
		var tile_data := image_data.slice(t.offset + 1, t.offset + t.size)
		if image_data[t.offset] == 1:  # Data are using LZF compression.
			decompressed_data = lzf_decompress(tile_data, decompressed_size)
			if decompressed_data.size() != decompressed_size:
				push_error(
					(
						"Decompression failed at tile %s. Expected %s bytes, got %s bytes instead."
						% [t, decompressed_size, decompressed_data.size()]
					)
				)
				continue
		else:  # If data are stored raw, without compression.
			decompressed_data = tile_data

		# Krita stores color data in the following format:
		# B_1, B_2, ..., B_end, G_1, G_2, ..., G_end, R_1, R_2, ..., R_end, A_1, A_2, ..., A_end
		@warning_ignore("integer_division") var n_of_pixels := decompressed_data.size() / 4
		var final_data := PackedByteArray()
		for i in n_of_pixels:
			var blue := decompressed_data[i]
			var green := decompressed_data[i + n_of_pixels]
			var red := decompressed_data[i + n_of_pixels * 2]
			var alpha := decompressed_data[i + n_of_pixels * 3]
			var final_pixel := PackedByteArray([red, green, blue, alpha])
			final_data.append_array(final_pixel)
		var tile := Image.create_from_data(
			tile_width, tile_height, false, Image.FORMAT_RGBA8, final_data
		)
		image.blit_rect(
			tile, Rect2i(Vector2i.ZERO, Vector2i(tile_width, tile_height)), Vector2i(t.left, t.top)
		)

	return image


# gdlint: ignore=max-line-length
# https://invent.kde.org/graphics/krita/-/blob/master/libs/image/tiles3/swap/kis_lzf_compression.cpp#L173
# gdlint: ignore=max-line-length
# https://github.com/Grum999/BuliCommander/blob/tool_repair_file/bulicommander/bulicommander/bc/bcrepairfiles.py#L721
static func lzf_decompress(data_in: PackedByteArray, len_data_out: int) -> PackedByteArray:
	var data_out := PackedByteArray()
	data_out.resize(len_data_out)

	var len_data_in: int = data_in.size()
	var input_pos: int = 0
	var output_pos: int = 0

	while true:
		if input_pos >= len_data_in:
			break

		var ctrl: int = data_in[input_pos]
		input_pos += 1

		if ctrl < 32:
			ctrl += 1

			if output_pos + ctrl > len_data_out:
				print(
					(
						"lzf_uncompress: output buffer too small (1): %s %s %s"
						% [output_pos, ctrl, len_data_out]
					)
				)
				return PackedByteArray()

			for i in range(ctrl):
				data_out[output_pos] = data_in[input_pos]
				output_pos += 1
				input_pos += 1
		else:
			var data_len: int = ctrl >> 5
			var ref: int = output_pos - ((ctrl & 0x1f) << 8) - 1

			if data_len == 7:
				data_len += data_in[input_pos]
				input_pos += 1

			ref -= data_in[input_pos]
			input_pos += 1

			if output_pos + data_len + 2 > len_data_out:
				print(
					(
						"lzf_uncompress: output buffer too small (2): %s %s %s"
						% [output_pos, data_len + 2, len_data_out]
					)
				)
				return PackedByteArray()

			if ref < 0:
				print("lzf_uncompress: invalid reference")
				return PackedByteArray()

			for i in range(data_len + 2):
				data_out[output_pos] = data_out[ref]
				output_pos += 1
				ref += 1

	return data_out


## Match Krita's blend modes to Pixelorama's.
static func match_blend_modes(blend_mode: String) -> BaseLayer.BlendModes:
	match blend_mode:
		"erase":
			return BaseLayer.BlendModes.ERASE
		"darken":
			return BaseLayer.BlendModes.DARKEN
		"multiply":
			return BaseLayer.BlendModes.MULTIPLY
		"burn":
			return BaseLayer.BlendModes.COLOR_BURN
		"linear_burn":
			return BaseLayer.BlendModes.LINEAR_BURN
		"lighten":
			return BaseLayer.BlendModes.LIGHTEN
		"screen":
			return BaseLayer.BlendModes.SCREEN
		"divide":
			return BaseLayer.BlendModes.DIVIDE
		"diff":
			return BaseLayer.BlendModes.DIFFERENCE
		"dodge":
			return BaseLayer.BlendModes.COLOR_DODGE
		"add":
			return BaseLayer.BlendModes.ADD
		"overlay":
			return BaseLayer.BlendModes.OVERLAY
		"soft_light", "soft_light_svg", "soft_light_pegtop_delphi", "soft_light_ifs_illusions":
			return BaseLayer.BlendModes.SOFT_LIGHT
		"hard_light":
			return BaseLayer.BlendModes.HARD_LIGHT
		"exclusion":
			return BaseLayer.BlendModes.EXCLUSION
		"subtract":
			return BaseLayer.BlendModes.SUBTRACT
		"hue_hsl":
			return BaseLayer.BlendModes.HUE
		"saturation_hsl":
			return BaseLayer.BlendModes.SATURATION
		"color_hsl":
			return BaseLayer.BlendModes.COLOR
		"lightness":
			return BaseLayer.BlendModes.LUMINOSITY
		_:
			return BaseLayer.BlendModes.NORMAL
