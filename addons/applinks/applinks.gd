extends Node

signal data_received(data: String)

const CUSTOM_MANIFEST_ACTIVITY_ELEMENT := """
	<!-- Lospec‑palette deep link handler -->
	<intent-filter android:autoVerify="true">
		<action android:name="android.intent.action.VIEW"/>
		<category android:name="android.intent.category.DEFAULT"/>
		<category android:name="android.intent.category.BROWSABLE"/>
		<data android:scheme="lospec-palette"/>
	</intent-filter>

	<!-- Image & PXO files handler -->
	<intent-filter android:autoVerify="true">
		<action android:name="android.intent.action.VIEW"/>
		<category android:name="android.intent.category.DEFAULT"/>
		<category android:name="android.intent.category.BROWSABLE"/>
		<data android:scheme="file"/>
		<data android:scheme="content"/>
		<data android:mimeType="image/png"/>
		<data android:mimeType="image/jpeg"/>
		<data android:mimeType="image/webp"/>
		<data android:mimeType="image/gif"/>
		<data android:mimeType="application/x-pixelorama"/>
		<data android:pathPattern=".*\\.pxo"/>
	</intent-filter>
"""
const SINGLETON_NAME := "Applinks"
const PLUGIN_NAME := "applinks"

var applinks


func _ready() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		applinks = Engine.get_singleton(PLUGIN_NAME)
	elif OS.has_feature("android"):
		printerr("Couldn't find plugin " + PLUGIN_NAME)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and OS.has_feature("android"):
		var url := get_data()
		if not url.is_empty():
			data_received.emit(url)


func get_data() -> String:
	if applinks == null:
		printerr("Couldn't find plugin " + PLUGIN_NAME)
		return ""

	var data = applinks.getData()
	if data == null:
		return ""
	return data


func get_file_from_content_uri(uri: String) -> String:
	if applinks == null:
		printerr("Couldn't find plugin " + PLUGIN_NAME)
		return ""
	var data = applinks.getFileFromContentUri(uri)
	if data == null:
		return ""
	return data
