extends Node

func _ready() -> void:
	Global.loaded_locales = TranslationServer.get_loaded_locales()

	# Make sure locales are always sorted, in the same order
	Global.loaded_locales.sort()

	# Load language
	if Global.config_cache.has_section_key("preferences", "locale"):
		var saved_locale : String = Global.config_cache.get_value("preferences", "locale")
		TranslationServer.set_locale(saved_locale)

		# Set the language option menu's default selected option to the loaded locale
		var locale_index: int = Global.loaded_locales.find(saved_locale)
		get_child(0).pressed = false # Unset System Language option in preferences
		get_child(locale_index + 1).pressed = true
	else: # If the user doesn't have a language preference, set it to their OS' locale
		TranslationServer.set_locale(OS.get_locale())

	if "zh" in TranslationServer.get_locale():
		Global.control.theme.default_font = preload("res://assets/fonts/CJK/NotoSansCJKtc-Regular.tres")
	else:
		Global.control.theme.default_font = preload("res://assets/fonts/Roboto-Regular.tres")

	for child in get_children():
		if child is Button:
			child.connect("pressed", self, "_on_Language_pressed", [child])
			child.hint_tooltip = child.name


func _on_Language_pressed(button : Button) -> void:
	var index := 0
	var i := -1
	for child in get_children():
		if child is Button:
			if child == button:
				button.pressed = true
				index = i
			else:
				child.pressed = false
			i += 1
	if index == -1:
		TranslationServer.set_locale(OS.get_locale())
	else:
		TranslationServer.set_locale(Global.loaded_locales[index])

	if "zh" in TranslationServer.get_locale():
		Global.control.theme.default_font = preload("res://assets/fonts/CJK/NotoSansCJKtc-Regular.tres")
	else:
		Global.control.theme.default_font = preload("res://assets/fonts/Roboto-Regular.tres")

	Global.config_cache.set_value("preferences", "locale", TranslationServer.get_locale())
	Global.config_cache.save("user://cache.ini")

	# Update Translations
	Global.update_hint_tooltips()
	Global.preferences_dialog._on_PreferencesDialog_popup_hide()
	Global.preferences_dialog._on_PreferencesDialog_about_to_show(true)
