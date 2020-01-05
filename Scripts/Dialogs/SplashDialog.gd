extends WindowDialog

onready var changes_label : Label = $Contents/HBoxContainer/ChangesLabel
onready var art_by_label : Label = $Contents/PatronsArtNews/ArtContainer/ArtCredits
onready var show_on_startup_button : CheckBox = $Contents/BottomHboxContainer/ShowOnStartup
onready var developed_by_label : Label = $Contents/BottomHboxContainer/VBoxContainer/DevelopedBy

func _on_SplashDialog_about_to_show() -> void:
	if Global.config_cache.has_section_key("preferences", "startup"):
		show_on_startup_button.pressed = !Global.config_cache.get_value("preferences", "startup")
	var current_version : String = ProjectSettings.get_setting("application/config/Version")
	window_title = "Pixelorama" + " " + current_version
	changes_label.text = current_version + " " + tr("Changes")
	developed_by_label.text = "Pixelorama" + " " + current_version + " - " + tr("MADEBY_LABEL")

	art_by_label.text = tr("Art by") + ": Erevos"
	if "zh" in TranslationServer.get_locale():
		show_on_startup_button.add_font_override("font", preload("res://Assets/Fonts/CJK/NotoSansCJKtc-Small.tres"))
		developed_by_label.add_font_override("font", preload("res://Assets/Fonts/CJK/NotoSansCJKtc-Small.tres"))
	else:
		show_on_startup_button.add_font_override("font", preload("res://Assets/Fonts/Roboto-Small.tres"))
		developed_by_label.add_font_override("font", preload("res://Assets/Fonts/Roboto-Small.tres"))

func _on_ArtCredits_pressed() -> void:
	OS.shell_open("https://www.instagram.com/erevos_art")

func _on_ShowOnStartup_toggled(pressed : bool) -> void:
	if pressed:
		Global.config_cache.set_value("preferences", "startup", false)
	else:
		Global.config_cache.set_value("preferences", "startup", true)

func _on_PatronButton_pressed() -> void:
	OS.shell_open("https://www.patreon.com/OramaInteractive")

func _on_TakeThisSpot_pressed() -> void:
	OS.shell_open("https://www.patreon.com/OramaInteractive")
