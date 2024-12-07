class_name AudioLayer
extends BaseLayer

signal audio_changed

var audio: AudioStream:
	set(value):
		audio = value
		audio_changed.emit()


func _init(_project: Project, _name := "") -> void:
	project = _project
	name = _name


# Overridden Methods:
func serialize() -> Dictionary:
	var data := {"name": name, "type": get_layer_type()}
	return data


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)


func get_layer_type() -> int:
	return Global.LayerTypes.AUDIO


func new_empty_cel() -> AudioCel:
	return AudioCel.new()


func set_name_to_default(number: int) -> void:
	name = tr("Audio track") + " %s" % number
