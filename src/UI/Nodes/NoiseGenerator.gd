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
@onready var preview := %Preview as TextureRect


func _init() -> void:
	noise_texture = NoiseTexture2D.new()


func _on_size_slider_value_changed(value: Vector2) -> void:
	noise_texture.width = value.x
	noise_texture.height = value.y
	value_changed.emit(noise_texture)


func _on_invert_check_box_toggled(toggled_on: bool) -> void:
	noise_texture.invert = toggled_on
	value_changed.emit(noise_texture)


func _on_in_3d_space_check_box_toggled(toggled_on: bool) -> void:
	noise_texture.in_3d_space = toggled_on
	value_changed.emit(noise_texture)


func _on_seamless_check_box_toggled(toggled_on: bool) -> void:
	noise_texture.seamless = toggled_on
	value_changed.emit(noise_texture)


func _on_normal_map_check_box_toggled(toggled_on: bool) -> void:
	noise_texture.as_normal_map = toggled_on
	value_changed.emit(noise_texture)


func _on_normalize_check_box_toggled(toggled_on: bool) -> void:
	noise_texture.normalize = toggled_on
	value_changed.emit(noise_texture)


func _on_gradient_edit_updated(gradient: Gradient, _cc: bool) -> void:
	noise_texture.color_ramp = gradient
	value_changed.emit(noise_texture)


func _on_noise_type_option_button_item_selected(index: FastNoiseLite.NoiseType) -> void:
	(noise_texture.noise as FastNoiseLite).noise_type = index
	value_changed.emit(noise_texture)


func _on_seed_slider_value_changed(value: float) -> void:
	(noise_texture.noise as FastNoiseLite).seed = value
	value_changed.emit(noise_texture)


func _on_frequency_slider_value_changed(value: float) -> void:
	(noise_texture.noise as FastNoiseLite).frequency = value
	value_changed.emit(noise_texture)


func _on_offset_slider_value_changed(value: Vector3) -> void:
	(noise_texture.noise as FastNoiseLite).offset = value
	value_changed.emit(noise_texture)


func _on_fractal_type_option_button_item_selected(index: FastNoiseLite.FractalType) -> void:
	(noise_texture.noise as FastNoiseLite).fractal_type = index
	value_changed.emit(noise_texture)


func _on_fractal_octaves_slider_value_changed(value: float) -> void:
	(noise_texture.noise as FastNoiseLite).fractal_octaves = value
	value_changed.emit(noise_texture)


func _on_fractal_lacunarity_slider_value_changed(value: float) -> void:
	(noise_texture.noise as FastNoiseLite).fractal_lacunarity = value
	value_changed.emit(noise_texture)


func _on_fractal_gain_slider_value_changed(value: float) -> void:
	(noise_texture.noise as FastNoiseLite).fractal_gain = value
	value_changed.emit(noise_texture)


func _on_fractal_weighted_strength_slider_value_changed(value: float) -> void:
	(noise_texture.noise as FastNoiseLite).fractal_weighted_strength = value
	value_changed.emit(noise_texture)


func _on_domain_warp_enabled_check_box_toggled(toggled_on: bool) -> void:
	(noise_texture.noise as FastNoiseLite).domain_warp_enabled = toggled_on
	value_changed.emit(noise_texture)


func _on_domain_warp_type_option_button_item_selected(index: FastNoiseLite.DomainWarpType) -> void:
	(noise_texture.noise as FastNoiseLite).domain_warp_type = index
	value_changed.emit(noise_texture)


func _on_domain_warp_amplitude_slider_value_changed(value: float) -> void:
	(noise_texture.noise as FastNoiseLite).domain_warp_amplitude = value
	value_changed.emit(noise_texture)


func _on_domain_warp_frequency_slider_value_changed(value: float) -> void:
	(noise_texture.noise as FastNoiseLite).domain_warp_frequency = value
	value_changed.emit(noise_texture)


func _on_domain_warp_fractal_type_option_button_item_selected(
	index: FastNoiseLite.DomainWarpFractalType
) -> void:
	(noise_texture.noise as FastNoiseLite).domain_warp_fractal_type = index
	value_changed.emit(noise_texture)


func _on_domain_warp_fractal_octaves_slider_value_changed(value: float) -> void:
	(noise_texture.noise as FastNoiseLite).domain_warp_fractal_octaves = value
	value_changed.emit(noise_texture)


func _on_domain_warp_fractal_lacunarity_slider_value_changed(value: float) -> void:
	(noise_texture.noise as FastNoiseLite).domain_warp_fractal_lacunarity = value
	value_changed.emit(noise_texture)


func _on_domain_warp_fractal_gain_slider_value_changed(value: float) -> void:
	(noise_texture.noise as FastNoiseLite).domain_warp_fractal_gain = value
	value_changed.emit(noise_texture)
