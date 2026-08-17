shader_type canvas_item;
render_mode unshaded;

// Works on the principle https://www.sciencedirect.com/science/article/pii/S0965997825001139

uniform sampler2D selection : filter_nearest;

uniform ivec2 top_left = ivec2(0, 0);
uniform ivec2 top_right = ivec2(64, 0);
uniform ivec2 bottom_left = ivec2(0, 64);
uniform ivec2 bottom_right = ivec2(64, 64);


// we define cross2 as the scalar z-component of the cross product.
float cross2(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}


// Finds the source UV (the UV before deformation) that mapps to deformed UV coordinates `p`.
vec2 inverse_deform(vec2 p, vec2 tl, vec2 tr, vec2 bl, vec2 br) {
	// Bilinear interpolation:
	// https://en.wikipedia.org/wiki/Bilinear_interpolation#On_the_unit_square
	// here p is the deformed coordinate and (x, y) is the source we wish to find
	// p(x, y) = A + Bx + Cy + Dxy
	vec2 A = tl;
	vec2 B = tr - tl;
	vec2 C = bl - tl;
	vec2 D = tl - tr - bl + br;

	// p(x, y) - A = Bx + Cy + Dxy
	// Now we need to solve this equation for x and y.
	vec2 q = p - A;

	// We eliminate x and solve a quadratic for y.
	// q x C = (Bx + Cy + Dxy) x C  -->  q x C = x(B x C) + xy(D x C)
	// On solving for x we get --> x = (q x C) / [(B x C) + y(D x C)]
	// uning this in {q = Bx + Cy + Dxy} and turning it into a quadratic we get
	// (C x D)y^2 + [(C x B) − (q x D)]y − (q x B) = 0
	// a*y² + b*y + c = 0
	float a = cross2(C, D);
	float b = cross2(C, B) - cross2(q, D);
	float c = -cross2(q, B);

	// Degenerate / nearly linear case. if a = 0 then {a*y² + b*y + c = 0} --> {b*y + c = 0}
	// we don't need to use quadratic formulla here
	if (abs(a) < 0.001) {
		if (abs(b) < 0.001) {
			return vec2(-1.0);
		}
		float y = -c / b;
		float denominator = cross2(B, C) + (y * cross2(D, C));

		if (abs(denominator) < 0.000001) {
			return vec2(-1.0);
		}
		float x = cross2(q, C) / denominator;
		return vec2(x, y);
	}

	// Solve the quadratic equation
	// b^2 - 4ac is used to predict the type of solutions we get after solving
	float discriminant = b * b - 4.0 * a * c;
	float sqrt_discriminant = sqrt(discriminant);

	// Case 1: No real solution.
	if (discriminant < 0.0) {
		return vec2(-1.0);
	}

	// Case 2: Solutions possible (quadratic equation has 2 general solutions)
	float y0 = (-b + sqrt_discriminant) / (2.0 * a);
	float y1 = (-b - sqrt_discriminant) / (2.0 * a);

	// Pick the solution inside the source rectangle.
	float y;
	bool y0_valid = y0 >= 0.0 && y0 <= 1.0;
	bool y1_valid = y1 >= 0.0 && y1 <= 1.0;
	if (y0_valid) {
		y = y0;
	} else if (y1_valid) {
		y = y1;
	} else {
		return vec2(-1.0);
	}

	// we have obtained y, now solve for x (Remember: x = (q x C) / [(B x C) + y(D x C)])
	float denominator = cross2(B, C) + y * cross2(D, C);

	// Prevent infinities
	if (abs(denominator) < 0.000001) {
		return vec2(-1.0);
	}

	float x = cross2(q, C) / denominator;
	return vec2(x, y);
}


void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec2 size = vec2(textureSize(TEXTURE, 0));

	// Convert to normalized UV system
	vec2 tl = vec2(top_left) / size;
	vec2 tr = vec2(top_right) / size;
	vec2 bl = vec2(bottom_left) / size;
	vec2 br = vec2(bottom_right) / size;

	// Find which original texture coordinate corresponds to this destination position.
	// We are considering that UV is already deformed and working our way back to what color
	// should be placed here according to un-deformed UV
	vec2 source_uv = inverse_deform(UV, tl, tr, bl, br);

	// We are deforming entire image, obviously everything outside is transparent
	vec4 distorted_color = vec4(0.0);

	// Only pick color if the undeformed coordinate is a valid UV point
	if (
		source_uv.x >= 0.0 &&
		source_uv.x <= 1.0 &&
		source_uv.y >= 0.0 &&
		source_uv.y <= 1.0
	) {
		distorted_color = texture(TEXTURE, source_uv);
	}

	vec4 selection_color = texture(selection, UV);
	COLOR = mix(original_color, distorted_color, selection_color.a);
}