extends WindowDialog

onready var changes_label : Label = $"Contents/HBoxContainer/Buttons_Changelog/VBoxContainer/Changlog/ChangesLabel"
onready var art_by_label : Label = $"Contents/HBoxContainer/Logo_ArtWork/CenterContainer/ArtContainer/ArtCredits"
onready var show_on_startup_button : CheckBox = $"Contents/MarginContainer/Info/VBoxContainer/HBoxContainer/ShowOnStartup"
onready var developed_by_label : Label = $"Contents/MarginContainer/Info/VBoxContainer/Branding/VBoxContainer/DevelopedBy"
onready var platinum_placeholder_label : Label = $"Contents/MarginContainer/Info/Sponsors/PlatinumContainer/PlaceholderLabel"
onready var gold_placeholder_label : Label = $"Contents/MarginContainer/Info/Sponsors/GoldContainer/PlaceholderLabel"


func _on_SplashDialog_about_to_show() -> void:
	if Global.config_cache.has_section_key("preferences", "startup"):
		show_on_startup_button.pressed = !Global.config_cache.get_value("preferences", "startup")
	window_title = "Pixelorama" + " " + Global.current_version
	changes_label.text = Global.current_version + " " + tr("Changes")

	art_by_label.text = tr("Art by") + ": Erevos"
	if "zh" in TranslationServer.get_locale():
		show_on_startup_button.add_font_override("font", preload("res://Assets/Fonts/CJK/NotoSansCJKtc-Small.tres"))
		developed_by_label.add_font_override("font", preload("res://Assets/Fonts/CJK/NotoSansCJKtc-Small.tres"))
		platinum_placeholder_label.add_font_override("font", preload("res://Assets/Fonts/CJK/NotoSansCJKtc-Regular.tres"))
		gold_placeholder_label.add_font_override("font", preload("res://Assets/Fonts/CJK/NotoSansCJKtc-Regular.tres"))
	else:
		show_on_startup_button.add_font_override("font", preload("res://Assets/Fonts/Roboto-Small.tres"))
		developed_by_label.add_font_override("font", preload("res://Assets/Fonts/Roboto-Small.tres"))
		platinum_placeholder_label.add_font_override("font", preload("res://Assets/Fonts/Roboto-Bold.tres"))
		gold_placeholder_label.add_font_override("font", preload("res://Assets/Fonts/Roboto-Bold.tres"))


func _on_ArtCredits_pressed() -> void:
	OS.shell_open("https://www.instagram.com/erevoid")


func _on_ShowOnStartup_toggled(pressed : bool) -> void:
	if pressed:
		Global.config_cache.set_value("preferences", "startup", false)
	else:
		Global.config_cache.set_value("preferences", "startup", true)
	Global.config_cache.save("user://cache.ini")


func _on_PatreonButton_pressed() -> void:
	OS.shell_open("https://www.patreon.com/OramaInteractive")


func _on_TakeThisSpot_pressed() -> void:
	OS.shell_open("https://www.patreon.com/OramaInteractive")


func _on_GithubButton_pressed() -> void:
	OS.shell_open("https://github.com/Orama-Interactive/Pixelorama")


func _on_DiscordButton_pressed() -> void:
	OS.shell_open("https://discord.gg/GTMtr8s")


func _on_NewBtn_pressed() -> void:
	Global.control.file_menu_id_pressed(0)
	visible = false


func _on_OpenBtn__pressed() -> void:
	Global.control.file_menu_id_pressed(1)
	visible = false


func _on_OpenLastBtn_pressed() -> void:
	Global.control.file_menu_id_pressed(2)
	visible = false


func _on_ImportBtn_pressed() -> void:
	Global.control.file_menu_id_pressed(5)
	visible = false
