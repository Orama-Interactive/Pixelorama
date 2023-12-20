class_name PaletteColor
extends Resource

const UNSET_INDEX := -1

@export var color := Color.TRANSPARENT
@export var index := UNSET_INDEX


func _init(init_color := Color.BLACK, init_index := UNSET_INDEX) -> void:
	color = init_color
	index = init_index
