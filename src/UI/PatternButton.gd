extends BaseButton


var pattern := Patterns.Pattern.new()


func _on_PatternButton_pressed() -> void:
	Global.patterns_popup.select_pattern(pattern)
