shader_type canvas_item;

// author : csblo
// Work made just by consulting :
// https://en.wikipedia.org/wiki/Kernel_(image_processing)

uniform mat3 kernel = mat3(vec3(0, 0, 0), vec3(0, 1, 0), vec3(0, 0, 0));

// Find coordinate of matrix element from index
vec2 kpos(int index, vec2 iResolution)
{
	return vec2[9] (
		vec2(-1, -1), vec2(0, -1), vec2(1, -1),
		vec2(-1, 0), vec2(0, 0), vec2(1, 0),
		vec2(-1, 1), vec2(0, 1), vec2(1, 1)
	)[index] / iResolution.xy;
}


// Extract region of dimension 3x3 from sampler centered in uv
// sampler : texture sampler
// uv : current coordinates on sampler
// return : an array of mat3, each index corresponding with a color channel
mat3[3] region3x3(sampler2D sampler, vec2 uv, vec2 iResolution)
{
	// Create each pixels for region
	vec4[9] region;

	for (int i = 0; i < 9; i++)
		region[i] = texture(sampler, uv + kpos(i, iResolution));

	// Create 3x3 region with 3 color channels (red, green, blue)
	mat3[3] mRegion;

	for (int i = 0; i < 3; i++)
		mRegion[i] = mat3(
			vec3(region[0][i], region[1][i], region[2][i]),
			vec3(region[3][i], region[4][i], region[5][i]),
			vec3(region[6][i], region[7][i], region[8][i])
		);

	return mRegion;
}

// Convolve a texture with kernel
// kernel : kernel used for convolution
// sampler : texture sampler
// uv : current coordinates on sampler
vec3 convolution(sampler2D sampler, vec2 uv, vec2 iResolution)
{
	vec3 fragment;

	// Extract a 3x3 region centered in uv
	mat3[3] region = region3x3(sampler, uv, iResolution);

	// for each color channel of region
	for (int i = 0; i < 3; i++)
	{
		// get region channel
		mat3 rc = region[i];
		// component wise multiplication of kernel by region channel
		mat3 c = matrixCompMult(kernel, rc);
		// add each component of matrix
		float r = c[0][0] + c[1][0] + c[2][0]
				+ c[0][1] + c[1][1] + c[2][1]
				+ c[0][2] + c[1][2] + c[2][2];

		// for fragment at channel i, set result
		fragment[i] = r;
	}

	return fragment;
}

void fragment()
{
	// Convolve kernel with texture
	vec3 col = convolution(TEXTURE, UV, 1.0 / TEXTURE_PIXEL_SIZE);

	// Output to screen
	COLOR.rgb = col;
}
