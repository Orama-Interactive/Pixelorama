extends GridContainer

var grid_preferences: Array[GridPreference] = [
	GridPreference.new(
		"grid_type", "GridType", "selected", Global.GridTypes.CARTESIAN
	),
	GridPreference.new("grid_size", "GridSizeValue", "value", Vector2i(2, 2)),
	GridPreference.new(
		"isometric_grid_size", "IsometricGridSizeValue", "value", Vector2i(16, 8)
	),
	GridPreference.new("grid_offset", "GridOffsetValue", "value", Vector2i.ZERO),
	GridPreference.new(
		"grid_draw_over_tile_mode",
		"GridDrawOverTileMode",
		"button_pressed",
		false
	),
	GridPreference.new("grid_color", "GridColor", "color", Color.BLACK),
]

var grid_selected: int = 0:
	set(key):
		grid_selected = key
		for child: BaseButton in grids_select_container.get_children():
			if child.get_index() == grid_selected:
				child.self_modulate = Color.WHITE
			else:
				child.self_modulate = Color.DIM_GRAY
		var grids: Dictionary = Global.config_cache.get_value(
			"preferences", "grids", {0: create_default_properties()}
		)
		if grids.has(key):
			update_pref_ui(grids[key])

@onready var grids_select_container: HFlowContainer = $GridsSelectContainer


class GridPreference:
	var prop_name: String
	var node_path: String
	var value_type: String
	var default_value

	func _init(
		_prop_name: String,
		_node_path: String,
		_value_type: String,
		_default_value = null,
		_require_restart := false
	) -> void:
		prop_name = _prop_name
		node_path = _node_path
		value_type = _value_type
		if _default_value != null:
			default_value = _default_value
		else:
			default_value = Global.get(prop_name)


func _ready() -> void:
	for pref in grid_preferences:
		if not has_node(pref.node_path):
			continue
		var node := get_node(pref.node_path)
		var restore_default_button := RestoreDefaultButton.new()
		restore_default_button.setting_name = pref.prop_name
		restore_default_button.value_type = pref.value_type
		restore_default_button.default_value = pref.default_value
		restore_default_button.node = node

		var node_position := node.get_index()
		node.get_parent().add_child(restore_default_button)
		node.get_parent().move_child(restore_default_button, node_position)
		var grids = Global.config_cache.get_value(
			"preferences", "grids", {0: create_default_properties()}
		)
		Global.config_cache.set_value("preferences", "grids", grids)
		$GridsCount.value = grids.size()

		match pref.value_type:
			"button_pressed":
				node.toggled.connect(
					_on_Grid_Pref_value_changed.bind(pref, restore_default_button)
				)
			"value":
				node.value_changed.connect(
					_on_Grid_Pref_value_changed.bind(pref, restore_default_button)
				)
			"color":
				node.get_picker().presets_visible = false
				node.color_changed.connect(
					_on_Grid_Pref_value_changed.bind(pref, restore_default_button)
				)
			"selected":
				node.item_selected.connect(
					_on_Grid_Pref_value_changed.bind(pref, restore_default_button)
				)
	grid_selected = 0



func _on_Grid_Pref_value_changed(value, pref: GridPreference, button: RestoreDefaultButton) -> void:
	var grids: Dictionary = Global.config_cache.get_value(
		"preferences", "grids", {0: create_default_properties()}
	)
	if grids.has(grid_selected):  # Failsafe (Always true)
		var grid_info: Dictionary = grids[grid_selected]
		var prop := pref.prop_name
		grid_info[prop] = value
		grids[grid_selected] = grid_info
		var default_value = pref.default_value
		var disable: bool = Global.get(prop) == default_value
		if typeof(value) == TYPE_COLOR:
			disable = value.is_equal_approx(default_value)
		disable_restore_default_button(button, disable)
	Global.update_grids(grids)
	Global.config_cache.set_value(
		"preferences", "grids", grids
	)


func _on_grids_count_value_changed(value: float) -> void:
	var grid_idx = int(value - 1)
	var grids: Dictionary = Global.config_cache.get_value(
		"preferences", "grids", {0: create_default_properties()}
	)
	if grid_idx >= grids_select_container.get_child_count():
		for key in range(grids_select_container.get_child_count(), grid_idx + 1):
			if not grids.has(key):
				grids[grid_idx] = create_default_properties()
			add_remove_select_button(key)
	else:
		for key: int in range(grid_idx + 1, grids.size()):
			grids.erase(key)
			add_remove_select_button(key, true)
	Global.config_cache.set_value("preferences", "grids", grids)


func create_default_properties() -> Dictionary:
	var grid_info = {}
	for pref in grid_preferences:
		grid_info[pref.prop_name] = pref.default_value
	return grid_info


func disable_restore_default_button(button: RestoreDefaultButton, disable: bool) -> void:
	button.disabled = disable
	if disable:
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		button.tooltip_text = ""
	else:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "Restore default value"


func add_remove_select_button(grid_idx: int, remove := false):
	if not remove:
		var select_button = Button.new()
		select_button.text = str(grid_idx)
		grids_select_container.add_child(select_button)
		select_button.pressed.connect(func() : grid_selected = grid_idx)
	else:
		if grid_idx < grids_select_container.get_child_count():
			grids_select_container.get_child(grid_idx).queue_free()
	grid_selected = min(grid_selected, grid_idx - 1)


func update_pref_ui(grid_data: Dictionary):
	for pref in grid_preferences:
		var key = pref.prop_name
		if grid_data.has(key):
			var node := get_node(pref.node_path)
			node.set(pref.value_type, grid_data[key])
