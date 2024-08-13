class_name RestoreDefaultButton
extends TextureButton

var setting_name: String
var value_type: String
var default_value
var require_restart := false
var node: Node


func _ready() -> void:
	disabled = true
	add_to_group(&"UIButtons")
	modulate = Global.modulate_icon_color
	texture_normal = preload("res://assets/graphics/misc/icon_reload.png")
	texture_disabled = ImageTexture.new()
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pressed.connect(_on_RestoreDefaultButton_pressed)


func _on_RestoreDefaultButton_pressed() -> void:
	Global.set(setting_name, default_value)
	if not require_restart:
		Global.config_cache.set_value("preferences", setting_name, default_value)
	node.set(value_type, default_value)
