@tool
extends EditorPlugin

const APPLINKS_SCRIPT_PATH := "res://addons/applinks/applinks.gd"
const APPLINKS_SCRIPT := preload(APPLINKS_SCRIPT_PATH)

# A class member to hold the editor export plugin during its lifecycle.
var export_plugin: AndroidExportPlugin


class AndroidExportPlugin:
	extends EditorExportPlugin
	var _plugin_name := "applinks"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		if platform is EditorExportPlatformAndroid:
			return true
		return false

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray([_plugin_name + "/bin/debug/" + _plugin_name + "-debug.aar"])
		else:
			return PackedStringArray(
				[_plugin_name + "/bin/release/" + _plugin_name + "-release.aar"]
			)

	func _get_android_manifest_activity_element_contents(
		_platform: EditorExportPlatform, _debug: bool
	) -> String:
		return APPLINKS_SCRIPT.CUSTOM_MANIFEST_ACTIVITY_ELEMENT

	func _get_name() -> String:
		return APPLINKS_SCRIPT.PLUGIN_NAME


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)
	add_autoload_singleton(APPLINKS_SCRIPT.SINGLETON_NAME, APPLINKS_SCRIPT_PATH)


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	remove_autoload_singleton(APPLINKS_SCRIPT.SINGLETON_NAME)
	remove_export_plugin(export_plugin)
	export_plugin = null
