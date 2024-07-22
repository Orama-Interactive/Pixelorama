extends AcceptDialog

var artworks: Array[Artwork] = [
	Artwork.new(
		preload("res://assets/graphics/splash_screen/artworks/roroto.tres"),
		"Roroto Sic",
		"https://linktr.ee/Roroto_Sic",
		Color.WHITE,
		"Licensed under CC-BY-NC-ND, https://creativecommons.org/licenses/by-nc-nd/4.0/"
	),
	Artwork.new(
		preload("res://assets/graphics/splash_screen/artworks/uch.png"),
		"Uch",
		"https://www.instagram.com/vs.pxl/",
		Color.WHITE,
		"Licensed under CC BY-NC-SA 4.0, https://creativecommons.org/licenses/by-nc-sa/4.0/"
	),
	Artwork.new(
		preload("res://assets/graphics/splash_screen/artworks/wishdream.png"),
		"Wishdream",
		"https://x.com/WishdreamStar",
		Color.BLACK,
		"Licensed under CC BY-NC-SA 4.0, https://creativecommons.org/licenses/by-nc-sa/4.0/"
	),
	Artwork.new(
		preload("res://assets/graphics/splash_screen/artworks/nighters.png"),
		"Nighters",
		"https://www.instagram.com/_artei",
		Color.WHITE,
		"Licensed under CC BY 3.0, https://creativecommons.org/licenses/by/3.0/"
	),
	Artwork.new(
		preload("res://assets/graphics/splash_screen/artworks/kalpar.png"),
		"Kalpar",
		"https://linktr.ee/kalpar",
		Color.BLACK,
		"Licensed under CC BY 3.0, https://creativecommons.org/licenses/by/3.0/"
	),
]

var chosen_artwork: int
@onready var art_by_label := %ArtistName as Button
@onready var splash_art_texturerect := %SplashArt as TextureRect
@onready var version_text := %VersionText as TextureRect
@onready var show_on_startup := %ShowOnStartup as CheckBox


class Artwork:
	var artwork: Texture2D
	var artist_name := ""
	var artist_link := ""
	var text_modulation: Color
	var license_information := ""

	func _init(
		_artwork: Texture2D,
		_artist_name := "",
		_artist_link := "",
		_text_modulation := Color.WHITE,
		_license_information := ""
	) -> void:
		artwork = _artwork
		artist_name = _artist_name
		artist_link = _artist_link
		text_modulation = _text_modulation
		license_information = _license_information


func _ready() -> void:
	get_ok_button().visible = false
	if OS.get_name() == "Web":
		$Contents/ButtonsPatronsLogos/Buttons/OpenLastBtn.visible = false


func _process(_delta: float) -> void:
	splash_art_texturerect.queue_redraw()


func _on_SplashDialog_about_to_show() -> void:
	if Global.config_cache.has_section_key("preferences", "startup"):
		show_on_startup.button_pressed = not Global.config_cache.get_value("preferences", "startup")
	title = "Pixelorama" + " " + Global.current_version

	if not artworks.is_empty():
		chosen_artwork = randi() % artworks.size()
		change_artwork(0)
	else:
		$Contents/SplashArt/ChangeArtBtnLeft.visible = false
		$Contents/SplashArt/ChangeArtBtnRight.visible = false


func change_artwork(direction: int) -> void:
	chosen_artwork = wrapi(chosen_artwork + direction, 0, artworks.size())
	splash_art_texturerect.texture = artworks[chosen_artwork].artwork
	set_process(artworks[chosen_artwork].artwork is AnimatedTexture)
	art_by_label.text = tr("Art by: %s") % artworks[chosen_artwork].artist_name
	art_by_label.tooltip_text = artworks[chosen_artwork].artist_link
	version_text.modulate = artworks[chosen_artwork].text_modulation
	# Set an ambient
	var ambient = GradientTexture2D.new()
	ambient.gradient = Gradient.new()
	ambient.width = 100
	ambient.height = 100
	var col_a = splash_art_texturerect.texture.get_image().get_pixel(0, 0)
	var col_b = Color(col_a.r, col_a.g, col_a.b, 0.5)
	ambient.gradient.set_color(0, col_a)
	ambient.gradient.set_color(1, col_b)
	ambient.fill_from = Vector2(0.5, 0.5)
	ambient.fill = GradientTexture2D.FILL_RADIAL
	%Ambient.texture = ambient


func _on_ArtCredits_pressed() -> void:
	if not artworks[chosen_artwork].artist_link.is_empty():
		OS.shell_open(artworks[chosen_artwork].artist_link)


func _on_ShowOnStartup_toggled(pressed: bool) -> void:
	Global.config_cache.set_value("preferences", "startup", not pressed)
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
	if not visible:
		Global.dialog_open(false)
		set_process(false)
