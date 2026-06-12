extends ImageEffect

var blur_type := 0
var blur_amount := 16
var blur_radius := 1.0
var blur_direction := Vector2.ONE
var shader := preload("res://src/Shaders/Effects/GaussianBlur.gdshader")

# Supersample factor for smoother blur gradients on the commit path.
# The blur is rendered at (SUPERSAMPLE × original) resolution, then
# downscaled back with LANCZOS interpolation, producing much smoother
# gradient transitions than rendering at native pixel-art resolution.
const SUPERSAMPLE := 16

# Number of iterative blur passes at supersampled resolution.
# Each pass progressively smooths the gradient further.
# More passes = smoother result, but slower.
const BLUR_PASSES := 3


func _ready() -> void:
	super._ready()
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)


func commit_action(cel: Image, project := Global.current_project) -> void:
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project, project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	var params := {
		"blur_type": blur_type,
		"blur_amount": blur_amount,
		"blur_radius": blur_radius,
		"blur_direction": blur_direction,
		"selection": selection_tex
	}
	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		# --- Supersampled + iterative rendering for smooth blur ---
		var super_size := project.size * SUPERSAMPLE

		# 1. Upscale the cel image to SUPERSAMPLE×resolution with bilinear
		#    interpolation so the blur shader sees smooth intermediate values.
		var super_image := Image.create(super_size.x, super_size.y, false, Image.FORMAT_RGBA8)
		super_image.copy_from(cel)
		super_image.resize(super_size.x, super_size.y, Image.INTERPOLATE_BILINEAR)

		# 2. Upscale the selection texture to match supersampled size
		var super_selection_tex: ImageTexture
		if selection_tex:
			var selected_img_supersampled := selection_tex.get_image()
			selected_img_supersampled.resize(super_size.x, super_size.y, Image.INTERPOLATE_NEAREST)
			super_selection_tex = ImageTexture.create_from_image(selected_img_supersampled)

		# 3. Apply iterative blur passes at supersampled resolution.
		#    Each pass smooths the previous result further.
		#    Pass blur_amount = total / sqrt(passes) so the cumulative
		#    Gaussian width is approximately the same as a single pass.
		var pass_blur_amount: float = max(1.0, float(blur_amount) * float(SUPERSAMPLE) / sqrt(float(BLUR_PASSES)))
		var pass_blur_radius: float = blur_radius * float(SUPERSAMPLE) / sqrt(float(BLUR_PASSES))

		for _pass in range(BLUR_PASSES):
			var super_params := {
				"blur_type": blur_type,
				"blur_amount": int(pass_blur_amount),
				"blur_radius": pass_blur_radius,
				"blur_direction": blur_direction,
				"selection": super_selection_tex
			}
			var gen := ShaderImageEffect.new()
			gen.generate_image(super_image, shader, super_params, super_size)

		# 4. Downscale back to original size with high-quality LANCZOS
		super_image.resize(project.size.x, project.size.y, Image.INTERPOLATE_LANCZOS)

		# 5. Copy result back into the cel (preserving original format)
		super_image.convert(cel.get_format())
		cel.copy_from(super_image)


func _on_blur_type_item_selected(index: int) -> void:
	blur_type = index
	update_preview()


func _on_blur_amount_value_changed(value: float) -> void:
	blur_amount = value
	update_preview()


func _on_blur_radius_value_changed(value: float) -> void:
	blur_radius = value
	update_preview()


func _on_blur_direction_value_changed(value: Vector2) -> void:
	blur_direction = value
	update_preview()
