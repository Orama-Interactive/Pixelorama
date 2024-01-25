extends VBoxContainer

var custom_links := []


func _ready() -> void:
	custom_links = Global.config_cache.get_value("ExtensionExplorer", "custom_links", [])
	for link in custom_links:
		add_field(link)


func update_links() -> void:
	custom_links.clear()
	for child in $Links.get_children():
		if child.text != "":
			custom_links.append(child.text)
	Global.config_cache.set_value("ExtensionExplorer", "custom_links", custom_links)


func _on_NewLink_pressed() -> void:
	add_field()


func add_field(link := "") -> void:
	var link_field := LineEdit.new()
	# gdlint: ignore=max-line-length
	link_field.placeholder_text = "Paste Store link, given by the store owner (will automatically be removed if left empty)"
	link_field.text = link
	$Links.add_child(link_field)
	link_field.text_changed.connect(field_text_changed)


func field_text_changed(_text: String) -> void:
	update_links()


func _on_Options_visibility_changed() -> void:
	for child in $Links.get_children():
		if child.text == "":
			child.queue_free()


# Uncomment it when we have a proper guide for writing a store_info file
func _on_Guide_pressed() -> void:
	pass
# gdlint: ignore=max-line-length
#	OS.shell_open("https://github.com/Variable-Interactive/Variable-Store/tree/master#rules-for-writing-a-store_info-file")
