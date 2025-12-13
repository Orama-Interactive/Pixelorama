class_name KeyframeButton
extends TextureButton

const KEYFRAME_ICON := preload("uid://yhha3l44svgs")
const KEYFRAME_SELECTED_ICON := preload("uid://dtx6hygsgoifb")

var dict: Dictionary
var param_name: String
var frame_index: int


func _init() -> void:
	toggle_mode = true
	texture_normal = KEYFRAME_ICON
	texture_pressed = KEYFRAME_SELECTED_ICON
