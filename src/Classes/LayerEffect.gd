class_name LayerEffect
extends AnimatableObject

var name := ""
var shader: Shader:
	set(value):
		shader = value
		_set_params_from_shader()
var layer: BaseLayer
var category := ""
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


func serialize() -> Dictionary:
	return (
		{
			"name": name,
			"shader_path": shader.resource_path,
			"enabled": enabled,
		}
		. merged(super())
	)


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
	super(dict)


func _set_params_from_shader() -> void:
	if not is_instance_valid(shader):
		return
	var uniforms := shader.get_shader_uniform_list()
	for uniform in uniforms:
		var u_name := uniform["name"] as String
		param_properties[u_name] = uniform
