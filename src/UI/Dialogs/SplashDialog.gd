extends WindowDialog

var artworks := [
	[
		"Roroto Sic",
		preload("res://assets/graphics/splash_screen/artworks/roroto.png"),
		"https://linktr.ee/Roroto_Sic"
	],
	[
		"Kamilayza",
		preload("res://assets/graphics/splash_screen/artworks/kamilayza.png"),
		"https://twitter.com/kamilayza"
	],
	[
		"Wishdream",
		preload("res://assets/graphics/splash_screen/artworks/wishdream.png"),
		"https://twitter.com/WishdreamStar"
	]
]

var chosen_artwork: int

var splash_art_texturerect: TextureRect
var art_by_label: Button


func _on_SplashDialog_about_to_show() -> void:
	splash_art_texturerect = find_node("SplashArt")
	art_by_label = find_node("ArtistName")
	var show_on_startup_button: CheckBox = find_node("ShowOnStartup")

	if Global.config_cache.has_section_key("preferences", "startup"):
		show_on_startup_button.pressed = !Global.config_cache.get_value("preferences", "startup")
	window_title = "Pixelorama" + " " + Global.current_version

	chosen_artwork = randi() % artworks.size()
	change_artwork(0)

	if OS.get_name() == "HTML5":
		$Contents/ButtonsPatronsLogos/Buttons/OpenLastBtn.visible = false


func change_artwork(direction: int) -> void:
	if chosen_artwork + direction > artworks.size() - 1 or chosen_artwork + direction < 0:
		chosen_artwork = 0 if direction == 1 else artworks.size() - 1
	else:
		chosen_artwork = chosen_artwork + direction

	splash_art_texturerect.texture = artworks[chosen_artwork][1]

	art_by_label.text = tr("Art by: %s") % artworks[chosen_artwork][0]
	art_by_label.hint_tooltip = artworks[chosen_artwork][2]


func _on_ArtCredits_pressed() -> void:
	OS.shell_open(artworks[chosen_artwork][2])


func _on_ShowOnStartup_toggled(pressed: bool) -> void:
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


func _on_OpenBtn_pressed() -> void:
	visible = false
	Global.top_menu_container.file_menu_id_pressed(1)


func _on_OpenLastBtn_pressed() -> void:
	visible = false
	Global.top_menu_container.file_menu_id_pressed(2)


func _on_ChangeArtBtnLeft_pressed():
	change_artwork(-1)


func _on_ChangeArtBtnRight_pressed():
	change_artwork(1)
