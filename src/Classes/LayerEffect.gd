class_name LayerEffect
extends RefCounted

var name := ""
var shader: Shader
var category := ""
var params := {}
var enabled := true


func _init(_name := "", _shader: Shader = null, _category := "", _params := {}) -> void:
	name = _name
	shader = _shader
	category = _category
	params = _params


func duplicate() -> LayerEffect:
	return LayerEffect.new(name, shader, category, params.duplicate())


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
		for param in dict["params"]:
			if typeof(dict["params"][param]) == TYPE_STRING:
				dict["params"][param] = str_to_var(dict["params"][param])
		params = dict["params"]
	if dict.has("enabled"):
		enabled = dict["enabled"]
