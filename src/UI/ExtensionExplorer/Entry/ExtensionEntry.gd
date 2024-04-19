class_name ExtensionEntry
extends Panel

var thumbnail := ""
var download_link := ""
var download_path := ""
var tags := PackedStringArray()
var is_update := false  ## An update instead of download

# node references used in this script
@onready var extensions := Global.control.get_node("Extensions") as Extensions
@onready var ext_name := %ExtensionName as Label
@onready var ext_discription := %ExtensionDescription as TextEdit
@onready var small_picture := %Picture as TextureButton
@onready var enlarged_picture := %Enlarged as TextureRect
@onready var request_delay := %RequestDelay as Timer
@onready var thumbnail_request := %ImageRequest as HTTPRequest
@onready var extension_downloader := %DownloadRequest as HTTPRequest
@onready var down_button := %DownloadButton as Button
@onready var progress_bar := %ProgressBar as ProgressBar
@onready var done_label := %Done as Label
@onready var alert_dialog := %Alert as AcceptDialog


func set_info(info: Dictionary, extension_path: String) -> void:
	if "name" in info.keys() and "version" in info.keys():
		ext_name.text = str(info["name"], "-v", info["version"])
		# check for updates
		change_button_if_updatable(info["name"], info["version"])
		# Setting path extension will be "temporarily" downloaded to before install
		DirAccess.make_dir_recursive_absolute(str(extension_path, "Download/"))
		download_path = str(extension_path, "Download/", info["name"], ".pck")
	if "description" in info.keys():
		ext_discription.text = info["description"]
		ext_discription.tooltip_text = ext_discription.text
	if "thumbnail" in info.keys():
		thumbnail = info["thumbnail"]
	if "download_link" in info.keys():
		download_link = info["download_link"]
	if "tags" in info.keys():
		tags.append_array(info["tags"])

	# Adding a tiny delay to prevent sending bulk requests
	request_delay.wait_time = randf() * 2
	request_delay.start()


func _on_RequestDelay_timeout() -> void:
	request_delay.queue_free()  # node no longer needed
	if not thumbnail.is_empty():
		thumbnail_request.request(thumbnail)  # image


func _on_ImageRequest_request_completed(
	_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	# Update the received image
	thumbnail_request.queue_free()
	var image := Image.new()
	# for images on internet there is a hagh chance that extension is wrong
	# so check all of them even if they give error
	var err := image.load_png_from_buffer(body)
	if err != OK:
		var err_a := image.load_jpg_from_buffer(body)
		if err_a != OK:
			var err_b := image.load_webp_from_buffer(body)
			if err_b != OK:
				var err_c := image.load_tga_from_buffer(body)
				if err_c != OK:
					image.load_bmp_from_buffer(body)
	var texture := ImageTexture.create_from_image(image)
	small_picture.texture_normal = texture
	small_picture.pressed.connect(enlarge_thumbnail.bind(texture))


func _on_Download_pressed() -> void:
	down_button.disabled = true
	extension_downloader.download_file = download_path
	extension_downloader.request(download_link)
	prepare_progress()


## Called after the extension downloader has finished its job
func _on_DownloadRequest_request_completed(
	result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray
) -> void:
	if result == HTTPRequest.RESULT_SUCCESS:
		# Add extension
		extensions.install_extension(download_path)
		if is_update:
			is_update = false
		announce_done(true)
	else:
		alert_dialog.get_node("Text").text = (
			str(
				"Unable to download extension.\nHttp Code: ",
				result,
				" (",
				error_string(result),
				")"
			)
			. c_unescape()
		)
		alert_dialog.popup_centered()
		announce_done(false)
	DirAccess.remove_absolute(download_path)


## Updates the entry node's UI
func announce_done(success: bool) -> void:
	close_progress()
	down_button.disabled = false
	if success:
		done_label.visible = true
		down_button.text = "Redownload"
		done_label.get_node("DoneDelay").start()


## Returns true if entry contains ALL tags in tag_array
func tags_match(tag_array: PackedStringArray) -> bool:
	if tags.size() > 0:
		for tag in tag_array:
			if !tag in tags:
				return false
		return true
	else:
		if tag_array.size() > 0:
			return false
		return true


## Updates the entry node's UI if it has an update available
func change_button_if_updatable(extension_name: String, new_version: float) -> void:
	for extension in extensions.extensions.keys():
		if extensions.extensions[extension].file_name == extension_name:
			var old_version = str_to_var(extensions.extensions[extension].version)
			if typeof(old_version) == TYPE_FLOAT:
				if new_version > old_version:
					down_button.text = "Update"
					is_update = true
				elif new_version == old_version:
					down_button.text = "Redownload"


## Show an enlarged version of the thumbnail
func enlarge_thumbnail(texture: ImageTexture) -> void:
	enlarged_picture.texture = texture
	enlarged_picture.get_parent().popup_centered()


## A beautification function that hides the "Done" label bar after some time
func _on_DoneDelay_timeout() -> void:
	done_label.visible = false


## Progress bar method
func prepare_progress() -> void:
	progress_bar.visible = true
	progress_bar.value = 0
	progress_bar.get_node("ProgressTimer").start()


## Progress bar method
func update_progress() -> void:
	var down := extension_downloader.get_downloaded_bytes()
	var total := extension_downloader.get_body_size()
	progress_bar.value = (float(down) / float(total)) * 100.0


## Progress bar method
func close_progress() -> void:
	progress_bar.visible = false
	progress_bar.get_node("ProgressTimer").stop()


## Progress bar method
func _on_ProgressTimer_timeout() -> void:
	update_progress()


func _manage_enlarded_thumbnail_close() -> void:
	enlarged_picture.get_parent().hide()


func _manage_alert_close() -> void:
	alert_dialog.hide()
