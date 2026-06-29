class_name AnimatableObject
extends RefCounted

signal keyframe_set

const TRANS_CONSTANT := -1

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

## Inspired from [method Object.get_property_list], optionally contains extra properties
## for parameters, that work as hints so that the editor knows which UI elements to use.
## For example, a parameter that is an integer may need to be displayed as an OptionButton
## because it works as an enumerator.
## Example:
## [codeblock]
##{
##	"brush":
##	{
##		"hint": PROPERTY_HINT_ENUM,
##		"hint_string": "Diamond,Circle,Square",
##	},
##}
## [/codeblock]
var param_properties: Dictionary[String, Dictionary]


## Returns the interpolated valued of all the properties present in [member animated_params] for the
## frame at [param frame_index].
func get_params(frame_index: int) -> Dictionary:
	var to_return := params.duplicate()  # Start with default values
	for param in animated_params:
		if param.begins_with("PXO_"):
			continue
		to_return[param] = get_animated_property(frame_index, param)
	return to_return


## Compact form of [method get_params]. Returns the interpolated value of the [param param] for the
## [param frame_index] or [code]null[/code] if [param param] is not valid, i-e not registered
## in the [member params] dictionary.
func get_animated_property(frame_index: int, param: String) -> Variant:
	# Check if the param is valid.
	if not params.has(param):
		return  # null return
	# Check if the property is animatable, return default value if not animatable
	if (
		param.begins_with("PXO_")
		or not animated_params.has(param)
		or not is_animatable_type(params[param])
	):
		return params[param]

	# Get the keyframe info for our param.
	var properties := animated_params[param]  # Dictionary[int, Dictionary]
	if properties.size() == 0:
		return params[param]  # No Keyframes present, return default value

	if properties.has(frame_index):
		# If the currect frame is a keyframe then there is no reason to
		# interpolate. Get value directly from properties
		return properties[frame_index].get("value", params[param])
	else:
		# If it doesn't exist, interpolate.
		var frame_edges := find_frame_edges(frame_index, properties)
		var min_params: Dictionary = properties[frame_edges[0]]
		var max_params: Dictionary = properties[frame_edges[1]]
		var min_value = min_params.get("value", params[param])
		var max_value = max_params.get("value", params[param])
		if not is_interpolatable_type(min_value):
			# NOTE: Examples that trigger this are the Desaturation effect and Kernel of
			# Convolution matrix effect. Here, we just take the interpolation as TRANS_CONSTANT.
			return min_value
		var elapsed := frame_index - frame_edges[0]
		var delta = max_value - min_value
		var duration := frame_edges[1] - frame_edges[0]
		var trans_type: int = min_params.get("trans", Tween.TRANS_LINEAR)
		if trans_type == TRANS_CONSTANT:
			return min_value
		var ease_type: Tween.EaseType = min_params.get("ease", Tween.EASE_IN)
		return Tween.interpolate_value(
			min_value, delta, elapsed, duration, trans_type, ease_type
		)


func set_keyframe(
	param_name: String,
	frame_index: int,
	value: Variant = get_params(frame_index)[param_name],
	trans := Tween.TRANS_LINEAR,
	ease_type := Tween.EASE_IN
) -> void:
	if not animated_params.has(param_name):
		animated_params[param_name] = {}
	var id := KeyframeTimeline.next_keyframe_id
	animated_params[param_name][frame_index] = {
		"id": id, "value": value, "trans": trans, "ease": ease_type
	}
	KeyframeTimeline.next_keyframe_id += 1
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


static func find_frame_edges(frame_index: int, animated_properties: Dictionary) -> Array[int]:
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
