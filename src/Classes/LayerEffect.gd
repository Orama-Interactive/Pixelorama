class_name LayerEffect
extends RefCounted

signal keyframe_set

var name := ""
var shader: Shader
var layer: BaseLayer
var category := ""
var params: Dictionary[String, Variant] = {}
## A Dictionary containing another Dictionary that
## maps the frame indices (int) to another Dictionary of value, trans and ease.
## Example:
## [codeblock]
##{"offset":
##	{
##		0: {id: 0, "value": Vector2(0, 0), "trans": 0, "ease": 2},
##		10: {id: 1, "value": Vector2(64, 64), "trans": 1, "ease": 3},
##	}
##}
## [/codeblock]
var animated_params: Dictionary[String, Dictionary] = {}
var enabled := true


func _init(
	_name := "", _shader: Shader = null, _category := "", _params: Dictionary[String, Variant] = {}
) -> void:
	name = _name
	shader = _shader
	category = _category
	params = _params


func duplicate() -> LayerEffect:
	return LayerEffect.new(name, shader, category, params.duplicate())


func get_params(frame_index: int) -> Dictionary:
	var to_return := params.duplicate()
	for param in animated_params:
		if param.begins_with("PXO_"):
			continue
		var animated_properties := animated_params[param]  # Dictionary[int, Dictionary]
		if animated_properties.has(frame_index):
			# If the frame index exists in the properties, get that.
			to_return[param] = animated_properties[frame_index].get("value", to_return[param])
		else:
			if animated_properties.size() == 0:
				continue
			# If it doesn't exist, interpolate.
			var frame_edges := find_frame_edges(frame_index, animated_properties)
			var min_params: Dictionary = animated_properties[frame_edges[0]]
			var max_params: Dictionary = animated_properties[frame_edges[1]]
			var min_value = min_params.get("value", to_return[param])
			var max_value = max_params.get("value", to_return[param])
			if not is_interpolatable_type(min_value):
				to_return[param] = max_value
				continue
			var elapsed := frame_index - frame_edges[0]
			var delta = max_value - min_value
			var duration := frame_edges[1] - frame_edges[0]
			var trans_type: int = min_params.get("trans", Tween.TRANS_LINEAR)
			if trans_type == Tween.TRANS_SPRING + 1:
				to_return[param] = min_value
				continue
			var ease_type: Tween.EaseType = min_params.get("ease", Tween.EASE_IN)
			to_return[param] = Tween.interpolate_value(
				min_value, delta, elapsed, duration, trans_type, ease_type
			)
	return to_return


func set_keyframe(
	param_name: String,
	frame_index: int,
	value: Variant = params[param_name],
	trans := Tween.TRANS_LINEAR,
	ease_type := Tween.EASE_IN
) -> void:
	if not animated_params.has(param_name):
		animated_params[param_name] = {}
	var id := layer.next_keyframe_id
	animated_params[param_name][frame_index] = {
		"id": id, "value": value, "trans": trans, "ease": ease_type
	}
	layer.next_keyframe_id += 1
	keyframe_set.emit()


func is_interpolatable_type(value: Variant) -> bool:
	var type := typeof(value)
	match type:
		TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I:
			return true
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_COLOR, TYPE_QUATERNION:
			return true
		_:
			return false


func find_frame_edges(frame_index: int, animated_properties: Dictionary) -> Array[int]:
	var param_keys := animated_properties.keys()
	if param_keys.size() == 1:
		return [param_keys[0], param_keys[0]]
	param_keys.sort()
	var minimum: int = param_keys[0]
	var maximum: int = param_keys[-1]
	for key in param_keys:
		if key > minimum and key <= frame_index:
			minimum = key
		if key < maximum and key >= frame_index:
			maximum = key
	return [minimum, maximum]


func serialize() -> Dictionary:
	return {
		"name": name,
		"shader_path": shader.resource_path,
		"enabled": enabled,
		"params": var_to_str(params),
		"animated_params": var_to_str(animated_params),
	}


func deserialize(dict: Dictionary) -> void:
	if dict.has("name"):
		name = dict["name"]
	if dict.has("shader_path"):
		var path: String = dict["shader_path"]
		var shader_to_load := load(path)
		if is_instance_valid(shader_to_load) and shader_to_load is Shader:
			shader = shader_to_load
	if dict.has("enabled"):
		enabled = dict["enabled"]
	if dict.has("params"):
		if typeof(dict["params"]) == TYPE_DICTIONARY:
			for param in dict["params"]:
				if typeof(dict["params"][param]) == TYPE_STRING:
					params[param] = str_to_var(dict["params"][param])
		else:
			params = str_to_var(dict["params"])
	if dict.has("animated_params"):
		animated_params = str_to_var(dict["animated_params"])
