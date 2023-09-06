extends Window

### Usage:
### Change the and "STORE_LINK" from the (Main.gd)
### Don't touch anything else

const STORE_NAME :String = "Extension Explorer"
const store_information_file = STORE_NAME + ".txt"  # contains information about extensions available for download
const STORE_LINK: String = "https://raw.githubusercontent.com/Variable-Interactive/Variable-Store/4.0/store_info.txt"

# variables placed here due to their frequent use
var extension_container :VBoxContainer
var extension_path: String  # the base path where extensions will be stored (obtained from pixelorama)
var custom_links_remaining: int  # remaining custom links to be processed
var redirects :Array
var faulty_custom_links: Array

# node references
@onready var content: VBoxContainer = $"%Content"
@onready var store_info_downloader = $StoreInformationDownloader


func _ready() -> void:
	# Basic setup
	extension_container = Global.preferences_dialog.find_child("Extensions")
	$"%MainStore".text = STORE_LINK
	# Get the path that pixelorama uses to store extensions
	extension_path = ProjectSettings.globalize_path(extension_container.EXTENSIONS_PATH)
	# tell the downloader where to download the store information
	store_info_downloader.download_file = extension_path.path_join(store_information_file)


func _on_Store_about_to_show() -> void:
	# clear old tags
	$"%SearchManager".available_tags = PackedStringArray()
	for tag in $"%SearchManager".tag_list.get_children():
		tag.queue_free()
	#Clear old entries
	for entry in content.get_children():
		entry.queue_free()
	faulty_custom_links.clear()
	custom_links_remaining = $"%CustomStoreLinks".custom_links.size()
	fetch_info(STORE_LINK)


func _on_close_requested() -> void:
	hide()


func fetch_info(link: String) -> void:
	if extension_path != "":  # Did everything went smoothly in _ready() function?
		# everything is ready, now request the store information
		# so that available extensions could be displayed
		var error = store_info_downloader.request(link)
		if error == OK:
			prepare_progress()
		else:
			printerr("Unable to Get info from remote repository...")
			error_getting_info(error)


# If downloading is completed
func _on_StoreInformation_request_completed(result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS:
		# process the info contained in the file
		var file = FileAccess.open(extension_path.path_join(store_information_file), FileAccess.READ)
		while not file.eof_reached():
			var info = str_to_var(file.get_line())
			if typeof(info) == TYPE_ARRAY:
				add_entry(info)
			elif typeof(info) == TYPE_STRING:  # redirect store_link detected
				var link: String = info.strip_edges()
				if !link.begins_with("#") and link != "":
					if !info in redirects:
						redirects.append(info)
		file.close()
		DirAccess.remove_absolute(extension_path.path_join(store_information_file))
		# Hide the progress bar because it's no longer required
		close_progress()
	else:
		printerr("Unable to Get info from remote repository...")
		error_getting_info(result)


################# HELPER METHODS #################

# SIGNAL CONNECTED FROM StoreButton.tscn
func _on_explore_pressed() -> void:
	popup_centered()


# FUNCTION RELATED TO ERROR DIALOG
func _on_CopyCommand_pressed():
	DisplayServer.clipboard_set("sudo flatpak override com.orama_interactive.Pixelorama --share=network")


# FUNCTION RELATED TO ERROR DIALOG
func _on_ManualDownload_pressed():
	# warning-ignore:return_value_discarded
	OS.shell_open("https://variable-interactive.itch.io/pixelorama-extensions")


# ADDS A NEW EXTENSION ENTRY TO THE "content"
func add_entry(info: Array) -> void:
	var entry = preload("res://src/UI/ExtensionExplorer/Entry/Entry.tscn").instantiate()
	entry.connect("tags_detected", Callable($"%SearchManager", "add_new_tags"))
	entry.extension_container = extension_container
	content.add_child(entry)
	entry.set_info(info, extension_path)


# GETS CALLED WHEN DATA COULDN'T BE FETCHED FROM REMOTE REPOSITORY
func error_getting_info(result: int) -> void:
	# Shows a popup if error is from main link (i-e MainStore)
	# Popups for errors in custom_links are handled in close_progress()
	if custom_links_remaining == $"%CustomStoreLinks".custom_links.size():
		$Error.popup_centered()
		$Error.title = error_string(result)
	else:
		faulty_custom_links.append($"%CustomStoreLinks".custom_links[custom_links_remaining])
	close_progress()


# PROGRESS BAR METHOD
func prepare_progress():
	$ProgressContainer.visible = true
	$TabContainer.visible = false
	$ProgressContainer/ProgressBar.value = 0
	$ProgressContainer/UpdateTimer.start()


# PROGRESS BAR METHOD
func update_progress():
	var down = store_info_downloader.get_downloaded_bytes()
	var total = store_info_downloader.get_body_size()
	$ProgressContainer/ProgressBar.value = (float(down) / float(total)) * 100.0


func close_progress():
	$ProgressContainer.visible = false
	$TabContainer.visible = true
	$ProgressContainer/UpdateTimer.stop()
	if redirects.size() > 0:
		var next_link = redirects.pop_front()
		fetch_info(next_link)
	else:
		# no more redirects, jump to the next store
		custom_links_remaining -= 1
		if custom_links_remaining >= 0:
			var next_link = $"%CustomStoreLinks".custom_links[custom_links_remaining]
			fetch_info(next_link)
		else:
			if faulty_custom_links.size() > 0:  # manage custom faulty links
				$"%FaultyLinks".text = ""
				for link in faulty_custom_links:
					$"%FaultyLinks".text += str(link, "\n")
				$ErrorCustom.popup_centered()



# PROGRESS BAR METHOD
func _on_UpdateTimer_timeout():
	update_progress()
