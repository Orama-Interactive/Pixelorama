extends Node

const LANGUAGES_DICT := {
	"en_US": ["English", "English"],
	"cs_CZ": ["Czech", "Czech"],
	"de_DE": ["Deutsch", "German"],
	"el_GR": ["Ελληνικά", "Greek"],
	"eo": ["Esperanto", "Esperanto"],
	"es_ES": ["Español", "Spanish"],
	"fr_FR": ["Français", "French"],
	"id_ID": ["Indonesian", "Indonesian"],
	"it_IT": ["Italiano", "Italian"],
	"lv_LV": ["Latvian", "Latvian"],
	"pl_PL": ["Polski", "Polish"],
	"pt_BR": ["Português Brasileiro", "Brazilian Portuguese"],
	"pt_PT": ["Português", "Portuguese"],
	"ru_RU": ["Русский", "Russian"],
	"zh_CN": ["简体中文", "Chinese Simplified"],
	"zh_TW": ["繁體中文", "Chinese Traditional"],
	"nb_NO": ["Norsk Bokmål", "Norwegian Bokmål"],
	"hu_HU": ["Magyar", "Hungarian"],
	"ro_RO": ["Română", "Romanian"],
	"ko_KR": ["한국어", "Korean"],
	"tr_TR": ["Türkçe", "Turkish"],
	"ja_JP": ["日本語", "Japanese"],
	"uk_UA": ["Українська", "Ukrainian"],
}

var loaded_locales: Array


func _ready() -> void:
	loaded_locales = TranslationServer.get_loaded_locales()

	# Make sure locales are always sorted, in the same order
	loaded_locales.sort()
	var button_group: ButtonGroup = get_child(0).group

	# Create radiobuttons for each language
	for locale in loaded_locales:
		if !locale in LANGUAGES_DICT:
			continue
		var button := CheckBox.new()
		button.text = LANGUAGES_DICT[locale][0] + " [%s]" % [locale]
		button.name = LANGUAGES_DICT[locale][1]
		button.hint_tooltip = LANGUAGES_DICT[locale][1]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.group = button_group
		add_child(button)

	# Load language
	if Global.config_cache.has_section_key("preferences", "locale"):
		var saved_locale: String = Global.config_cache.get_value("preferences", "locale")
		TranslationServer.set_locale(saved_locale)

		# Set the language option menu's default selected option to the loaded locale
		var locale_index: int = loaded_locales.find(saved_locale)
		get_child(0).pressed = false  # Unset System Language option in preferences
		get_child(locale_index + 1).pressed = true
	else:  # If the user doesn't have a language preference, set it to their OS' locale
		TranslationServer.set_locale(OS.get_locale())

	for child in get_children():
		if child is Button:
			child.connect("pressed", self, "_on_Language_pressed", [child.get_index()])
			child.hint_tooltip = child.name


func _on_Language_pressed(index: int) -> void:
	get_child(index).pressed = true
	if index == 0:
		TranslationServer.set_locale(OS.get_locale())
	else:
		TranslationServer.set_locale(loaded_locales[index - 1])

	Global.config_cache.set_value("preferences", "locale", TranslationServer.get_locale())
	Global.config_cache.save("user://cache.ini")

	# Update Translations
	Global.update_hint_tooltips()
	Global.preferences_dialog.list.clear()
	Global.preferences_dialog.add_tabs(true)
