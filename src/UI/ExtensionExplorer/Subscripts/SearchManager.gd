extends LineEdit

var available_tags := PackedStringArray()
@onready var tag_list: VBoxContainer = $"%TagList"


func _on_SearchManager_text_changed(_new_text: String) -> void:
	tag_text_search()


func tag_text_search() -> void:
	var result := text_search(text)
	var tags := PackedStringArray([])
	for tag: Button in tag_list.get_children():
		if tag.button_pressed:
			tags.append(tag.text)

	for entry in result:
		if !entry.tags_match(tags):
			entry.visible = false


func text_search(text_to_search: String) -> Array[ExtensionEntry]:
	var result: Array[ExtensionEntry] = []
	for entry: ExtensionEntry in $"%Content".get_children():
		var visibility := true
		if text_to_search != "":
			var extension_name := entry.ext_name.text.to_lower()
			var extension_description := entry.ext_discription.text.to_lower()
			if not text_to_search.to_lower() in extension_name:
				if not text_to_search.to_lower() in extension_description:
					visibility = false
		if visibility == true:
			result.append(entry)
		entry.visible = visibility
	return result


func add_new_tags(tag_array: PackedStringArray) -> void:
	for tag in tag_array:
		if !tag in available_tags:
			available_tags.append(tag)
			var tag_checkbox := CheckBox.new()
			tag_checkbox.text = tag
			tag_list.add_child(tag_checkbox)
			tag_checkbox.toggled.connect(start_tag_search)


func start_tag_search(_button_pressed: bool) -> void:
	tag_text_search()
