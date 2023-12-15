extends Node

var tool_names := PackedStringArray()


func _enter_tree() -> void:
	# The parameters passed in order :
	# tool_name
	# display_name
	# scene
	# layer_types
	# extra_hint
	# shortcut
	# extra_shortucts
	# insertion point
	tool_names.append("RectSelect")
	ExtensionsApi.tools.add_tool(
		"RectSelect",
		"Rectangular Selection",
		"res://src/Extensions/DefaultTools/Tools/SelectionTools/RectSelect.tscn",
		[],
		"",
		"rectangle_select",
		[],
		0
	)

	tool_names.append("EllipseSelect")
	ExtensionsApi.tools.add_tool(
		"EllipseSelect",
		"Elliptical Selection",
		"res://src/Extensions/DefaultTools/Tools/SelectionTools/EllipseSelect.tscn",
		[],
		"",
		"ellipse_select",
		[],
		1
	)

	tool_names.append("PolygonSelect")
	ExtensionsApi.tools.add_tool(
		"PolygonSelect",
		"Polygonal Selection",
		"res://src/Extensions/DefaultTools/Tools/SelectionTools/PolygonSelect.tscn",
		[],
		"Double-click to connect the last point to the starting point",
		"polygon_select",
		[],
		2
	)

	tool_names.append("ColorSelect")
	ExtensionsApi.tools.add_tool(
		"ColorSelect",
		"Select By Color",
		"res://src/Extensions/DefaultTools/Tools/SelectionTools/ColorSelect.tscn",
		[],
		"",
		"color_select",
		[],
		3
	)

	tool_names.append("MagicWand")
	ExtensionsApi.tools.add_tool(
		"MagicWand",
		"Magic Wand",
		"res://src/Extensions/DefaultTools/Tools/SelectionTools/MagicWand.tscn",
		[],
		"",
		"magic_wand",
		[],
		4
	)

	tool_names.append("Lasso")
	ExtensionsApi.tools.add_tool(
		"Lasso",
		"Lasso / Free Select Tool",
		"res://src/Extensions/DefaultTools/Tools/SelectionTools/Lasso.tscn",
		[],
		"",
		"lasso",
		[],
		5
	)

	tool_names.append("PaintSelect")
	ExtensionsApi.tools.add_tool(
		"PaintSelect",
		"Select by Drawing",
		"res://src/Extensions/DefaultTools/Tools/SelectionTools/PaintSelect.tscn",
		[],
		"",
		"paint_selection",
		[],
		6
	)

	tool_names.append("Move")
	ExtensionsApi.tools.add_tool(
		"Move",
		"Move",
		"res://src/Extensions/DefaultTools/Tools/Move.tscn",
		[Global.LayerTypes.PIXEL],
		"",
		"move",
		[],
		7
	)

	tool_names.append("Zoom")
	ExtensionsApi.tools.add_tool(
		"Zoom",
		"Zoom",
		"res://src/Extensions/DefaultTools/Tools/Zoom.tscn",
		[],
		"",
		"zoom",
		[],
		8
	)

	tool_names.append("Pan")
	ExtensionsApi.tools.add_tool(
		"Pan",
		"Pan",
		"res://src/Extensions/DefaultTools/Tools/Pan.tscn",
		[],
		"",
		"pan",
		[],
		9
	)

	tool_names.append("ColorPicker")
	ExtensionsApi.tools.add_tool(
		"ColorPicker",
		"Color Picker",
		"res://src/Extensions/DefaultTools/Tools/ColorPicker.tscn",
		[],
		"Select a color from a pixel of the sprite",
		"colorpicker",
		[],
		10
	)

	tool_names.append("Crop")
	ExtensionsApi.tools.add_tool(
		"Crop",
		"Crop",
		"res://src/Extensions/DefaultTools/Tools/CropTool.tscn",
		[],
		"Resize the canvas",
		"crop",
		[],
		11
	)

	tool_names.append("Bucket")
	ExtensionsApi.tools.add_tool(
		"Bucket",
		"Bucket",
		"res://src/Extensions/DefaultTools/Tools/Bucket.tscn",
		[Global.LayerTypes.PIXEL],
		"",
		"fill",
		[],
	)

	tool_names.append("Shading")
	ExtensionsApi.tools.add_tool(
		"Shading",
		"Shading Tool",
		"res://src/Extensions/DefaultTools/Tools/Shading.tscn",
		[Global.LayerTypes.PIXEL],
		"",
		"shading"
	)

	tool_names.append("LineTool")
	ExtensionsApi.tools.add_tool(
		"LineTool",
		"Line Tool",
		"res://src/Extensions/DefaultTools/Tools/LineTool.tscn",
		[Global.LayerTypes.PIXEL],
		"""Hold %s to snap the angle of the line
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""",
		"linetool",
		["shape_perfect", "shape_center", "shape_displace"]
	)

	tool_names.append("RectangleTool")
	ExtensionsApi.tools.add_tool(
		"RectangleTool",
		"Rectangle Tool",
		"res://src/Extensions/DefaultTools/Tools/RectangleTool.tscn",
		[Global.LayerTypes.PIXEL],
		"""Hold %s to create a 1:1 shape
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""",
		"rectangletool",
		["shape_perfect", "shape_center", "shape_displace"]
	)

	tool_names.append("EllipseTool")
	ExtensionsApi.tools.add_tool(
		"EllipseTool",
		"Ellipse Tool",
		"res://src/Extensions/DefaultTools/Tools/EllipseTool.tscn",
		[Global.LayerTypes.PIXEL],
		"""Hold %s to create a 1:1 shape
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""",
		"ellipsetool",
		["shape_perfect", "shape_center", "shape_displace"]
	)


func _exit_tree() -> void:
	for tool_name in tool_names:
		ExtensionsApi.tools.remove_tool(tool_name)
