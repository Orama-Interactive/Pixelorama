extends GridContainer

# We should use pre defined initial grid colors instead of random colors
const INITIAL_GRID_COLORS := [
	Color.BLACK,
	Color.WHITE,
	Color.YELLOW,
	Color.GREEN,
	Color.BLUE,
	Color.GRAY,
	Color.ORANGE,
	Color.PINK,
	Color.SIENNA,
	Color.CORAL,
]

var grid_preferences: Array[GridPreference] = [
	GridPreference.new("grid_type", "GridType", "selected", Global.GridTypes.CARTESIAN),
	GridPreference.new("grid_size", "GridSizeValue", "value", Vector2i(2, 2)),
	GridPreference.new("grid_offset", "GridOffsetValue", "value", Vector2i.ZERO),
	GridPreference.new("grid_draw_over_tile_mode", "GridDrawOverTileMode", "button_pressed", false),
	GridPreference.new("is_pixelated", "GridPixelated", "button_pressed", false),
	GridPreference.new("y_separated", "GridYSeperated", "button_pressed", false),
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
			load_grid_ui(grids[key])

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


func _ready() -> void:
	var grids = Global.config_cache.get_value(
		"preferences", "grids", {0: create_default_properties()}
	)
	Global.config_cache.set_value("preferences", "grids", grids)
	$GridsCount.value = grids.size()
	if grids.size() == 1:
		add_remove_select_button(0)
	for pref in grid_preferences:
		if not has_node(pref.node_path):
			continue
		var node := get_node(pref.node_path)
		var restore_default_button := RestoreDefaultButton.new()
		restore_default_button.pressed.connect(
			_on_grid_pref_value_changed.bind(pref.default_value, pref, restore_default_button)
		)
		restore_default_button.setting_name = pref.prop_name
		restore_default_button.value_type = pref.value_type
		restore_default_button.default_value = pref.default_value
		restore_default_button.node = node

		var node_position := node.get_index()
		node.get_parent().add_child(restore_default_button)
		node.get_parent().move_child(restore_default_button, node_position)

		match pref.value_type:
			"button_pressed":
				node.toggled.connect(_on_grid_pref_value_changed.bind(pref, restore_default_button))
			"value":
				node.value_changed.connect(
					_on_grid_pref_value_changed.bind(pref, restore_default_button)
				)
			"color":
				node.get_picker().presets_visible = false
				node.color_changed.connect(
					_on_grid_pref_value_changed.bind(pref, restore_default_button)
				)
			"selected":
				node.item_selected.connect(
					_on_grid_pref_value_changed.bind(pref, restore_default_button)
				)
	grid_selected = 0


func _on_grid_pref_value_changed(value, pref: GridPreference, button: RestoreDefaultButton) -> void:
	var grids: Dictionary = Global.config_cache.get_value(
		"preferences", "grids", {0: create_default_properties()}
	)
	var prop := pref.prop_name
	var grid_info := {}
	if grids.has(grid_selected):  # Failsafe (Always true)
		grid_info = grids[grid_selected]
		grid_info[prop] = value
		grids[grid_selected] = grid_info
		# NOTE: All prop values of bool type in grid_info that don't have a direct mapping in
		# the Grid class gets assigned or removed from the special_flags based on if it's value
		# is true or false.
		Global.update_grids(grids)
		var default_value = pref.default_value
		var disable: bool = Global.grids[grid_selected].get(prop) == default_value
		# NOTE: special_flags are special switches that may be different for different grids
		# for example the y_separated flag is only specific to the isometric grid.
		var special_flags = Global.grids[grid_selected].get("special_flags")
		if (
			special_flags
			and typeof(special_flags) == TYPE_PACKED_STRING_ARRAY
			and typeof(default_value) == TYPE_BOOL
		):
			disable = (prop in special_flags) == default_value if !disable else disable
		if typeof(value) == TYPE_COLOR:
			disable = value.is_equal_approx(default_value)
		disable_restore_default_button(button, disable)
	Global.config_cache.set_value("preferences", "grids", grids)
	manage_button_disabling(grid_info)


func _on_grids_count_value_changed(value: float) -> void:
	var new_grids: Dictionary = Global.config_cache.get_value(
		"preferences", "grids", {0: create_default_properties()}
	)
	var last_grid_idx = int(value - 1)
	if last_grid_idx >= grids_select_container.get_child_count():
		# Add missing grids
		for key in range(grids_select_container.get_child_count(), value):
			if not new_grids.has(key):
				var new_grid := create_default_properties()
				if new_grids.has(key - 1):  # Failsafe
					var last_grid = new_grids[key - 1]
					# This small bit of code is there to make ui look a little neater
					# Reasons:
					# - Usually user intends to make the next grid twice the size.
					# - Having all grids being same size initially may cause confusion for some
					# users when they try to change color of a middle grid not seeing it's changing
					# (due to being covered by grids above it).
					if new_grid.has("grid_size") and new_grid.has("grid_color"):
						new_grid["grid_size"] = last_grid["grid_size"] * 2
						if key < INITIAL_GRID_COLORS.size():
							new_grid["grid_color"] = INITIAL_GRID_COLORS[key]
				new_grids[key] = new_grid
			add_remove_select_button(key)
	else:
		# Remove extra grids
		for key: int in range(value, new_grids.size()):
			new_grids.erase(key)
			add_remove_select_button(key, true)
	grid_selected = min(grid_selected, last_grid_idx)
	Global.update_grids(new_grids)
	Global.config_cache.set_value("preferences", "grids", new_grids)


func create_default_properties() -> Dictionary:
	var grid_info := {}
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
		select_button.pressed.connect(func(): grid_selected = grid_idx)
	else:
		if grid_idx < grids_select_container.get_child_count():
			grids_select_container.get_child(grid_idx).queue_free()


func load_grid_ui(grid_data: Dictionary):
	for pref in grid_preferences:
		var key = pref.prop_name
		if grid_data.has(key):
			var node := get_node(pref.node_path)
			node.set(pref.value_type, grid_data[key])
			if pref.value_type == "color":
				# the signal doesn't seem to be emitted automatically
				node.color_changed.emit(grid_data[key])
	manage_button_disabling(grid_data)


func manage_button_disabling(grid_data: Dictionary):
	$GridPixelated.disabled = true
	$GridYSeperated.disabled = true
	if grid_data.get("grid_type", 0) == Global.GridTypes.ISOMETRIC:
		$GridPixelated.disabled = false
		if grid_data.get("is_pixelated", false) == true:
			$GridYSeperated.disabled = false
	$GridPixelated.text = "Disabled" if $GridPixelated.disabled else "On"
	$GridYSeperated.text = "Disabled" if $GridYSeperated.disabled else "On"
