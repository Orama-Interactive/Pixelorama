class_name KeyframeTimeline
extends Control

var current_layer: BaseLayer:
	set(value):
		if is_instance_valid(current_layer):
			if current_layer.effects_added_removed.is_connected(_recreate_timeline):
				current_layer.effects_added_removed.disconnect(_recreate_timeline)
		current_layer = value
		_recreate_timeline()
		current_layer.effects_added_removed.connect(_recreate_timeline)
static var frame_ui_size := 50

@onready var layer_element_container: VBoxContainer = $LayerElementContainer
@onready var layer_element_spacer: Control = $LayerElementContainer/LayerElementSpacer
@onready var track_container: VBoxContainer = $TrackContainer
@onready var frames_container: HBoxContainer = $TrackContainer/FramesContainer


func _ready() -> void:
	Global.project_about_to_switch.connect(_on_project_about_to_switch)
	Global.project_switched.connect(_on_project_switched)
	Global.cel_switched.connect(_on_cel_switched)
	await get_tree().process_frame
	var project := Global.current_project
	current_layer = project.layers[project.current_layer]
	_add_ui_frames()


func _on_cel_switched() -> void:
	var project := Global.current_project
	var layer := project.layers[project.current_layer]
	if layer == current_layer:
		return
	current_layer = layer


func _on_project_about_to_switch() -> void:
	var project := Global.current_project
	project.frames_updated.disconnect(_add_ui_frames)


func _on_project_switched() -> void:
	var project := Global.current_project
	if not project.frames_updated.is_connected(_add_ui_frames):
		project.frames_updated.connect(_add_ui_frames)


func _recreate_timeline() -> void:
	for child in layer_element_container.get_children():
		if child == layer_element_spacer:
			continue
		child.queue_free()
	for child in track_container.get_children():
		if child == frames_container:
			continue
		child.queue_free()
	# Await is needed so that the params get added to the layer effect.
	await get_tree().process_frame
	for effect in current_layer.effects:
		var label := Label.new()
		label.text = effect.name
		layer_element_container.add_child(label)
		var track := KeyframeAnimationTrack.new()
		track.custom_minimum_size.y = label.size.y
		track_container.add_child(track)
		for param in effect.animated_params[0]:
			if param in ["PXO_time", "PXO_frame_index", "PXO_layer_index"]:
				continue
			var param_label := Label.new()
			param_label.text = "\t " + param
			layer_element_container.add_child(param_label)
			var param_track := KeyframeAnimationTrack.new()
			param_track.effect = effect
			param_track.param_name = param
			param_track.is_property = true
			param_track.custom_minimum_size.y = param_label.size.y
			track_container.add_child(param_track)
			for frame_index in effect.animated_params:
				var keyframe := Button.new()
				keyframe.position.x = frame_index * frame_ui_size
				keyframe.position.y = param_track.custom_minimum_size.y / 2
				param_track.add_child(keyframe)


func _add_ui_frames() -> void:
	for child in frames_container.get_children():
		child.queue_free()
	var project := Global.current_project
	for i in project.frames.size():
		var frame_label := Label.new()
		#frame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		frame_label.text = str(i + 1)
		frame_label.custom_minimum_size.x = frame_ui_size
		frames_container.add_child(frame_label)
	layer_element_spacer.custom_minimum_size.y = frames_container.size.y
