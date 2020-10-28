extends WindowDialog


var artworks := {
	"Roroto Sic" : [preload("res://assets/graphics/splash_screen/artworks/roroto.png"), "https://www.instagram.com/roroto_sic/"],
	"jess.mpz" : [preload("res://assets/graphics/splash_screen/artworks/jessmpz.png"), "https://www.instagram.com/jess.mpz/"],
	"Wishdream" : [preload("res://assets/graphics/splash_screen/artworks/wishdream.png"), "https://twitter.com/WishdreamStar"]
}

var chosen_artwork = ""

onready var latin_font = preload("res://assets/fonts/Roboto-Small.tres")
onready var cjk_font = preload("res://assets/fonts/CJK/DroidSansFallback-Small.tres")


func _on_SplashDialog_about_to_show() -> void:
	var splash_art_texturerect : TextureRect = Global.find_node_by_name(self, "SplashArt")
	var art_by_label : Button = Global.find_node_by_name(self, "ArtistName")
	var show_on_startup_button : CheckBox = Global.find_node_by_name(self, "ShowOnStartup")
	var copyright_label : Label = Global.find_node_by_name(self, "CopyrightLabel")

	if Global.config_cache.has_section_key("preferences", "startup"):
		show_on_startup_button.pressed = !Global.config_cache.get_value("preferences", "startup")
	window_title = "Pixelorama" + " " + Global.current_version

	chosen_artwork = artworks.keys()[randi() % artworks.size()]
	splash_art_texturerect.texture = artworks[chosen_artwork][0]

	art_by_label.text = tr("Art by: %s") % chosen_artwork
	art_by_label.hint_tooltip = artworks[chosen_artwork][1]

	if Global.is_cjk(TranslationServer.get_locale()):
		show_on_startup_button.add_font_override("font", cjk_font)
		copyright_label.add_font_override("font", cjk_font)
	else:
		show_on_startup_button.add_font_override("font", latin_font)
		copyright_label.add_font_override("font", latin_font)

	get_stylebox("panel", "WindowDialog").bg_color = Global.control.theme.get_stylebox("panel", "WindowDialog").bg_color
	get_stylebox("panel", "WindowDialog").border_color = Global.control.theme.get_stylebox("panel", "WindowDialog").border_color
	if OS.get_name() == "HTML5":
		$Contents/ButtonsPatronsLogos/Buttons/OpenLastBtn.visible = false


func _on_ArtCredits_pressed() -> void:
	OS.shell_open(artworks[chosen_artwork][1])


func _on_ShowOnStartup_toggled(pressed : bool) -> void:
	if pressed:
		Global.config_cache.set_value("preferences", "startup", false)
	else:
		Global.config_cache.set_value("preferences", "startup", true)
	Global.config_cache.save("user://cache.ini")


func _on_PatreonButton_pressed() -> void:
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
