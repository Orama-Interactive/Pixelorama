extends Node


const languages_dict := {
	"en_US" : ["English", "English"],
	"cs_CZ" : ["Czech", "Czech"],
	"de_DE" : ["Deutsch", "German"],
	"el_GR" : ["Ελληνικά", "Greek"],
	"eo" : ["Esperanto", "Esperanto"],
	"es_ES" : ["Español", "Spanish"],
	"fr_FR" : ["Français", "French"],
	"id_ID" : ["Indonesian", "Indonesian"],
	"it_IT" : ["Italiano", "Italian"],
	"lv_LV" : ["Latvian", "Latvian"],
	"pl_PL" : ["Polski", "Polish"],
	"pt_BR" : ["Português Brasileiro", "Brazilian Portuguese"],
	"ru_RU" : ["Русский", "Russian"],
	"zh_CN" : ["简体中文", "Chinese Simplified"],
	"zh_TW" : ["繁體中文", "Chinese Traditional"],
	"no_NO" : ["Norsk", "Norwegian"],
	"hu_HU" : ["Magyar", "Hungarian"],
	"ro_RO" : ["Română", "Romanian"],
	"ko_KR" : ["한국어", "Korean"],
}

var loaded_locales : Array
onready var latin_font = preload("res://assets/fonts/Roboto-Regular.tres")
onready var cjk_font = preload("res://assets/fonts/CJK/DroidSansFallback-Regular.tres")


func _ready() -> void:
	loaded_locales = TranslationServer.get_loaded_locales()

	# Make sure locales are always sorted, in the same order
	loaded_locales.sort()
	var button_group = get_child(0).group

	# Create radiobuttons for each language
	for locale in loaded_locales:
		if !locale in languages_dict:
			continue
		var button = CheckBox.new()
		button.text = languages_dict[locale][0] + " [%s]" % [locale]
		button.name = languages_dict[locale][1]
		button.hint_tooltip = languages_dict[locale][1]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.group = button_group
		if Global.is_cjk(locale):
			button.add_font_override("font", cjk_font)
		else:
			button.add_font_override("font", latin_font)
		add_child(button)

	# Load language
	if Global.config_cache.has_section_key("preferences", "locale"):
		var saved_locale : String = Global.config_cache.get_value("preferences", "locale")
		TranslationServer.set_locale(saved_locale)

		# Set the language option menu's default selected option to the loaded locale
		var locale_index: int = loaded_locales.find(saved_locale)
		get_child(0).pressed = false # Unset System Language option in preferences
		get_child(locale_index + 1).pressed = true
	else: # If the user doesn't have a language preference, set it to their OS' locale
		TranslationServer.set_locale(OS.get_locale())

	if Global.is_cjk(TranslationServer.get_locale()):
		Global.control.theme.default_font = cjk_font
	else:
		Global.control.theme.default_font = latin_font

	for child in get_children():
		if child is Button:
			child.connect("pressed", self, "_on_Language_pressed", [child.get_index()])
			child.hint_tooltip = child.name


func _on_Language_pressed(index : int) -> void:
	get_child(index).pressed = true
	if index == 0:
		TranslationServer.set_locale(OS.get_locale())
	else:
		TranslationServer.set_locale(loaded_locales[index - 1])

	if Global.is_cjk(TranslationServer.get_locale()):
		Global.control.theme.default_font = cjk_font
	else:
		Global.control.theme.default_font = latin_font

	Global.config_cache.set_value("preferences", "locale", TranslationServer.get_locale())
	Global.config_cache.save("user://cache.ini")

	# Update Translations
	Global.update_hint_tooltips()
	Global.preferences_dialog._on_PreferencesDialog_popup_hide()
	Global.preferences_dialog._on_PreferencesDialog_about_to_show(true)
