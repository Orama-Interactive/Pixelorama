/*** MIT LICENSE
Copyright (c) 2022 torcado

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
***/


shader_type canvas_item;

//enables 2:1 slopes. otherwise only uses 45 degree slopes
#define SLOPE
//cleans up small detail slope transitions (if SLOPE is enabled)
//if only using for rotation, CLEANUP has negligible effect and should be disabled for speed
#define CLEANUP

//the color with the highest priority.
// other colors will be tested based on distance to this
// color to determine which colors take priority for overlaps.
uniform vec3 highestColor = vec3(1.,1.,1.);

//how close two colors should be to be considered "similar".
// can group shapes of visually similar colors, but creates
// some artifacting and should be kept as low as possible.
uniform float similarThreshold = 0.0;

uniform float lineWidth = 1.0;

// Edited for Pixelorama
uniform float angle;
uniform sampler2D selection_tex;
uniform vec2 pivot_pixel;
uniform bool preview = false;

bool similar(vec4 col1, vec4 col2){
	return (col1.a == 0. && col2.a == 0.) || distance(col1, col2) <= similarThreshold;
}

//multiple versions because godot doesn't support function overloading
//note: inner check should ideally check between all permutations
//  but this is good enough, and faster
bool similar3(vec4 col1, vec4 col2, vec4 col3){
	return similar(col1, col2) && similar(col2, col3);
}

bool similar4(vec4 col1, vec4 col2, vec4 col3, vec4 col4){
	return similar(col1, col2) && similar(col2, col3) && similar(col3, col4);
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

//color distance
float cd(vec4 col1, vec4 col2){
	return distance(col1.rgba, col2.rgba);
}

float distToLine(vec2 testPt, vec2 pt1, vec2 pt2, vec2 dir){
  vec2 lineDir = pt2 - pt1;
  vec2 perpDir = vec2(lineDir.y, -lineDir.x);
  vec2 dirToPt1 = pt1 - testPt;
  return (dot(perpDir, dir) > 0.0 ? 1.0 : -1.0) * (dot(normalize(perpDir), dirToPt1));
}

//based on down-forward direction
vec4 sliceDist(vec2 point, vec2 mainDir, vec2 pointDir, vec4 u, vec4 uf, vec4 uff, vec4 b, vec4 c, vec4 f, vec4 ff, vec4 db, vec4 d, vec4 df, vec4 dff, vec4 ddb, vec4 dd, vec4 ddf){
	#ifdef SLOPE
	float minWidth = 0.44;
	float maxWidth = 1.142;
	#else
	float minWidth = 0.0;
	float maxWidth = 1.4;
	#endif
	float _lineWidth = max(minWidth, min(maxWidth, lineWidth));
	point = mainDir * (point - 0.5) + 0.5; //flip point

	//edge detection
	float distAgainst = 4.0*cd(f,d) + cd(uf,c) + cd(c,db) + cd(ff,df) + cd(df,dd);
	float distTowards = 4.0*cd(c,df) + cd(u,f) + cd(f,dff) + cd(b,d) + cd(d,ddf);
	bool shouldSlice =
	  (distAgainst < distTowards)
	  || (distAgainst < distTowards + 0.001) && !higher(c, f); //equivalent edges edge case
	if(similar4(f, d, b, u) && similar3(uf, df, db/*, ub*/) && !similar(c, f)){ //checkerboard edge case
		shouldSlice = false;
	}
	if(!shouldSlice) return vec4(-1.0);

	//only applicable for very large lineWidth (>1.3)
//	if(similar3(c, f, df)){ //don't make slice for same color
//		return vec4(-1.0);
//	}
	float dist = 1.0;
	bool flip = false;
	vec2 center = vec2(0.5,0.5);

	#ifdef SLOPE
	if(similar3(f, d, db) && !similar3(f, d, b) && !similar(uf, db)){ //lower shallow 2:1 slant
		if(similar(c, df) && higher(c, f)){ //single pixel wide diagonal, dont flip

		} else {
			//priority edge cases
			if(higher(c, f)){
				flip = true;
			}
			if(similar(u, f) && !similar(c, df) && !higher(c, u)){
				flip = true;
			}
		}

		if(flip){
			dist = _lineWidth-distToLine(point, center+vec2(1.5, -1.0)*pointDir, center+vec2(-0.5, 0.0)*pointDir, -pointDir); //midpoints of neighbor two-pixel groupings
		} else {
			dist = distToLine(point, center+vec2(1.5, 0.0)*pointDir, center+vec2(-0.5, 1.0)*pointDir, pointDir); //midpoints of neighbor two-pixel groupings
		}

		//cleanup slant transitions
		#ifdef CLEANUP
		if(!flip && similar(c, uf) && !(similar3(c, uf, uff) && !similar3(c, uf, ff) && !similar(d, uff))){ //shallow
			float dist2 = distToLine(point, center+vec2(2.0, -1.0)*pointDir, center+vec2(-0.0, 1.0)*pointDir, pointDir);
			dist = min(dist, dist2);
		}
		#endif

		dist -= (_lineWidth/2.0);
		return dist <= 0.0 ? ((cd(c,f) <= cd(c,d)) ? f : d) : vec4(-1.0);
	} else if(similar3(uf, f, d) && !similar3(u, f, d) && !similar(uf, db)){ //forward steep 2:1 slant
		if(similar(c, df) && higher(c, d)){ //single pixel wide diagonal, dont flip

		} else {
			//priority edge cases
			if(higher(c, d)){
				flip = true;
			}
			if(similar(b, d) && !similar(c, df) && !higher(c, d)){
				flip = true;
			}
		}

		if(flip){
			dist = _lineWidth-distToLine(point, center+vec2(0.0, -0.5)*pointDir, center+vec2(-1.0, 1.5)*pointDir, -pointDir); //midpoints of neighbor two-pixel groupings
		} else {
			dist = distToLine(point, center+vec2(1.0, -0.5)*pointDir, center+vec2(0.0, 1.5)*pointDir, pointDir); //midpoints of neighbor two-pixel groupings
		}

		//cleanup slant transitions
		#ifdef CLEANUP
		if(!flip && similar(c, db) && !(similar3(c, db, ddb) && !similar3(c, db, dd) && !similar(f, ddb))){ //steep
			float dist2 = distToLine(point, center+vec2(1.0, 0.0)*pointDir, center+vec2(-1.0, 2.0)*pointDir, pointDir);
			dist = min(dist, dist2);
		}
		#endif

		dist -= (_lineWidth/2.0);
		return dist <= 0.0 ? ((cd(c,f) <= cd(c,d)) ? f : d) : vec4(-1.0);
	} else
	#endif
	if(similar(f, d)) { //45 diagonal
		if(similar(c, df) && higher(c, f)){ //single pixel diagonal along neighbors, dont flip
			if(!similar(c, dd) && !similar(c, ff)){ //line against triple color stripe edge case
				flip = true;
			}
		} else {
			//priority edge cases
			if(higher(c, f)){
				flip = true;
			}
			if(!similar(c, b) && similar4(b, f, d, u)){
				flip = true;
			}
		}
		//single pixel 2:1 slope, dont flip
		if((( (similar(f, db) && similar3(u, f, df)) || (similar(uf, d) && similar3(b, d, df)) ) && !similar(c, df))){
			flip = true;
		}

		if(flip){
			dist = _lineWidth-distToLine(point, center+vec2(1.0, -1.0)*pointDir, center+vec2(-1.0, 1.0)*pointDir, -pointDir); //midpoints of own diagonal pixels
		} else {
			dist = distToLine(point, center+vec2(1.0, 0.0)*pointDir, center+vec2(0.0, 1.0)*pointDir, pointDir); //midpoints of corner neighbor pixels
		}

		//cleanup slant transitions
		#ifdef SLOPE
		#ifdef CLEANUP
		if(!flip && similar3(c, uf, uff) && !similar3(c, uf, ff) && !similar(d, uff)){ //shallow
			float dist2 = distToLine(point, center+vec2(1.5, 0.0)*pointDir, center+vec2(-0.5, 1.0)*pointDir, pointDir);
			dist = max(dist, dist2);
		}

		if(!flip && similar3(ddb, db, c) && !similar3(dd, db, c) && !similar(ddb, f)){ //steep
			float dist2 = distToLine(point, center+vec2(1.0, -0.5)*pointDir, center+vec2(0.0, 1.5)*pointDir, pointDir);
			dist = max(dist, dist2);
		}
		#endif
		#endif

		dist -= (_lineWidth/2.0);
		return dist <= 0.0 ? ((cd(c,f) <= cd(c,d)) ? f : d) : vec4(-1.0);
	}
	#ifdef SLOPE
	else if(similar3(ff, df, d) && !similar3(ff, df, c) && !similar(uff, d)){ //far corner of shallow slant

		if(similar(f, dff) && higher(f, ff)){ //single pixel wide diagonal, dont flip

		} else {
			//priority edge cases
			if(higher(f, ff)){
				flip = true;
			}
			if(similar(uf, ff) && !similar(f, dff) && !higher(f, uf)){
				flip = true;
			}
		}
		if(flip){
			dist = _lineWidth-distToLine(point, center+vec2(1.5+1.0, -1.0)*pointDir, center+vec2(-0.5+1.0, 0.0)*pointDir, -pointDir); //midpoints of neighbor two-pixel groupings
		} else {
			dist = distToLine(point, center+vec2(1.5+1.0, 0.0)*pointDir, center+vec2(-0.5+1.0, 1.0)*pointDir, pointDir); //midpoints of neighbor two-pixel groupings
		}

		dist -= (_lineWidth/2.0);
		return dist <= 0.0 ? ((cd(f,ff) <= cd(f,df)) ? ff : df) : vec4(-1.0);
	} else if(similar3(f, df, dd) && !similar3(c, df, dd) && !similar(f, ddb)){ //far corner of steep slant
		if(similar(d, ddf) && higher(d, dd)){ //single pixel wide diagonal, dont flip

		} else {
			//priority edge cases
			if(higher(d, dd)){
				flip = true;
			}
			if(similar(db, dd) && !similar(d, ddf) && !higher(d, dd)){
				flip = true;
			}
//			if(!higher(d, dd)){
//				return vec4(1.0);
//				flip = true;
//			}
		}

		if(flip){
			dist = _lineWidth-distToLine(point, center+vec2(0.0, -0.5+1.0)*pointDir, center+vec2(-1.0, 1.5+1.0)*pointDir, -pointDir); //midpoints of neighbor two-pixel groupings
		} else {
			dist = distToLine(point, center+vec2(1.0, -0.5+1.0)*pointDir, center+vec2(0.0, 1.5+1.0)*pointDir, pointDir); //midpoints of neighbor two-pixel groupings
		}
		dist -= (_lineWidth/2.0);
		return dist <= 0.0 ? ((cd(d,df) <= cd(d,dd)) ? df : dd) : vec4(-1.0);
	}
	#endif
	return vec4(-1.0);
}

// Pixelorama edit, taken from NearestNeighbour shader
vec2 rotate(vec2 uv, vec2 pivot, float ratio) {
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
	vec2 size = 1.0/TEXTURE_PIXEL_SIZE+0.0001; //fix for some sort of rounding error
	// Pixelorama edit
	vec4 original = texture(TEXTURE, UV);
	float selection = texture(selection_tex, UV).a;
	vec2 pivot = pivot_pixel / size; // Normalize pivot position
	float ratio = size.x / size.y; // Resolution ratio
	vec2 pixelated_uv = floor(UV * size) / (size - 1.0); // Pixelate UV to fit resolutio
	vec2 rotated_uv;
	if (preview) {
		rotated_uv = rotate(pixelated_uv, pivot, ratio);
	}
	else {
		rotated_uv = rotate(UV, pivot, ratio);
	}
	vec2 px = rotated_uv * size;
	vec2 local = fract(px);
	px = ceil(px);

	vec2 pointDir = round(local)*2.0-1.0;

	//neighbor pixels
	//Up, Down, Forward, and Back
	//relative to quadrant of current location within pixel

	vec4 uub = texture(TEXTURE, (px+vec2(-1.0,-2.0)*pointDir)/size);
	vec4 uu  = texture(TEXTURE, (px+vec2( 0.0,-2.0)*pointDir)/size);
	vec4 uuf = texture(TEXTURE, (px+vec2( 1.0,-2.0)*pointDir)/size);

	vec4 ubb = texture(TEXTURE, (px+vec2(-2.0,-2.0)*pointDir)/size);
	vec4 ub  = texture(TEXTURE, (px+vec2(-1.0,-1.0)*pointDir)/size);
	vec4 u   = texture(TEXTURE, (px+vec2( 0.0,-1.0)*pointDir)/size);
	vec4 uf  = texture(TEXTURE, (px+vec2( 1.0,-1.0)*pointDir)/size);
	vec4 uff = texture(TEXTURE, (px+vec2( 2.0,-1.0)*pointDir)/size);

	vec4 bb  = texture(TEXTURE, (px+vec2(-2.0, 0.0)*pointDir)/size);
	vec4 b   = texture(TEXTURE, (px+vec2(-1.0, 0.0)*pointDir)/size);
	vec4 c   = texture(TEXTURE, (px+vec2( 0.0, 0.0)*pointDir)/size);
	vec4 f   = texture(TEXTURE, (px+vec2( 1.0, 0.0)*pointDir)/size);
	vec4 ff  = texture(TEXTURE, (px+vec2( 2.0, 0.0)*pointDir)/size);

	vec4 dbb = texture(TEXTURE, (px+vec2(-2.0, 1.0)*pointDir)/size);
	vec4 db  = texture(TEXTURE, (px+vec2(-1.0, 1.0)*pointDir)/size);
	vec4 d   = texture(TEXTURE, (px+vec2( 0.0, 1.0)*pointDir)/size);
	vec4 df  = texture(TEXTURE, (px+vec2( 1.0, 1.0)*pointDir)/size);
	vec4 dff = texture(TEXTURE, (px+vec2( 2.0, 1.0)*pointDir)/size);

	vec4 ddb = texture(TEXTURE, (px+vec2(-1.0, 2.0)*pointDir)/size);
	vec4 dd  = texture(TEXTURE, (px+vec2( 0.0, 2.0)*pointDir)/size);
	vec4 ddf = texture(TEXTURE, (px+vec2( 1.0, 2.0)*pointDir)/size);

	vec4 col = c;

	//c_orner, b_ack, and u_p slices
	// (slices from neighbor pixels will only ever reach these 3 quadrants
	vec4 c_col = sliceDist(local, vec2( 1.0, 1.0), pointDir, u, uf, uff, b, c, f, ff, db, d, df, dff, ddb, dd, ddf);
	vec4 b_col = sliceDist(local, vec2(-1.0, 1.0), pointDir, u, ub, ubb, f, c, b, bb, df, d, db, dbb, ddf, dd, ddb);
	vec4 u_col = sliceDist(local, vec2( 1.0,-1.0), pointDir, d, df, dff, b, c, f, ff, ub, u, uf, uff, uub, uu, uuf);

	if(c_col.r >= 0.0){
		col = c_col;
	}
	if(b_col.r >= 0.0){
		col = b_col;
	}
	if(u_col.r >= 0.0){
		col = u_col;
	}

    // Pixelorama edit, taken from NearestNeighbour shader
	col.a *= texture(selection_tex, rotated_uv).a; // Combine with selection mask
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
	COLOR.rgb = mix(mix(original.rgb, col.rgb, col.a * border), col.rgb, mask);
	COLOR.a = mix(original.a, 0.0, selection); // Remove alpha on the selected area
	COLOR.a = mix(COLOR.a, 1.0, col.a * border); // Combine alpha of original image and rotated
}
