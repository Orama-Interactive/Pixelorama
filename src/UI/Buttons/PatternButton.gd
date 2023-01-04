extends BaseButton

var pattern = Global.patterns_popup.Pattern.new()


func _on_PatternButton_pressed() -> void:
	Global.patterns_popup.select_pattern(pattern)
