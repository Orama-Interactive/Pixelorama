extends WindowDialog


func _on_SplashDialog_about_to_show() -> void:
	var art_by_label : Label = Global.find_node_by_name(self, "ArtByLabel")
	var show_on_startup_button : CheckBox = Global.find_node_by_name(self, "ShowOnStartup")
	var developed_by_label : Label = Global.find_node_by_name(self, "DevelopedBy")
	var become_platinum : Button = Global.find_node_by_name(self, "BecomePlatinum")
	var become_gold : Button = Global.find_node_by_name(self, "BecomeGold")
	var become_patron : Button = Global.find_node_by_name(self, "BecomePatron")

	if Global.config_cache.has_section_key("preferences", "startup"):
		show_on_startup_button.pressed = !Global.config_cache.get_value("preferences", "startup")
	window_title = "Pixelorama" + " " + Global.current_version

	art_by_label.text = tr("Art by") + ":"
	become_platinum.text = "- " + tr("Become a Platinum Sponsor")
	become_gold.text = "- " + tr("Become a Gold Sponsor")
	become_patron.text = "- " + tr("Become a Patron")
	if "zh" in TranslationServer.get_locale():
		show_on_startup_button.add_font_override("font", preload("res://assets/fonts/CJK/NotoSansCJKtc-Small.tres"))
		developed_by_label.add_font_override("font", preload("res://assets/fonts/CJK/NotoSansCJKtc-Small.tres"))
	else:
		show_on_startup_button.add_font_override("font", preload("res://assets/fonts/Roboto-Small.tres"))
		developed_by_label.add_font_override("font", preload("res://assets/fonts/Roboto-Small.tres"))

	get_stylebox("panel", "WindowDialog").bg_color = Global.control.theme.get_stylebox("panel", "WindowDialog").bg_color
	get_stylebox("panel", "WindowDialog").border_color = Global.control.theme.get_stylebox("panel", "WindowDialog").border_color
	if OS.get_name() == "HTML5":
		$Contents/ButtonsPatronsLogos/Buttons/OpenLastBtn.visible = false



func _on_ArtCredits_pressed() -> void:
	OS.shell_open("https://twitter.com/WishdreamStar")


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
	visible = false
	Global.top_menu_container.file_menu_id_pressed(0)


func _on_OpenBtn__pressed() -> void:
	visible = false
	Global.top_menu_container.file_menu_id_pressed(1)


func _on_OpenLastBtn_pressed() -> void:
	visible = false
	Global.top_menu_container.file_menu_id_pressed(2)
