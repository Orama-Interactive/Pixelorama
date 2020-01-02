extends WindowDialog

func _on_SplashDialog_about_to_show() -> void:
	var current_version : String = ProjectSettings.get_setting("application/config/Version")
	window_title = "Pixelorama" + " " + current_version
	$Contents/DevelopedBy.text = "Pixelorama" + " " + current_version + " - " + tr("MADEBY_LABEL")

	$Contents/ArtCredits.text = tr("Art by") + ": Erevos"

func _on_ArtCredits_pressed() -> void:
	OS.shell_open("https://www.instagram.com/erevos_art")

func _on_ShowOnStartup_toggled(pressed : bool) -> void:
	if pressed:
		Global.config_cache.set_value("preferences", "startup", false)
	else:
		Global.config_cache.set_value("preferences", "startup", true)