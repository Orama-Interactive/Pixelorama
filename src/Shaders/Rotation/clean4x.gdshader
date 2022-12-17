// Original shader by torcado194
// https://gist.github.com/torcado194/e2c9beb055d1b4fa3fe89c21e22eee9b
// Modified by Overloaded to combine it with NearestNeighbour rotation and selection masking
// So that it works in Pixelorama
shader_type canvas_item;

uniform float angle;
uniform sampler2D selection_tex;
uniform vec2 selection_pivot;
uniform vec2 selection_size;
// the color with the highest priority.
// other colors will be tested based on distance to this
// color to determine which colors take priority for overlaps.
uniform vec3 highestColor = vec3(1.,1.,1.);

// how close two colors should be to be considered "similar".
// can group shapes of visually similar colors, but creates
// some artifacting and should be kept as low as possible.
uniform float similarThreshold = 0.0;
uniform bool preview = true;

const float scale = 4.0;
const mat3 yuv_matrix = mat3(vec3(0.299, 0.587, 0.114), vec3(-0.169, -0.331, 0.5), vec3(0.5, -0.419, -0.081));

vec3 yuv(vec3 col){
	mat3 yuv = transpose(yuv_matrix);
	return yuv * col;
}

bool similar(vec4 col1, vec4 col2){
	return (col1.a == 0. && col2.a == 0.) || distance(col1, col2) <= similarThreshold;
}

// multiple versions because godot doesn't support function overloading
// note: inner check should ideally check between all permutations
// but this is good enough, and faster
bool similar3(vec4 col1, vec4 col2, vec4 col3){
	return similar(col1, col2) && similar(col2, col3);
}

bool similar4(vec4 col1, vec4 col2, vec4 col3, vec4 col4){
	return similar(col1, col2) && similar(col2, col3) && similar(col3, col4);
}

bool similar5(vec4 col1, vec4 col2, vec4 col3, vec4 col4, vec4 col5){
	return similar(col1, col2) && similar(col2, col3) && similar(col3, col4) && similar(col4, col5);
}

bool higher(vec4 thisCol, vec4 otherCol){
	if(similar(thisCol, otherCol)) return false;
	if(thisCol.a == otherCol.a){
//		return yuv(thisCol.rgb).x > yuv(otherCol.rgb).x;
//		return distance(yuv(thisCol.rgb), yuv(highestColor)) < distance(yuv(otherCol.rgb), yuv(highestColor));
		return distance(thisCol.rgb, highestColor) < distance(otherCol.rgb, highestColor);
	} else {
		return thisCol.a > otherCol.a;
	}
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

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float selection = texture(selection_tex, UV).a;
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE + 0.00001; //???
	vec2 pixelated_uv = floor(UV * size) / (size - 1.0); // Pixelate UV to fit resolution
	vec2 pivot = selection_pivot / size; // Normalize pivot position
	float ratio = size.x / size.y; // Resolution ratio
//	vec2 px = UV * size;
	vec2 px;
	if (preview) {
		px = rotate(pixelated_uv, pivot, ratio) * size;
	}
	else {
		px = rotate(UV, pivot, ratio) * size;
	}
	vec2 local = floor(mod(px,1.0)*scale);
	vec2 localDiff = (local/1.0) - vec2(1.5, 1.5);
	vec2 edge = floor(local/(scale/2.0))*(scale/2.0) - vec2(1.0, 1.0);
	px = ceil(px);
	
	vec4 baseCol = texture(TEXTURE, px/size);

	vec4 col = baseCol;
	
	vec4 c = baseCol;
	
//	vec4 c = texture(TEXTURE, floor(px+(vec2(0.5,0.5)+edge/4.0))/size);
	vec2 ot = vec2(edge.x, edge.y * 4.0);
	vec4 t = texture(TEXTURE, floor(px+(vec2(0.5,0.5)+ot/4.0))/size);
	vec2 otl = vec2(edge.x * 4.0, edge.y * 4.0);
	vec4 tl = texture(TEXTURE, floor(px+(vec2(0.5,0.5)+otl/4.0))/size);
	vec2 otr = vec2(-edge.x * 4.0, edge.y * 4.0);
	vec4 tr = texture(TEXTURE, floor(px+(vec2(0.5,0.5)+otr/4.0))/size);
	vec2 ol = vec2(edge.x * 4.0, edge.y);
	vec4 l = texture(TEXTURE, floor(px+(vec2(0.5,0.5)+ol/4.0))/size);
	vec2 ob = vec2(edge.x, -edge.y * 4.0);
	vec4 b = texture(TEXTURE, floor(px+(vec2(0.5,0.5)+ob/4.0))/size);
	vec2 obl = vec2(edge.x * 4.0, -edge.y * 4.0);
	vec4 bl = texture(TEXTURE, floor(px+(vec2(0.5,0.5)+obl/4.0))/size);
	vec2 obr = vec2(-edge.x * 4.0, -edge.y * 4.0);
	vec4 br = texture(TEXTURE, floor(px+(vec2(0.5,0.5)+obr/4.0))/size);
	vec2 or = vec2(-edge.x * 4.0, edge.y);
	vec4 r = texture(TEXTURE, floor(px+(vec2(0.5,0.5)+or/4.0))/size);
	
	vec2 os = vec2(localDiff.x, localDiff.y);
	vec4 s = texture(TEXTURE, floor(px+(vec2(0.5,0.5)+os/2.0))/size);
	
	
	//checkerboard special case
	if(similar5(c, tl, tr, bl, br) && similar4(t, r, b, l) && higher(t, c)){
//		if(local == vec2(0.,0.)){
//			col = l;
//		} else if(local == vec2(3.,0.)){
//			col = r;
//		} else if(local == vec2(0.,3.)){
//			col = l;
//		} else if(local == vec2(3.,3.)){
//			col = r;
//		}
	} else {
		//corner
		if(length(localDiff) > 2.1){
			if(similar(t, l) && !(similar(tl, c) && !higher(t, c))){
				col = t;
			} else if(higher(c, l) && higher(c, t) && (similar(tr, c) || similar(bl, c)) && !similar(tl, c)){
				if(higher(t, l)){
					col = t;
				} else {
					col = l;
				}
			}
		//edge
		} else if(length(localDiff) > 1.58) {
			
			if(similar(t, l)){
				if(higher(s, c)){
					col = s;
				}
			}
			
			if(similar3(r, s, tl) && similar3(br, c, l) && higher(s, c)/* && !similar(b, t)*/){
				col = t;
			}
			if(!similar(tl, c) && similar3(r, c, bl) && similar3(tr, t, l) && higher(c, l)){
				col = s;
			}
			if(!similar(tr, c) && similar3(l, c, br) && similar3(tl, s, r) && higher(c, r)){
				col = s;
			}
			
			if(similar3(b, s, tl) && similar3(br, c, t) && higher(b, c)/* && !similar(r, l)*/){
				col = s;
			}
			if(!similar(tl, c) && similar3(tr, c, b) && similar3(t, l, bl) && higher(c, l)){
				col = s;
			}
			if(!similar(bl, c) && similar3(br, c, t) && similar3(b, s, tl) && higher(c, s)){
				col = s;
			}
		}
	}
	//set alpha back to full, for manually adjusted pixels 
	if(col.a > 0.00001){
		col.a = 1.0;
	}
	
	// Taken from NearestNeighbour shader
	col.a *= texture(selection_tex, rotate(pixelated_uv, pivot, ratio)).a; // Combine with selection mask
	// Make a border to prevent stretching pixels on the edge
	vec2 border_uv = rotate(pixelated_uv, pivot, ratio);
	
	// Center the border
	border_uv -= 0.5;
	border_uv *= 2.0;
	border_uv = abs(border_uv);
	
	float border = max(border_uv.x, border_uv.y); // This is a rectangular gradient
	border = floor(border - TEXTURE_PIXEL_SIZE.x); // Turn the grad into a rectangle shape
	border = 1.0 - clamp(border, 0.0, 1.0); // Invert the rectangle
	
	float mask = mix(selection, 1.0, 1.0 - ceil(original.a)); // Combine selection mask with area outside original
	
	// Combine original and rotated image only when intersecting, otherwise just pure rotated image.
	COLOR.rgb = mix(mix(original.rgb, col.rgb, col.a * border), col.rgb, mask);
	COLOR.a = mix(original.a, 0.0, selection); // Remove alpha on the selected area
	COLOR.a = mix(COLOR.a, 1.0, col.a * border); // Combine alpha of original image and rotated
	
	//COLOR = col;
}
