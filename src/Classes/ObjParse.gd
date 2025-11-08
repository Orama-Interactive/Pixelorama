class_name ObjParse
extends Object
## A static helper script for parsing OBJ/MTL files at runtime.

# gd-obj
# https://github.com/Ezcha/gd-obj
#
# Created on 7/11/2018
# Refactored 9/18/2025
#
# Originally made by Dylan (https://ezcha.net)
# Contributors: DaniKog, deakcor, jeffgamedev, kb173
#
# MIT License
# https://github.com/Ezcha/gd-obj/blob/master/LICENSE

const PRINT_DEBUG: bool = false
const PRINT_COMMENTS: bool = false
const TEXTURE_KEYS: Array[String] = [
	"map_kd", "map_disp", "disp", "map_bump", "map_normal", "bump", "map_ao", "map_ks"
]

# Main functions


## Returns a mesh parsed from obj and mtl paths
static func from_path(obj_path: String, mtl_path: String = "") -> Mesh:
	var obj_str: String = _read_file_str(obj_path)
	if obj_str.is_empty():
		return null
	if mtl_path.is_empty():
		var mtl_filename: String = _get_mtl_filename(obj_str)
		if mtl_filename.is_empty():
			return _create_obj(obj_str, {})
		mtl_path = obj_path.get_base_dir() + "/" + mtl_filename
	var materials: Dictionary[String, StandardMaterial3D] = _create_mtl(
		_read_file_str(mtl_path), _get_mtl_tex(mtl_path)
	)
	return _create_obj(obj_str, materials)


## Returns a mesh parsed from an OBJ string
static func from_obj_string(
	obj_data: String, materials: Dictionary[String, StandardMaterial3D] = {}
) -> Mesh:
	return _create_obj(obj_data, materials)


## Returns materials parsed from an MTL string
static func from_mtl_string(
	mtl_data: String, textures: Dictionary[String, ImageTexture] = {}
) -> Dictionary[String, StandardMaterial3D]:
	return _create_mtl(mtl_data, textures)


# Internal functions


static func _prefix_print(...args: Array) -> void:
	args.insert(0, "[ObjParse]")
	prints(args)


static func _debug_msg(...args: Array) -> void:
	if !PRINT_DEBUG:
		return
	_prefix_print(args)


# Get data from file path
static func _read_file_str(path: String) -> String:
	if path.is_empty():
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


# Get textures from mtl path
static func _get_mtl_tex(mtl_path: String) -> Dictionary[String, ImageTexture]:
	var file_paths: Array[String] = _get_mtl_tex_paths(mtl_path)
	var textures: Dictionary[String, ImageTexture] = {}
	for k: String in file_paths:
		var img: Image = _get_image(mtl_path, k)
		if img.is_empty():
			continue
		textures[k] = ImageTexture.create_from_image(img)
	return textures


# Get textures paths from mtl path
static func _get_mtl_tex_paths(mtl_path: String) -> Array[String]:
	var file: FileAccess = FileAccess.open(mtl_path, FileAccess.READ)
	if file == null:
		return []
	var paths: Array[String] = []
	var lines: PackedStringArray = file.get_as_text().split("\n", false)
	for line: String in lines:
		var parts: PackedStringArray = line.split(" ", false, 1)
		if !TEXTURE_KEYS.has(parts[0].to_lower()):
			continue
		if paths.has(parts[1]):
			continue
		paths.append(parts[1])
	return paths


static func _get_mtl_filename(obj: String) -> String:
	var lines: PackedStringArray = obj.split("\n")
	for line: String in lines:
		var split: PackedStringArray = line.split(" ", false)
		if split.size() < 2:
			continue
		if split[0] != "mtllib":
			continue
		return split[1].strip_edges()
	return ""


static func _create_mtl(
	obj: String, textures: Dictionary[String, ImageTexture]
) -> Dictionary[String, StandardMaterial3D]:
	if obj.is_empty():
		return {}
	var materials: Dictionary[String, StandardMaterial3D] = {}
	var current_material: StandardMaterial3D = null
	var lines: PackedStringArray = obj.split("\n", false)
	for line: String in lines:
		var parts: PackedStringArray = line.split(" ", false)
		match parts[0].to_lower():
			"#":
				if !PRINT_COMMENTS:
					continue
				_prefix_print(line)
			"newmtl":
				# New material
				if parts.size() < 2:
					_debug_msg("New material is missing a name")
					continue
				var mat_name: String = parts[1].strip_edges()
				_debug_msg("Adding new material", mat_name)
				current_material = StandardMaterial3D.new()
				materials[mat_name] = current_material
			"kd":
				# Albedo color
				if parts.size() < 4:
					_debug_msg("Invalid albedo/diffuse color")
					continue
				current_material.albedo_color = Color(
					parts[1].to_float(), parts[2].to_float(), parts[3].to_float()
				)
			"map_kd":
				# Albedo texture
				var path: String = line.split(" ", false, 1)[1]
				if !textures.has(path):
					continue
				current_material.albedo_texture = textures[path]
			"map_disp", "disp":
				# Heightmap
				var path: String = line.split(" ", false, 1)[1]
				if !textures.has(path):
					continue
				current_material.heightmap_enabled = true
				current_material.heightmap_texture = textures[path]
			"map_bump", "map_normal", "bump":
				# Normal map
				var path: String = line.split(" ", false, 1)[1]
				if !textures.has(path):
					continue
				current_material.normal_enabled = true
				current_material.normal_texture = textures[path]
			"map_ao":
				# AO map
				var path: String = line.split(" ", false, 1)[1]
				if !textures.has(path):
					continue
				current_material.ao_texture = textures[path]
			"map_ks":
				# Roughness map
				var path: String = line.split(" ", false, 1)[1]
				if !textures.has(path):
					continue
				current_material.roughness_texture = textures[path]
			_:
				# Unsupported feature
				pass
	return materials


static func _parse_mtl_file(path: String) -> Dictionary[String, StandardMaterial3D]:
	return _create_mtl(_read_file_str(path), _get_mtl_tex(path))


static func _get_image(mtl_filepath: String, tex_filename: String) -> Image:
	_debug_msg("Mapping texture file", tex_filename)
	var tex_filepath: String = tex_filename
	if tex_filename.is_relative_path():
		tex_filepath = mtl_filepath.get_base_dir() + "/" + tex_filename
		tex_filepath = tex_filepath.strip_edges()
	var file_type: String = tex_filepath.get_extension()
	_debug_msg("Texture file path:", tex_filepath, "of type", file_type)

	var img: Image = Image.new()
	img.load(tex_filepath)
	return img


static func _get_texture(mtl_filepath, tex_filename) -> ImageTexture:
	var tex = ImageTexture.create_from_image(_get_image(mtl_filepath, tex_filename))
	_debug_msg("Texture is", str(tex))
	return tex


static func _create_obj(obj: String, materials: Dictionary[String, StandardMaterial3D]) -> Mesh:
	# Prepare
	var mat_name: String = "_default"
	if !materials.has("_default"):
		materials["_default"] = StandardMaterial3D.new()
	var mesh: ArrayMesh = ArrayMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array([Vector3.ZERO])
	var normals: PackedVector3Array = PackedVector3Array([Vector3.ONE])
	var uvs: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	var faces: Dictionary[String, Array] = {}
	for mat_key: String in materials.keys():
		faces[mat_key] = []

	# Parse
	var lines: PackedStringArray = obj.split("\n", false)
	for line: String in lines:
		if line.is_empty():
			continue
		var feature: String = line.substr(0, line.find(" "))
		match feature:
			"#":
				# Comment
				if !PRINT_COMMENTS:
					continue
				_prefix_print(line)
			"v":
				# Vertice
				var line_remaining: String = line.substr(feature.length() + 1)
				var parts: PackedFloat64Array = line_remaining.split_floats(" ")
				var n_v: Vector3 = Vector3(parts[0], parts[1], parts[2])
				vertices.append(n_v)
			"vn":
				# Normal
				var line_remaining: String = line.substr(feature.length() + 1)
				var parts: PackedFloat64Array = line_remaining.split_floats(" ")
				var n_vn: Vector3 = Vector3(parts[0], parts[1], parts[2])
				normals.append(n_vn)
			"vt":
				# UV
				var line_remaining: String = line.substr(feature.length() + 1)
				var parts: PackedFloat64Array = line_remaining.split_floats(" ")
				var n_uv: Vector2 = Vector2(parts[0], 1 - parts[1])
				uvs.append(n_uv)
			"usemtl":
				# Material group
				mat_name = line.substr(feature.length() + 1).strip_edges()
				# Fallback to default if material is not available
				if faces.has(mat_name):
					continue
				mat_name = "_default"
			"f":
				# Face
				var line_remaining: String = line.substr(feature.length() + 1)
				var def_count: int = line_remaining.count(" ") + 1
				var components_per: int = (
					line_remaining.substr(0, line_remaining.find(" ") - 1).count("/") + 1
				)
				var sectioned: bool = components_per > 1
				if line_remaining.find("/"):
					line_remaining = line_remaining.replace("//", " 0 ").replace("/", " ")
				var parts: PackedFloat64Array = line_remaining.split_floats(" ", false)
				if sectioned:
					if parts.size() % components_per != 0:
						_debug_msg("Face needs 3+ parts to be valid")
						continue
				elif parts.size() < 3:
					_debug_msg("Face needs 3+ parts to be valid")
					continue
				var face: ObjParseFace = ObjParseFace.new()
				for cursor: int in def_count:
					if sectioned:
						cursor *= components_per
					face.v.append(int(parts[cursor]))
					face.vt.append(int(parts[cursor + 1]) if sectioned else 0)
					face.vn.append(int(parts[cursor + 2]) if sectioned else 0)
				# Continue if already a tri
				if def_count == 3:
					faces[mat_name].append(face)
					continue
				# Quad/ngon detected, triangulate
				for i: int in range(1, def_count - 1):
					var tri_face: ObjParseFace = ObjParseFace.new()
					tri_face.v.append(face.v[0])
					tri_face.v.append(face.v[i])
					tri_face.v.append(face.v[i + 1])
					tri_face.vt.append(face.vt[0])
					tri_face.vt.append(face.vt[i])
					tri_face.vt.append(face.vt[i + 1])
					tri_face.vn.append(face.vn[0])
					tri_face.vn.append(face.vn[i])
					tri_face.vn.append(face.vn[i + 1])
					faces[mat_name].append(tri_face)
			_:
				# Unsupported feature
				pass

	# Skip if no faces were parsed
	if faces.size() == 1 && faces["_default"].is_empty():
		return mesh

	# Make tri
	for mat_group: String in faces.keys():
		_debug_msg(
			"Creating surface for material",
			mat_group,
			"with",
			str(faces[mat_group].size()),
			"faces"
		)

		# Prepare mesh assembly
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

		# Determine material
		if !materials.has(mat_group):
			materials[mat_group] = StandardMaterial3D.new()
		st.set_material(materials[mat_group])

		# Assembly
		for face: ObjParseFace in faces[mat_group]:
			# Vertices
			var fan_v: PackedVector3Array = PackedVector3Array()
			fan_v.append(vertices[face.v[0]])
			fan_v.append(vertices[face.v[2]])
			fan_v.append(vertices[face.v[1]])
			# Normals
			var fan_vn: PackedVector3Array = PackedVector3Array()
			fan_vn.append(normals[face.vn[0]])
			fan_vn.append(normals[face.vn[2]])
			fan_vn.append(normals[face.vn[1]])
			# Textures
			var fan_vt: PackedVector2Array = PackedVector2Array()
			for k: int in [0, 2, 1]:
				var f = face.vt[k]
				if f < 0 || f >= uvs.size():
					continue
				var uv: Vector2 = uvs[f]
				fan_vt.append(uv)
			st.add_triangle_fan(fan_v, fan_vt, PackedColorArray(), PackedVector2Array(), fan_vn, [])

		# Append to final mesh
		mesh = st.commit(mesh)

	# Apply materials to surfaces
	for k: int in mesh.get_surface_count():
		var mat: Material = mesh.surface_get_material(k)
		mat_name = ""
		for m: String in materials:
			if materials[m] != mat:
				continue
			mat_name = m
		mesh.surface_set_name(k, mat_name)

	# All done!
	return mesh


class ObjParseFace:
	extends RefCounted
	var v: PackedInt32Array = PackedInt32Array()
	var vt: PackedInt32Array = PackedInt32Array()
	var vn: PackedInt32Array = PackedInt32Array()
