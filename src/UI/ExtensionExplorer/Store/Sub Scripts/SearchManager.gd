extends LineEdit

@onready var tag_list: VBoxContainer = $"%TagList"
var available_tags := PackedStringArray()

func _on_SearchManager_text_changed(new_text: String) -> void:
	tag_text_search()


func tag_text_search() -> void:
	var result = text_search(text)
	var tags = []
	for tag in tag_list.get_children():
		if tag.pressed:
			tags.append(tag.text)

	for entry in result:
		if !entry.tags_match(tags):
			entry.visible = false


func text_search(text: String) -> Array:
	var result = []
	for entry in $"%Content".get_children():
		var visibility = true
		if text != "":
			var extension_name = entry.ext_name.text
			var extension_description = entry.ext_discription.text
			if not text in extension_name:
				if not text in extension_description:
					visibility = false
		if visibility == true:
			result.append(entry)
		entry.visible = visibility
	return result


func add_new_tags(tag_array: Array):
	for tag in tag_array:
		if !tag in available_tags:
			available_tags.append(tag)
			var tag_checkbox = CheckBox.new()
			tag_checkbox.text = tag
			tag_list.add_child(tag_checkbox)
			tag_checkbox.connect("toggled", Callable(self, "start_tag_search"))


func start_tag_search(_pressed) -> void:
	tag_text_search()
