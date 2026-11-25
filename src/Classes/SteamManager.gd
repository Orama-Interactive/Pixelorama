class_name SteamManager
extends Node

## A class that manages Steam-specific functionalities.
## On non-Steam builds, this node gets automatically freed.

## The Steam app id of Pixelorama.
const APP_ID := 2779170
## We are using a variable instead of the `Steam` singleton directly,
## because it is not available in non-Steam builds.
static var steam_class
static var achievements := {
	"ACH_FIRST_PIXEL": false,
	"ACH_ERASE_PIXEL": false,
	"ACH_SAVE": false,
	"ACH_PREFERENCES": false,
	"ACH_ONLINE_DOCS": false,
	"ACH_SUPPORT_DEVELOPMENT": false,
	"ACH_3D_LAYER": false,
}


func _init() -> void:
	if not ClassDB.class_exists(&"Steam"):
		queue_free()
		return
	steam_class = ClassDB.instantiate(&"Steam")
	OS.set_environment("SteamAppID", str(APP_ID))
	OS.set_environment("SteamGameID", str(APP_ID))


func _ready() -> void:
	if not is_instance_valid(steam_class):
		return
	var response: Dictionary = steam_class.steamInitEx(APP_ID)
	print(response)
	if not steam_class.isSteamRunning():
		print("Steam is not running!")
		return


## Wrapper for [method OS.execute] that executes the given process outside the Steam Linux
## Runtime. Should only be used when [method is_in_runtime] returns [code]true[/code].
static func execute_outside_runtime(
	path: String,
	arguments: PackedStringArray,
	output: Array = [],
	read_stderr := false,
	open_console := false
) -> int:
	# gdlint:ignore = max-line-length
	# https://gitlab.steamos.cloud/steamrt/steam-runtime-tools/-/blob/main/docs/slr-for-game-developers.md#running-commands-outside-the-container
	var complete_arguments: PackedStringArray = ["--alongside-steam", "--host", "-c"]
	complete_arguments.append("%s %s" % [path, " ".join(arguments)])
	return OS.execute(
		"steam-runtime-launch-client", complete_arguments, output, read_stderr, open_console
	)


## Returns [code]true[/code] if Pixelorama is running inside the Steam Linux Runtime.
static func is_in_runtime() -> bool:
	# gdlint:ignore = max-line-length
	# https://gitlab.steamos.cloud/steamrt/steam-runtime-tools/-/blob/main/docs/slr-for-game-developers.md#detecting-the-container-environment
	return OS.is_sandboxed() and "Steam Runtime" in OS.get_distribution_name()


## Unlocks an achievement on Steam based on its [param achievement_name].
static func set_achievement(achievement_name: String) -> void:
	if achievements[achievement_name]:  # Return early if the achievement has already been achieved
		return
	if not is_instance_valid(steam_class):
		return
	if not steam_class.isSteamRunning():
		return
	var status: Dictionary = steam_class.getAchievement(achievement_name)
	if status.get("achieved"):
		achievements[achievement_name] = true
		return
	steam_class.setAchievement(achievement_name)
	steam_class.storeStats()
	achievements[achievement_name] = true
