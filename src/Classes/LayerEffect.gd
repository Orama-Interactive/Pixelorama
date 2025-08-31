class_name LayerEffect
extends RefCounted

signal animated_changed(animated_state: bool)

const MAX_FRAME_INDEX := 9999999

var name := ""
var shader: Shader
var category := ""
var params := {}
var animated_params := {}
var animated_tween_params: Dictionary[String, Dictionary] = {}
var enabled := true
var animated := false:
	set(value):
		animated = value
		animated_changed.emit(animated)


func _init(_name := "", _shader: Shader = null, _category := "", _animated_params := {}) -> void:
	name = _name
	shader = _shader
	category = _category
	animated_params = _animated_params
	if not animated_params.has(0):
		animated_params[0] = {}


func duplicate() -> LayerEffect:
	return LayerEffect.new(name, shader, category, params.duplicate())


func get_params(frame_index: int) -> Dictionary:
	if not animated:
		return animated_params[0]
	if not animated_params.has(frame_index):
		if animated_params.size() == 1:
			return animated_params[0]
		var frame_edges := find_frame_edges(frame_index)
		var min_params: Dictionary = animated_params[frame_edges[0]]
		if frame_edges[1] >= MAX_FRAME_INDEX:
			return min_params
		var max_params: Dictionary = animated_params[frame_edges[1]]
		var interpolated_params := {}
		for param in animated_params[0]:
			if param.begins_with("PXO_"):
				continue
			if param not in min_params or param not in max_params:
				interpolated_params[param] = animated_params[0][param]
				continue
			var min_param = min_params[param]
			var max_param = max_params[param]
			if not is_interpolatable_type(min_param):
				interpolated_params[param] = animated_params[0][param]
				continue
			var elapsed := frame_index - frame_edges[0]
			var delta = max_param - min_param
			var duration := frame_edges[1] - frame_edges[0]
			var trans_type := Tween.TRANS_LINEAR
			var ease_type := Tween.EASE_IN
			if animated_tween_params.has(param):
				trans_type = animated_tween_params[param].get("trans_type", trans_type)
				ease_type = animated_tween_params[param].get("ease_type", ease_type)
			interpolated_params[param] = Tween.interpolate_value(
				min_param, delta, elapsed, duration, trans_type, ease_type
			)
		return interpolated_params
	return animated_params[frame_index]


func is_interpolatable_type(value: Variant) -> bool:
	var type := typeof(value)
	match type:
		TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_COLOR, TYPE_QUATERNION:
			return true
		_:
			return false


func find_frame_edges(frame_index: int) -> Array[int]:
	var param_keys := animated_params.keys()
	param_keys.sort()
	var minimum := 0
	var maximum := MAX_FRAME_INDEX
	for key in param_keys:
		if key > minimum and key <= frame_index:
			minimum = key
		if key < maximum and key >= frame_index:
			maximum = key
	return [minimum, maximum]


func serialize() -> Dictionary:
	var p_str := {}
	for param in params:
		p_str[param] = var_to_str(params[param])
	return {"name": name, "shader_path": shader.resource_path, "params": p_str, "enabled": enabled}


func deserialize(dict: Dictionary) -> void:
	if dict.has("name"):
		name = dict["name"]
	if dict.has("shader_path"):
		var path: String = dict["shader_path"]
		var shader_to_load := load(path)
		if is_instance_valid(shader_to_load) and shader_to_load is Shader:
			shader = shader_to_load
	if dict.has("params"):
		if typeof(dict["params"]) == TYPE_DICTIONARY:
			for param in dict["params"]:
				if typeof(dict["params"][param]) == TYPE_STRING:
					params[param] = str_to_var(dict["params"][param])
		else:
			params = str_to_var(dict["params"])
	if dict.has("enabled"):
		enabled = dict["enabled"]
	animated = dict.get("animated", animated)
