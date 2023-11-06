// No AA version from https://github.com/deakcor/godot-omniscale/blob/5dfee6e89cd955dd01dccfe70c9979f9b55bb1bf/OmniScale.shader
// Edited slightly by Overloaded to add rotation support for Pixelorama
shader_type canvas_item;

//#version 130

// OmniScale
// by Lior Halphon
// original GLSL code from hunterk by way of RetroArch
// ported to Godot3 shader language by Nobuyuki

//
// MIT License
//
// Copyright (c) 2015-2016 Lior Halphon
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

uniform int ScaleMultiplier : hint_range(0, 100) = 4;

// vertex compatibility #defines
// #define vTexCoord TEX0.xy
// #define outsize vec4(OutputSize, 1.0 / OutputSize)

// Pixelorama-specific uniforms
uniform float angle;
uniform sampler2D selection_tex;
uniform vec2 pivot_pixel;
uniform bool preview = false;


bool is_different(vec4 a, vec4 b)
{
    return distance(a,b)>0.1;
}

// This define could've made code a ton more readable if godot shaders supported it, but it doesn't.
// 55 occurrences of this in code;  use regexp to turn it back once supported?
// #define P(m, r) ((pattern & (m)) == (r))


vec4 scale(sampler2D image, vec2 coord, vec2 pxSize) {

	vec2 OutputSize = vec2(float(ScaleMultiplier), float(ScaleMultiplier));
	vec2 textureDimensions = vec2(1.0,1.0);

    // o = offset, the width of a pixel
    vec2 o = pxSize;
    vec2 texCoord = coord;

    // We always calculate the top left quarter.  If we need a different quarter, we flip our coordinates */

    // p = the position within a pixel [0...1]
    vec2 p = fract(texCoord / pxSize);

    if (p.x > 0.5) {
        o.x = -o.x;
        p.x = 1.0 - p.x;
    }
    if (p.y > 0.5) {
        o.y = -o.y;
        p.y = 1.0 - p.y;
    }



    vec4 w0 = texture(image, texCoord + vec2( -o.x, -o.y));
    vec4 w1 = texture(image, texCoord + vec2(    0, -o.y));
    vec4 w2 = texture(image, texCoord + vec2(  o.x, -o.y));
    vec4 w3 = texture(image, texCoord + vec2( -o.x,    0));
    vec4 w4 = texture(image, texCoord + vec2(    0,    0));
    vec4 w5 = texture(image, texCoord + vec2(  o.x,    0));
    vec4 w6 = texture(image, texCoord + vec2( -o.x,  o.y));
    vec4 w7 = texture(image, texCoord + vec2(    0,  o.y));
    vec4 w8 = texture(image, texCoord + vec2(  o.x,  o.y));

    int pattern = 0;
    if (is_different(w0, w4)) pattern |= 1 << 0;
    if (is_different(w1, w4)) pattern |= 1 << 1;
    if (is_different(w2, w4)) pattern |= 1 << 2;
    if (is_different(w3, w4)) pattern |= 1 << 3;
    if (is_different(w5, w4)) pattern |= 1 << 4;
    if (is_different(w6, w4)) pattern |= 1 << 5;
    if (is_different(w7, w4)) pattern |= 1 << 6;
    if (is_different(w8, w4)) pattern |= 1 << 7;

    if ((((pattern & (191)) == (55)) || ((pattern & (219)) == (19))) && is_different(w1, w5))
        return mix(w4, w3, 0.5 - p.x>0.5?1.0:0.0);
    if ((((pattern & (219)) == (73)) || ((pattern & (239)) == (109))) && is_different(w7, w3))
        return mix(w4, w1, 0.5 - p.y>0.5?1.0:0.0);
    if ((((pattern & (11)) == (11)) || ((pattern & (254)) == (74)) || ((pattern & (254)) == (26))) && is_different(w3, w1))
        return w4;
    if ((((pattern & (111)) == (42)) || ((pattern & (91)) == (10)) || ((pattern & (191)) == (58)) || ((pattern & (223)) == (90)) ||
         ((pattern & (159)) == (138)) || ((pattern & (207)) == (138)) || ((pattern & (239)) == (78)) || ((pattern & (63)) == (14)) ||
         ((pattern & (251)) == (90)) || ((pattern & (187)) == (138)) || ((pattern & (127)) == (90)) || ((pattern & (175)) == (138)) ||
         ((pattern & (235)) == (138))) && is_different(w3, w1))
        return mix(w4, mix(w4, w0, 0.5 - p.x>0.5?1.0:0.0), 0.5 - p.y>0.5?1.0:0.0);
    if (((pattern & (11)) == (8)))
        return mix(mix(w0 * 0.375 + w1 * 0.25 + w4 * 0.375, w4 * 0.5 + w1 * 0.5, p.x * 2.0>0.5?1.0:0.0), w4, p.y * 2.0>0.5?1.0:0.0);
    if (((pattern & (11)) == (2)))
        return mix(mix(w0 * 0.375 + w3 * 0.25 + w4 * 0.375, w4 * 0.5 + w3 * 0.5, p.y * 2.0>0.5?1.0:0.0), w4, p.x * 2.0>0.5?1.0:0.0);
    if (((pattern & (47)) == (47))) {
        float dist = length(p - vec2(0.5));
        float pixel_size = length(1.0 / (OutputSize / textureDimensions));
        if (dist < 0.5 - pixel_size / 2.0) {
            return w4;
        }
        vec4 r;
        if (is_different(w0, w1) || is_different(w0, w3)) {
            r = mix(w1, w3, p.y - p.x + 0.5>0.5?1.0:0.0);
        }
        else {
            r = mix(mix(w1 * 0.375 + w0 * 0.25 + w3 * 0.375, w3, p.y * 2.0>0.5?1.0:0.0), w1, p.x * 2.0>0.5?1.0:0.0);
        }

        if (dist > 0.5 + pixel_size / 2.0) {
            return r;
        }
        return mix(w4, r, (dist - 0.5 + pixel_size / 2.0) / pixel_size>0.5?1.0:0.0);
    }
    if (((pattern & (191)) == (55)) || ((pattern & (219)) == (19))) {
        float dist = p.x - 2.0 * p.y;
        float pixel_size = length(1.0 / (OutputSize / textureDimensions)) * sqrt(5.0);
        if (dist > pixel_size / 2.0) {
            return w1;
        }
        vec4 r = mix(w3, w4, p.x + 0.5>0.5?1.0:0.0);
        if (dist < -pixel_size / 2.0) {
            return r;
        }
        return mix(r, w1, (dist + pixel_size / 2.0) / pixel_size>0.5?1.0:0.0);
    }
    if (((pattern & (219)) == (73)) || ((pattern & (239)) == (109))) {
        float dist = p.y - 2.0 * p.x;
        float pixel_size = length(1.0 / (OutputSize / textureDimensions)) * sqrt(5.0);
        if (p.y - 2.0 * p.x > pixel_size / 2.0) {
            return w3;
        }
        vec4 r = mix(w1, w4, p.x + 0.5>0.5?1.0:0.0);
        if (dist < -pixel_size / 2.0) {
            return r;
        }
        return mix(r, w3, (dist + pixel_size / 2.0) / pixel_size>0.5?1.0:0.0);
    }
    if (((pattern & (191)) == (143)) || ((pattern & (126)) == (14))) {
        float dist = p.x + 2.0 * p.y;
        float pixel_size = length(1.0 / (OutputSize / textureDimensions)) * sqrt(5.0);

        if (dist > 1.0 + pixel_size / 2.0) {
            return w4;
        }

        vec4 r;
        if (is_different(w0, w1) || is_different(w0, w3)) {
            r = mix(w1, w3, p.y - p.x + 0.5>0.5?1.0:0.0);
        }
        else {
            r = mix(mix(w1 * 0.375 + w0 * 0.25 + w3 * 0.375, w3, p.y * 2.0>0.5?1.0:0.0), w1, p.x * 2.0>0.5?1.0:0.0);
        }

        if (dist < 1.0 - pixel_size / 2.0) {
            return r;
        }

        return mix(r, w4, (dist + pixel_size / 2.0 - 1.0) / pixel_size>0.5?1.0:0.0);

    }

    if (((pattern & (126)) == (42)) || ((pattern & (239)) == (171))) {
        float dist = p.y + 2.0 * p.x;
        float pixel_size = length(1.0 / (OutputSize / textureDimensions)) * sqrt(5.0);

        if (p.y + 2.0 * p.x > 1.0 + pixel_size / 2.0) {
            return w4;
        }

        vec4 r;

        if (is_different(w0, w1) || is_different(w0, w3)) {
            r = mix(w1, w3, p.y - p.x + 0.5>0.5?1.0:0.0);
        }
        else {
            r = mix(mix(w1 * 0.375 + w0 * 0.25 + w3 * 0.375, w3, p.y * 2.0>0.5?1.0:0.0), w1, p.x * 2.0>0.5?1.0:0.0);
        }

        if (dist < 1.0 - pixel_size / 2.0) {
            return r;
        }

        return mix(r, w4, (dist + pixel_size / 2.0 - 1.0) / pixel_size>0.5?1.0:0.0);
    }

    if (((pattern & (27)) == (3)) || ((pattern & (79)) == (67)) || ((pattern & (139)) == (131)) || ((pattern & (107)) == (67)))
        return mix(w4, w3, 0.5 - p.x>0.5?1.0:0.0);

    if (((pattern & (75)) == (9)) || ((pattern & (139)) == (137)) || ((pattern & (31)) == (25)) || ((pattern & (59)) == (25)))
        return mix(w4, w1, 0.5 - p.y>0.5?1.0:0.0);

    if (((pattern & (251)) == (106)) || ((pattern & (111)) == (110)) || ((pattern & (63)) == (62)) || ((pattern & (251)) == (250)) ||
        ((pattern & (223)) == (222)) || ((pattern & (223)) == (30)))
        return mix(w4, w0, (1.0 - p.x - p.y) / 2.0>0.5?1.0:0.0);

    if (((pattern & (79)) == (75)) || ((pattern & (159)) == (27)) || ((pattern & (47)) == (11)) ||
        ((pattern & (190)) == (10)) || ((pattern & (238)) == (10)) || ((pattern & (126)) == (10)) || ((pattern & (235)) == (75)) ||
        ((pattern & (59)) == (27))) {
        float dist = p.x + p.y;
        float pixel_size = length(1.0 / (OutputSize / textureDimensions));

        if (dist > 0.5 + pixel_size / 2.0) {
            return w4;
        }

        vec4 r;
        if (is_different(w0, w1) || is_different(w0, w3)) {
            r = mix(w1, w3, p.y - p.x + 0.5>0.5?1.0:0.0);
        }
        else {
            r = mix(mix(w1 * 0.375 + w0 * 0.25 + w3 * 0.375, w3, p.y * 2.0>0.5?1.0:0.0), w1, p.x * 2.0>0.5?1.0:0.0);
        }

        if (dist < 0.5 - pixel_size / 2.0) {
            return r;
        }

        return mix(r, w4, (dist + pixel_size / 2.0 - 0.5) / pixel_size>0.5?1.0:0.0);
    }

    if (((pattern & (11)) == (1)))
        return mix(mix(w4, w3, 0.5 - p.x>0.5?1.0:0.0), mix(w1, (w1 + w3) / 2.0, 0.5 - p.x>0.5?1.0:0.0), 0.5 - p.y>0.5?1.0:0.0);

    if (((pattern & (11)) == (0)))
        return mix(mix(w4, w3, 0.5 - p.x>0.5?1.0:0.0), mix(w1, w0, 0.5 - p.x>0.5?1.0:0.0), 0.5 - p.y>0.5?1.0:0.0);

    float dist = p.x + p.y;
    float pixel_size = length(1.0 / (OutputSize / textureDimensions));

    if (dist > 0.5 + pixel_size / 2.0)
        return w4;

    /* We need more samples to "solve" this diagonal */
    vec4 x0 = texture(image, texCoord + vec2( -o.x * 2.0, -o.y * 2.0));
    vec4 x1 = texture(image, texCoord + vec2( -o.x      , -o.y * 2.0));
    vec4 x2 = texture(image, texCoord + vec2(  0.0      , -o.y * 2.0));
    vec4 x3 = texture(image, texCoord + vec2(  o.x      , -o.y * 2.0));
    vec4 x4 = texture(image, texCoord + vec2( -o.x * 2.0, -o.y      ));
    vec4 x5 = texture(image, texCoord + vec2( -o.x * 2.0,  0.0      ));
    vec4 x6 = texture(image, texCoord + vec2( -o.x * 2.0,  o.y      ));

    if (is_different(x0, w4)) pattern |= 1 << 8;
    if (is_different(x1, w4)) pattern |= 1 << 9;
    if (is_different(x2, w4)) pattern |= 1 << 10;
    if (is_different(x3, w4)) pattern |= 1 << 11;
    if (is_different(x4, w4)) pattern |= 1 << 12;
    if (is_different(x5, w4)) pattern |= 1 << 13;
    if (is_different(x6, w4)) pattern |= 1 << 14;

    int diagonal_bias = -7;
    while (pattern != 0) {
        diagonal_bias += pattern & 1;
        pattern >>= 1;
    }

    if (diagonal_bias <=  0) {
        vec4 r = mix(w1, w3, p.y - p.x + 0.5>0.5?1.0:0.0);
        if (dist < 0.5 - pixel_size / 2.0) {
            return r;
        }
        return mix(r, w4, (dist + pixel_size / 2.0 - 0.5) / pixel_size>0.5?1.0:0.0);
    }

    return w4;
}


vec2 rotate(vec2 uv, vec2 pivot, float ratio) {  // Taken from NearestNeighbour shader
	// Scale and center image
	uv.x -= pivot.x;
	uv.x *= ratio;
	uv.x += pivot.x;

	// Rotate image
	uv -= pivot;
	uv = vec2(cos(angle) * uv.x + sin(angle) * uv.y,
				-sin(angle) * uv.x + cos(angle) * uv.y);
	uv.x /= ratio;
	uv += pivot;

	return uv;
}


void fragment()
{
	vec4 original = texture(TEXTURE, UV);
	float selection = texture(selection_tex, UV).a;
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 pivot = pivot_pixel / size; // Normalize pivot position
	float ratio = size.x / size.y; // Resolution ratio
	vec2 pixelated_uv = floor(UV * size) / (size - 1.0); // Pixelate UV to fit resolution
	vec2 rotated_uv;
	if (preview) {
		rotated_uv = rotate(pixelated_uv, pivot, ratio);
	}
	else {
		rotated_uv = rotate(UV, pivot, ratio);
	}
	vec4 c;
	c = scale(TEXTURE, rotated_uv, TEXTURE_PIXEL_SIZE);

	// Taken from NearestNeighbour shader
	c.a *= texture(selection_tex, rotated_uv).a; // Combine with selection mask
	// Make a border to prevent stretching pixels on the edge
	vec2 border_uv = rotated_uv;

	// Center the border
	border_uv -= 0.5;
	border_uv *= 2.0;
	border_uv = abs(border_uv);

	float border = max(border_uv.x, border_uv.y); // This is a rectangular gradient
	border = floor(border - TEXTURE_PIXEL_SIZE.x); // Turn the grad into a rectangle shape
	border = 1.0 - clamp(border, 0.0, 1.0); // Invert the rectangle

	float mask = mix(selection, 1.0, 1.0 - ceil(original.a)); // Combine selection mask with area outside original

	// Combine original and rotated image only when intersecting, otherwise just pure rotated image.
	COLOR.rgb = mix(mix(original.rgb, c.rgb, c.a * border), c.rgb, mask);
	COLOR.a = mix(original.a, 0.0, selection); // Remove alpha on the selected area
	COLOR.a = mix(COLOR.a, 1.0, c.a * border); // Combine alpha of original image and rotated
	//c.a = step(0.5,c.a);
	//COLOR = c;
}