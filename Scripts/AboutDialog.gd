extends AcceptDialog

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var current_version : String = ProjectSettings.get_setting("application/config/Version")
	$AboutUI/Pixelorama.text = "Pixelorama %s\n" % current_version

func _on_Website_pressed() -> void:
	OS.shell_open("https://www.orama-interactive.com/pixelorama")

func _on_GitHub_pressed() -> void:
	OS.shell_open("https://github.com/OverloadedOrama/Pixelorama")

func _on_Donate_pressed() -> void:
	OS.shell_open("https://paypal.me/OverloadedOrama")
	OS.shell_open("https://ko-fi.com/overloadedorama")
