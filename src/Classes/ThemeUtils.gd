@abstract class_name ThemeUtils
extends RefCounted

static var theme_properties: Dictionary[String, Array] = {
	"Background":
	[
		ThemeProperty.new(&"normal", &"CelButton", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"hover", &"CelButton", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"guide", &"CelButton", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"panel", &"Panel", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"disabled", &"Button", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"normal", &"Button", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"pressed", &"Button", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"title_panel", &"FoldableContainer", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(
			&"title_hover_panel", &"FoldableContainer", Theme.DATA_TYPE_STYLEBOX, true
		),
		ThemeProperty.new(&"title_collapsed_panel", &"FoldableContainer", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(
			&"title_collapsed_hover_panel", &"FoldableContainer", Theme.DATA_TYPE_STYLEBOX, true
		),
		ThemeProperty.new(&"focus", &"FoldableContainer", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"panel", &"ItemList", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"panel", &"Tree", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"focus", &"LineEdit", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"normal", &"LineEdit", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"read_only", &"LineEdit", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"focus", &"TextEdit", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"normal", &"TextEdit", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"read_only", &"TextEdit", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"under_color", &"ValueSlider"),
		ThemeProperty.new(&"panel", &"PopupPanel", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"panel", &"PopupMenu", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"tab_focus", &"TabBar", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"tab_selected", &"TabBar", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(
			&"tab_unselected", &"TabBar", Theme.DATA_TYPE_STYLEBOX, false, _darken.bind(0.3)
		),
		ThemeProperty.new(&"tab_focus", &"TabContainer", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"tab_selected", &"TabContainer", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(
			&"tab_unselected", &"TabContainer", Theme.DATA_TYPE_STYLEBOX, false, _darken.bind(0.3)
		),
		ThemeProperty.new(&"panel", &"TooltipPanel", Theme.DATA_TYPE_STYLEBOX),
	],
	"Primary":
	[
		ThemeProperty.new(&"normal", &"CelButton", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"panel", &"PanelContainer", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"panel", &"FoldableContainer", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"panel", &"AcceptDialog", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"panel", &"TabContainer", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"panel", &"Tree", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"clear_color", &"Misc"),
	],
	"Secondary":
	[
		ThemeProperty.new(&"grabber", &"HScrollBar", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(
			&"grabber_pressed", &"HScrollBar", Theme.DATA_TYPE_STYLEBOX, false, _lighten.bind(0.2)
		),
		ThemeProperty.new(
			&"grabber_highlight", &"HScrollBar", Theme.DATA_TYPE_STYLEBOX, false, _lighten.bind(0.3)
		),
		ThemeProperty.new(&"grabber", &"VScrollBar", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(
			&"grabber_pressed", &"VScrollBar", Theme.DATA_TYPE_STYLEBOX, false, _lighten.bind(0.2)
		),
		ThemeProperty.new(
			&"grabber_highlight", &"VScrollBar", Theme.DATA_TYPE_STYLEBOX, false, _lighten.bind(0.3)
		),
		ThemeProperty.new(&"progress_color", &"ValueSlider"),
		ThemeProperty.new(&"hover", &"Button", Theme.DATA_TYPE_STYLEBOX, false, _halve_alpha),
		ThemeProperty.new(&"hover", &"CheckBox", Theme.DATA_TYPE_STYLEBOX, false, _halve_alpha),
		ThemeProperty.new(&"hover", &"CheckButton", Theme.DATA_TYPE_STYLEBOX, false, _halve_alpha),
		ThemeProperty.new(&"hover", &"CelButton", Theme.DATA_TYPE_STYLEBOX, false, _halve_alpha),
		ThemeProperty.new(&"hover", &"PopupMenu", Theme.DATA_TYPE_STYLEBOX, false, _halve_alpha),
		ThemeProperty.new(&"hover", &"PopupMenu", Theme.DATA_TYPE_STYLEBOX, false, _halve_alpha),
		ThemeProperty.new(
			&"title_hover_panel",
			&"FoldableContainer",
			Theme.DATA_TYPE_STYLEBOX,
			false,
			_halve_alpha
		),
		ThemeProperty.new(
			&"title_collapsed_hover_panel",
			&"FoldableContainer",
			Theme.DATA_TYPE_STYLEBOX,
			false,
			_halve_alpha
		),
		ThemeProperty.new(&"guide", &"CelButton", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"pressed", &"LayerFrameButton", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"selected", &"ItemList", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"selected_focus", &"ItemList", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"selected", &"Tree", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"selected_focus", &"Tree", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"disabled", &"RulerButton", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"focus", &"RulerButton", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"hover", &"RulerButton", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(&"normal", &"RulerButton", Theme.DATA_TYPE_STYLEBOX),
	],
	"Accent":
	[
		ThemeProperty.new(&"pressed", &"Button", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"pressed", &"CelButton", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"pressed", &"LayerFrameButton", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(
			&"focus", &"Button", Theme.DATA_TYPE_STYLEBOX, true, _change_brightness.bind(0.2)
		),
		ThemeProperty.new(&"focus", &"LineEdit", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"focus", &"TextEdit", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"tab_focus", &"TabBar", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"tab_selected", &"TabBar", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"tab_focus", &"TabContainer", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"tab_selected", &"TabContainer", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"panel", &"ItemList", Theme.DATA_TYPE_STYLEBOX, true),
		ThemeProperty.new(&"font_focus_color", &"Button"),
		ThemeProperty.new(&"font_hover_color", &"Button"),
		ThemeProperty.new(&"font_hover_pressed_color", &"Button"),
		ThemeProperty.new(&"font_pressed_color", &"Button"),
		ThemeProperty.new(&"font_hover_color", &"PopupMenu"),
		ThemeProperty.new(&"font_pressed_color", &"MenuButton"),
		ThemeProperty.new(&"font_hover_color", &"MenuButton"),
		ThemeProperty.new(&"font_pressed_color", &"MenuBar"),
		ThemeProperty.new(&"font_hover_color", &"MenuBar"),
		ThemeProperty.new(&"font_hovered_color", &"ItemList"),
		ThemeProperty.new(&"hover_font_color", &"FoldableContainer"),
		ThemeProperty.new(&"panel", &"TooltipPanel", Theme.DATA_TYPE_STYLEBOX, true),
	],
	"Accent #2":
	[
		ThemeProperty.new(&"pressed", &"CelButton", Theme.DATA_TYPE_STYLEBOX),
	],
	"Text color":
	[
		ThemeProperty.new(&"font_color", &"Button"),
		ThemeProperty.new(&"font_color", &"CheckBox"),
		ThemeProperty.new(&"font_color", &"CheckButton"),
		ThemeProperty.new(&"font_color", &"MenuButton"),
		ThemeProperty.new(&"font_color", &"MenuBar"),
		ThemeProperty.new(&"font_color", &"PopupMenu"),
		ThemeProperty.new(&"font_color", &"OptionButton"),
		ThemeProperty.new(&"font_color", &"ProgressBar"),
		ThemeProperty.new(&"font_color", &"Label"),
		ThemeProperty.new(&"font_color", &"LineEdit"),
		ThemeProperty.new(
			&"font_placeholder_color",
			&"LineEdit",
			Theme.DATA_TYPE_COLOR,
			false,
			_set_alpha.bind(0.6)
		),
		ThemeProperty.new(&"font_color", &"TextEdit"),
		ThemeProperty.new(
			&"font_placeholder_color",
			&"TextEdit",
			Theme.DATA_TYPE_COLOR,
			false,
			_set_alpha.bind(0.6)
		),
		ThemeProperty.new(
			&"font_readonly_color", &"TextEdit", Theme.DATA_TYPE_COLOR, false, _set_alpha.bind(0.6)
		),
		ThemeProperty.new(&"font_color", &"ItemList"),
		ThemeProperty.new(&"font_color", &"Tree"),
		ThemeProperty.new(&"font_color", &"FoldableContainer"),
		ThemeProperty.new(&"collapsed_font_color", &"FoldableContainer"),
		ThemeProperty.new(&"font_selected_color", &"TabBar"),
		ThemeProperty.new(&"font_unselected_color", &"TabBar"),
		ThemeProperty.new(&"font_selected_color", &"TabContainer"),
		ThemeProperty.new(&"font_unselected_color", &"TabContainer"),
		ThemeProperty.new(&"title_color", &"Window"),
		ThemeProperty.new(&"font_color", &"TooltipLabel"),
		ThemeProperty.new(&"icon_normal_color", &"Button"),
		ThemeProperty.new(
			&"icon_pressed_color", &"Button", Theme.DATA_TYPE_COLOR, false, _lighten.bind(0.2)
		),
		ThemeProperty.new(
			&"icon_hover_pressed_color", &"Button", Theme.DATA_TYPE_COLOR, false, _lighten.bind(0.2)
		),
		ThemeProperty.new(
			&"icon_hover_color", &"Button", Theme.DATA_TYPE_COLOR, false, _lighten.bind(0.3)
		),
		ThemeProperty.new(&"modulate_color", &"Icons"),
		ThemeProperty.new(
			&"children_hl_line_color", &"Tree", Theme.DATA_TYPE_COLOR, false, _set_alpha.bind(0.15)
		),
		ThemeProperty.new(
			&"parent_hl_line_color", &"Tree", Theme.DATA_TYPE_COLOR, false, _set_alpha.bind(0.15)
		),
		ThemeProperty.new(
			&"relationship_line_color", &"Tree", Theme.DATA_TYPE_COLOR, false, _set_alpha.bind(0.1)
		),
		ThemeProperty.new(
			&"font_disabled_color", &"Button", Theme.DATA_TYPE_COLOR, false, _halve_alpha
		),
		ThemeProperty.new(
			&"icon_disabled_color", &"Button", Theme.DATA_TYPE_COLOR, false, _halve_alpha
		),
		ThemeProperty.new(
			&"font_disabled_color", &"MenuButton", Theme.DATA_TYPE_COLOR, false, _halve_alpha
		),
		ThemeProperty.new(
			&"font_disabled_color", &"MenuBar", Theme.DATA_TYPE_COLOR, false, _halve_alpha
		),
		ThemeProperty.new(
			&"font_disabled_color", &"PopupMenu", Theme.DATA_TYPE_COLOR, false, _halve_alpha
		),
		ThemeProperty.new(
			&"font_disabled_color", &"OptionButton", Theme.DATA_TYPE_COLOR, false, _halve_alpha
		),
		ThemeProperty.new(
			&"font_disabled_color", &"PopupMenu", Theme.DATA_TYPE_COLOR, false, _halve_alpha
		),
		ThemeProperty.new(
			&"font_uneditable_color", &"LineEdit", Theme.DATA_TYPE_COLOR, false, _halve_alpha
		),
		ThemeProperty.new(
			&"font_uneditable_color", &"TextEdit", Theme.DATA_TYPE_COLOR, false, _halve_alpha
		),
		ThemeProperty.new(
			&"font_disabled_color", &"TabBar", Theme.DATA_TYPE_COLOR, false, _halve_alpha
		),
		ThemeProperty.new(
			&"font_disabled_color", &"TabContainer", Theme.DATA_TYPE_COLOR, false, _halve_alpha
		),
	],
	"Window border":
	[
		ThemeProperty.new(&"embedded_border", &"Window", Theme.DATA_TYPE_STYLEBOX),
		ThemeProperty.new(
			&"embedded_unfocused_border",
			&"Window",
			Theme.DATA_TYPE_STYLEBOX,
			false,
			_change_brightness.bind(0.2)
		),
	]
}


class ThemeProperty:
	var data_type: Theme.DataType
	var name := &""
	var theme_type := &""
	var border := false
	var method := Callable()

	func _init(
		_name: StringName,
		_theme_type: StringName,
		_data_type := Theme.DATA_TYPE_COLOR,
		_border := false,
		_method := Callable()
	) -> void:
		name = _name
		theme_type = _theme_type
		data_type = _data_type
		border = _border
		method = _method

	func set_color(theme: Theme, color: Color) -> void:
		if method.is_valid():
			color = method.call(color)
		if data_type == Theme.DATA_TYPE_COLOR:
			theme.set_color(name, theme_type, color)
		elif data_type == Theme.DATA_TYPE_STYLEBOX:
			var stylebox := theme.get_stylebox(name, theme_type)
			if not is_instance_valid(stylebox):
				stylebox = StyleBoxFlat.new()
			if stylebox is StyleBoxFlat:
				if border:
					stylebox.border_color = color
				else:
					stylebox.bg_color = color
			elif stylebox is StyleBoxLine:
				stylebox.color = color
			theme.set_stylebox(name, theme_type, stylebox)

	func get_color(theme: Theme) -> Color:
		if data_type == Theme.DATA_TYPE_COLOR:
			return theme.get_color(name, theme_type)
		elif data_type == Theme.DATA_TYPE_STYLEBOX:
			var stylebox := theme.get_stylebox(name, theme_type)
			if stylebox is StyleBoxFlat:
				if border:
					return stylebox.border_color
				return stylebox.bg_color
			elif stylebox is StyleBoxLine:
				return stylebox.color
		return Color.BLACK


class ThemePalette:
	var background: Color
	var primary: Color
	var secondary: Color
	var accent: Color
	var accent2: Color
	var text_color: Color
	var window_border: Color


static func generate_theme(theme_var: Themes.ThemeVariation) -> Theme:
	var theme := theme_var.theme.duplicate(true) as Theme
	var palette := generate_palette(
		theme_var.get_base_color(), theme_var.get_accent_color(), theme_var.contrast
	)
	if not theme_var.has_custom_colors():
		var bg := palette[0]
		var primary := palette[1]
		var secondary := palette[2]
		var text_color := palette[5]
		if not theme.is_type_variation(&"ValueSlider", &"TextureProgressBar"):
			theme.set_type_variation(&"ValueSlider", &"TextureProgressBar")
		if not theme.has_color(&"under_color", &"ValueSlider"):
			theme.set_color(&"under_color", &"ValueSlider", bg)
		if not theme.has_color(&"progress_color", &"ValueSlider"):
			theme.set_color(&"progress_color", &"ValueSlider", secondary)
		if not theme.has_color(&"clear_color", &"Misc"):
			theme.set_color(&"clear_color", &"Misc", primary)
		if not theme.has_color(&"modulate_color", &"Icons"):
			theme.set_color(&"modulate_color", &"Icons", text_color)
		return theme
	var i := 0
	for color_group in theme_properties:
		var properties := theme_properties[color_group]
		var color := palette[i]
		for prop: ThemeProperty in properties:
			prop.set_color(theme, color)
		i += 1
	return theme


static func generate_palette(
	base_color: Color, accent_color: Color, contrast: float
) -> PackedColorArray:
	var is_dark := base_color.get_luminance() < 0.5
	var background := base_color
	var primary := get_surface_color(base_color, contrast, 0.15)
	var secondary := get_surface_color(base_color, maxf(0.2, contrast), 0.5)
	var window_border := get_surface_color(base_color, contrast, 1.0)
	var accent := accent_color
	var accent2_weight := 0.20 if is_dark else 0.35
	var accent2 := accent.lerp(background, accent2_weight)
	var text_base := Color.WHITE if is_dark else Color.BLACK
	var text_color := text_base * Color(1, 1, 1, 0.75)

	return PackedColorArray(
		[background, primary, secondary, accent, accent2, text_color, window_border]
	)


static func get_surface_color(base_color: Color, contrast: float, offset: float) -> Color:
	var mono := Color.WHITE if base_color.get_luminance() < 0.5 else Color.BLACK
	return base_color.lerp(mono, clampf(contrast * offset, 0.0, 1.0))


static func _invert_color(color: Color) -> Color:
	return color.inverted()


static func _set_alpha(color: Color, alpha: float) -> Color:
	var new_color := color
	new_color.a = alpha
	return new_color


static func _halve_alpha(color: Color) -> Color:
	var new_color := color
	new_color.a /= 2.0
	return new_color


static func _change_brightness(color: Color, amount: float) -> Color:
	if color.get_luminance() > 0.5:
		return _darken(color, amount)
	return _lighten(color, amount)


static func _lighten(color: Color, amount: float) -> Color:
	return color.lightened(amount)


static func _darken(color: Color, amount: float) -> Color:
	return color.darkened(amount)
