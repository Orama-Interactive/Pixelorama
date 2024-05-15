extends AcceptDialog

var artworks := [
	[  # Licensed under CC-BY-NC-ND, https://creativecommons.org/licenses/by-nc-nd/4.0/
		"Roroto Sic",
		preload("res://assets/graphics/splash_screen/artworks/roroto.png"),
		"https://linktr.ee/Roroto_Sic",
		Color.WHITE
	],
	[  # Licensed under CC BY-NC-SA 4.0, https://creativecommons.org/licenses/by-nc-sa/4.0/
		"Exuvita",
		preload("res://assets/graphics/splash_screen/artworks/exuvita.png"),
		"",
		Color.BLACK
	],
	[  # Licensed under CC BY-NC-SA 4.0, https://creativecommons.org/licenses/by-nc-sa/4.0/
		"Uch",
		preload("res://assets/graphics/splash_screen/artworks/uch.png"),
		"https://www.instagram.com/vs.pxl/",
		Color.BLACK
	],
	[  # Licensed under CC BY-NC-SA 4.0, https://creativecommons.org/licenses/by-nc-sa/4.0/
		"Wishdream",
		preload("res://assets/graphics/splash_screen/artworks/wishdream.png"),
		"https://twitter.com/WishdreamStar",
		Color.BLACK
	],
]

var chosen_artwork: int
@onready var art_by_label := %ArtistName as Button
@onready var splash_art_texturerect := %SplashArt as TextureRect
@onready var version_text := %VersionText as TextureRect


func _ready() -> void:
	get_ok_button().visible = false


func _on_SplashDialog_about_to_show() -> void:
	var show_on_startup_button: CheckBox = find_child("ShowOnStartup")
	if Global.config_cache.has_section_key("preferences", "startup"):
		show_on_startup_button.button_pressed = !Global.config_cache.get_value(
			"preferences", "startup"
		)
	title = "Pixelorama" + " " + Global.current_version

	chosen_artwork = randi() % artworks.size()
	change_artwork(0)

	if OS.get_name() == "Web":
		$Contents/ButtonsPatronsLogos/Buttons/OpenLastBtn.visible = false


func change_artwork(direction: int) -> void:
	if chosen_artwork + direction > artworks.size() - 1 or chosen_artwork + direction < 0:
		chosen_artwork = 0 if direction == 1 else artworks.size() - 1
	else:
		chosen_artwork = chosen_artwork + direction

	splash_art_texturerect.texture = artworks[chosen_artwork][1]

	art_by_label.text = tr("Art by: %s") % artworks[chosen_artwork][0]
	art_by_label.tooltip_text = artworks[chosen_artwork][2]

	version_text.modulate = artworks[chosen_artwork][3]


func _on_ArtCredits_pressed() -> void:
	if artworks[chosen_artwork][2]:
		OS.shell_open(artworks[chosen_artwork][2])


func _on_ShowOnStartup_toggled(pressed: bool) -> void:
	if pressed:
		Global.config_cache.set_value("preferences", "startup", false)
	else:
		Global.config_cache.set_value("preferences", "startup", true)
	Global.config_cache.save(Global.CONFIG_PATH)


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


func _on_ChangeArtBtnLeft_pressed() -> void:
	change_artwork(-1)


func _on_ChangeArtBtnRight_pressed() -> void:
	change_artwork(1)


func _on_visibility_changed() -> void:
	Global.dialog_open(false)
