class_name NoiseGenerator
extends ScrollContainer

signal value_changed(noise_texture: NoiseTexture2D)

var noise_texture: NoiseTexture2D:
	set(value):
		noise_texture = value
		if not is_instance_valid(noise_texture.noise):
			noise_texture.noise = FastNoiseLite.new()
		if not is_instance_valid(preview):
			await ready
		preview.texture = noise_texture
		_set_node_values()

@onready var preview := %Preview as TextureRect
@onready var size_slider := %SizeSlider as ValueSliderV2
@onready var properties := {
	"invert": %InvertCheckBox,
	"in_3d_space": %In3DSpaceCheckBox,
	"seamless": %SeamlessCheckBox,
	"as_normal_map": %NormalMapCheckBox,
	"normalize": %NormalizeCheckBox,
	"color_ramp": %ColorRampEdit,
	"noise:noise_type": %NoiseTypeOptionButton,
	"noise:seed": %SeedSlider,
	"noise:frequency": %FrequencySlider,
	"noise:offset": %OffsetSlider,
	"noise:fractal_type": %FractalTypeOptionButton,
	"noise:fractal_octaves": %FractalOctavesSlider,
	"noise:fractal_lacunarity": %FractalLacunaritySlider,
	"noise:fractal_gain": %FractalGainSlider,
	"noise:fractal_weighted_strength": %FractalWeightedStrengthSlider,
	"noise:domain_warp_enabled": %DomainWarpEnabledCheckBox,
	"noise:domain_warp_type": %DomainWarpTypeOptionButton,
	"noise:domain_warp_amplitude": %DomainWarpAmplitudeSlider,
	"noise:domain_warp_frequency": %DomainWarpFrequencySlider,
	"noise:domain_warp_fractal_type": %DomainWarpFractalTypeOptionButton,
	"noise:domain_warp_fractal_octaves": %DomainWarpFractalOctavesSlider,
	"noise:domain_warp_fractal_lacunarity": %DomainWarpFractalLacunaritySlider,
	"noise:domain_warp_fractal_gain": %DomainWarpFractalGainSlider
}


func _init() -> void:
	noise_texture = NoiseTexture2D.new()


func _ready() -> void:
	# Connect the signals of the object property nodes
	for prop in properties:
		var node: Control = properties[prop]
		if node is ValueSliderV3:
			node.value_changed.connect(_property_vector3_changed.bind(prop))
		elif node is ValueSliderV2:
			var property_path: String = prop
			node.value_changed.connect(_property_vector2_changed.bind(property_path))
		elif node is Range:
			node.value_changed.connect(_property_value_changed.bind(prop))
		elif node is OptionButton:
			node.item_selected.connect(_property_item_selected.bind(prop))
		elif node is CheckBox:
			node.toggled.connect(_property_toggled.bind(prop))
		elif node is GradientEditNode:
			node.updated.connect(_property_gradient_changed.bind(prop))


func _set_node_values() -> void:
	size_slider.value.x = noise_texture.width
	size_slider.value.y = noise_texture.height
	for prop in properties:
		var property_path: String = prop
		var value = noise_texture.get_indexed(property_path)
		if value == null:
			continue
		var node: Control = properties[prop]
		if node is Range or node is ValueSliderV3 or node is ValueSliderV2:
			if typeof(node.value) != typeof(value) and typeof(value) != TYPE_INT:
				continue
			node.value = value
		elif node is OptionButton:
			node.selected = value
		elif node is CheckBox:
			node.button_pressed = value
		elif node is GradientEditNode:
			var gradient_tex := GradientTexture2D.new()
			gradient_tex.gradient = value
			node.set_gradient_texture(gradient_tex)


func _set_value_from_node(value, prop: String) -> void:
	noise_texture.set_indexed(prop, value)
	await noise_texture.changed
	value_changed.emit(noise_texture)


func _property_vector3_changed(value: Vector3, prop: String) -> void:
	_set_value_from_node(value, prop)


func _property_vector2_changed(value: Vector2, prop: String) -> void:
	_set_value_from_node(value, prop)


func _property_value_changed(value: float, prop: String) -> void:
	_set_value_from_node(value, prop)


func _property_item_selected(value: int, prop: String) -> void:
	_set_value_from_node(value, prop)


func _property_gradient_changed(value: Gradient, _cc: bool, prop: String) -> void:
	_set_value_from_node(value, prop)


func _property_toggled(value: bool, prop: String) -> void:
	_set_value_from_node(value, prop)


func _on_size_slider_value_changed(value: Vector2) -> void:
	noise_texture.width = value.x
	noise_texture.height = value.y
	await noise_texture.changed
	value_changed.emit(noise_texture)
