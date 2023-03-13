extends TextureButton

var setting_name: String
var value_type: String
var default_value
var require_restart := false
var node: Node


func _ready() -> void:
	modulate = Global.modulate_icon_color


func _on_RestoreDefaultButton_pressed() -> void:
	Global.set(setting_name, default_value)
	if not require_restart:
		Global.config_cache.set_value("preferences", setting_name, default_value)
	Global.preferences_dialog.preference_update(setting_name, require_restart)
	Global.preferences_dialog.disable_restore_default_button(self, true)
	node.set(value_type, default_value)
