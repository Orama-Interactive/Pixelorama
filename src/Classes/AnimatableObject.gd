class_name AnimatableObject
extends RefCounted

signal keyframe_set

## A Dictionary containing another Dictionary that
## maps the frame indices (int) to another Dictionary of value, trans, ease,
## and a layer-scope unique ID.
## Example:
## [codeblock]
##{
##	"offset":
##	{
##		0: {id: 0, "value": Vector2(0, 0), "trans": 0, "ease": 2},
##		10: {id: 1, "value": Vector2(64, 64), "trans": 1, "ease": 3},
##	},
##	"wrap_around":
##	{
##		1: {id: 2, "value": false, "trans": 0, "ease": 0},
##		3: {id: 3, "value": true, "trans": 0, "ease": 0},
##		10: {id: 4, "value": false, "trans": 0, "ease": 0},
##	},
##}
## [/codeblock]
var animated_params: Dictionary[String, Dictionary] = {}

## These are the default values for the animation calculator to fall back on when a keyframe is
## not found.
## Example:
## [codeblock]
##{
##	"offset": Vector2(0, 0),
##	"wrap_around": false,
##}
## [/codeblock]
var params: Dictionary[String, Variant] = {}


func get_params(frame_index: int) -> Dictionary:
	var to_return := params.duplicate()
	for param in animated_params:
		var value = get_param(param, frame_index)
		if value:
			to_return[param] = value
	return to_return


func get_param(param_name: String, frame_index: int, default = null) -> Variant:
	var to_return := params.duplicate()
	if param_name.begins_with("PXO_"):
		return default
	if not animated_params.has(param_name):
		if params.has(param_name):
			return params[param_name]
		else:
			return default
	var animated_properties := animated_params[param_name]  # Dictionary[int, Dictionary]
	if animated_properties.has(frame_index):
		# If the frame index exists in the properties, get that.
		return animated_properties[frame_index].get("value", to_return[param_name])
	else:
		if animated_properties.size() == 0:
			return default
		# If it doesn't exist, interpolate.
		var frame_edges := find_frame_edges(frame_index, animated_properties)
		var min_params: Dictionary = animated_properties[frame_edges[0]]
		var max_params: Dictionary = animated_properties[frame_edges[1]]
		var min_value = min_params.get("value", to_return[param_name])
		var max_value = max_params.get("value", to_return[param_name])
		if not is_interpolatable_type(min_value):
			return max_value
		var elapsed := frame_index - frame_edges[0]
		var delta = max_value - min_value
		var duration := frame_edges[1] - frame_edges[0]
		var trans_type: int = min_params.get("trans", Tween.TRANS_LINEAR)
		if trans_type == Tween.TRANS_SPRING + 1:
			return min_value
		var ease_type: Tween.EaseType = min_params.get("ease", Tween.EASE_IN)
		return Tween.interpolate_value(
			min_value, delta, elapsed, duration, trans_type, ease_type
		)


func set_keyframe(
	param_name: String,
	frame_index: int,
	value: Variant = params[param_name],
	trans := Tween.TRANS_LINEAR,
	ease_type := Tween.EASE_IN
) -> void:
	if not animated_params.has(param_name):
		animated_params[param_name] = {}
	animated_params[param_name][frame_index] = {"value": value, "trans": trans, "ease": ease_type}
	keyframe_set.emit()


func unset_keyframe(
	param_name: String,
	frame_index: int
) -> void:
	if animated_params.has(param_name):
		animated_params[param_name].erase(frame_index)


static func is_interpolatable_type(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I:
			return true
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_COLOR, TYPE_QUATERNION:
			return true
		_:
			return false


static func is_animatable_type(value: Variant) -> bool:
	if is_interpolatable_type(value):
		return true
	match typeof(value):
		TYPE_BOOL, TYPE_BASIS:
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
		"params": var_to_str(params),
		"animated_params": var_to_str(animated_params),
	}


func deserialize(dict: Dictionary) -> void:
	if dict.has("params"):
		if typeof(dict["params"]) == TYPE_DICTIONARY:
			for param in dict["params"]:
				if typeof(dict["params"][param]) == TYPE_STRING:
					params[param] = str_to_var(dict["params"][param])
		else:
			params = str_to_var(dict["params"])
	if dict.has("animated_params"):
		animated_params = str_to_var(dict["animated_params"])
