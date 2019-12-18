extends AcceptDialog

func _on_LanguageOption_item_selected(ID : int) -> void:
	if ID == 0:
		TranslationServer.set_locale(OS.get_locale())
	else:
		TranslationServer.set_locale(Global.loaded_locales[ID - 1])
		if Global.loaded_locales[ID - 1] == "zh_TW":
			Global.control.theme.default_font = preload("res://Assets/Fonts/NotoSansCJKtc-Regular.tres")
		else:
			Global.control.theme.default_font = preload("res://Assets/Fonts/Roboto-Regular.tres")

	Global.config_cache.set_value("preferences", "locale", TranslationServer.get_locale())
	Global.config_cache.save("user://cache.ini")

func _on_GridWidthValue_value_changed(value : float) -> void:
	Global.grid_width = value

func _on_GridHeightValue_value_changed(value : float) -> void:
	Global.grid_height = value

func _on_GridColor_color_changed(color : Color) -> void:
	Global.grid_color = color