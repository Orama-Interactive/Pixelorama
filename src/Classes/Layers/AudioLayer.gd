class_name AudioLayer
extends BaseLayer

signal audio_changed

var audio: AudioStream:
	set(value):
		audio = value
		audio_changed.emit()
var playback_position := 0.0:  ## Measured in seconds.
	get():
		var frame := project.frames[playback_frame]
		return frame.position_in_seconds(project)
var playback_frame := 0


func _init(_project: Project, _name := "") -> void:
	project = _project
	name = _name


func get_audio_length() -> float:
	if is_instance_valid(audio):
		return audio.get_length()
	else:
		return -1.0


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
