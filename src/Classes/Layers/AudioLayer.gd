class_name AudioLayer
extends BaseLayer
## A unique type of layer which acts as an audio track for the timeline.
## Each audio layer has one audio stream, and its starting position can be
## in any point during the animation.

signal audio_changed
signal playback_frame_changed

var audio: AudioStream:  ## The audio stream of the layer.
	set(value):
		audio = value
		audio_changed.emit()
var playback_position := 0.0:  ## The time in seconds where the audio stream starts playing.
	get():
		if playback_frame >= 0:
			var frame := project.frames[playback_frame]
			return frame.position_in_seconds(project)
		var pos := 0.0
		for i in absi(playback_frame):
			pos -= 1.0 / project.fps
		return pos
var playback_frame := 0:  ## The frame where the audio stream starts playing.
	set(value):
		playback_frame = value
		playback_frame_changed.emit()


func _init(_project: Project, _name := "") -> void:
	project = _project
	name = _name


## Returns the length of the audio stream.
func get_audio_length() -> float:
	if is_instance_valid(audio):
		return audio.get_length()
	else:
		return -1.0


## Returns the class name of the audio stream. E.g. "AudioStreamMP3".
func get_audio_type() -> String:
	if not is_instance_valid(audio):
		return ""
	return audio.get_class()


# Overridden Methods:
func serialize() -> Dictionary:
	var data := {
		"name": name,
		"type": get_layer_type(),
		"playback_frame": playback_frame,
		"audio_type": get_audio_type()
	}
	return data


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	playback_frame = dict.get("playback_frame", playback_frame)


func get_layer_type() -> int:
	return Global.LayerTypes.AUDIO


func new_empty_cel() -> AudioCel:
	return AudioCel.new()


func set_name_to_default(number: int) -> void:
	name = tr("Audio") + " %s" % number
