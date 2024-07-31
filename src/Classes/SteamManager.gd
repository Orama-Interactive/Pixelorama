class_name SteamManager
extends Node

## A class that manages Steam-specific functionalities. Currently only unlocks achievements.
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
	var response: Dictionary = steam_class.steamInitEx(true, APP_ID)
	print(response)
	if not steam_class.isSteamRunning():
		print("Steam is not running!")
		return
	#var id: int = steam_class.getSteamID()
	#var username: String = steam_class.getFriendPersonaName(id)


## Unlocks an achievement on Steam based on its [param achievement_name].
static func set_achievement(achievement_name: String) -> void:
	if achievements[achievement_name]:  # Return early if the achievement has already been achieved
		return
	if not is_instance_valid(steam_class):
		return
	if not steam_class.isSteamRunning():
		return
	var status: Dictionary = steam_class.getAchievement(achievement_name)
	if status["achieved"]:
		achievements[achievement_name] = true
		return
	steam_class.setAchievement(achievement_name)
	steam_class.storeStats()
	achievements[achievement_name] = true
