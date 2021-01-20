extends TextureButton


var setting_name : String
var value_type : String
var default_value
var node : Node


func _ready() -> void:
	# Handle themes
	if Global.theme_type == Global.ThemeTypes.LIGHT:
		texture_normal = load("res://assets/graphics/light_themes/misc/icon_reload.png")
	elif Global.theme_type == Global.ThemeTypes.CARAMEL:
		texture_normal = load("res://assets/graphics/caramel_themes/misc/icon_reload.png")


func _on_RestoreDefaultButton_pressed() -> void:
	Global.set(setting_name, default_value)
	Global.config_cache.set_value("preferences", setting_name, default_value)
	Global.preferences_dialog.preference_update(setting_name)
	Global.preferences_dialog.disable_restore_default_button(self, true)
	node.set(value_type, default_value)
