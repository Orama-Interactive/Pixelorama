class_name ObjParse
extends Object

const DEBUG: bool = false

# gd-obj
#
# Created on 7/11/2018
#
# Originally made by Ezcha
# Contributors: deakcor, kb173, jeffgamedev
#
# https://ezcha.net
# https://github.com/Ezcha/gd-obj
#
# MIT License
# https://github.com/Ezcha/gd-obj/blob/master/LICENSE


# Create mesh from obj and mtl paths
static func load_obj(obj_path: String, mtl_path: String = "") -> Mesh:
	var obj_str: String = _read_file_str(obj_path)
	if mtl_path == "":
		var mtl_filename: String = _get_mtl_filename(obj_str)
		mtl_path = "%s/%s" % [obj_path.get_base_dir(), mtl_filename]
	var mats: Dictionary = {}
	if mtl_path != "":
		mats = _create_mtl(_read_file_str(mtl_path), _get_mtl_tex(mtl_path))
	if obj_str.is_empty():
		return null
	return _create_obj(obj_str, mats)


# Create mesh from obj, materials. Materials should be { "matname": data }
static func load_obj_from_buffer(obj_data: String, materials: Dictionary) -> Mesh:
	return _create_obj(obj_data, materials)


# Create materials
static func load_mtl_from_buffer(mtl_data: String, textures: Dictionary) -> Dictionary:
	return _create_mtl(mtl_data, textures)


# Get data from file path
static func _read_file_str(path: String) -> String:
	if path == "":
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


# Internal functions


# Get textures from mtl path (returns { "tex_path": data })
static func _get_mtl_tex(mtl_path: String) -> Dictionary:
	var file_paths: Array[String] = _get_mtl_tex_paths(mtl_path)
	var textures: Dictionary = {}
	for k in file_paths:
		textures[k] = _get_image(mtl_path, k).save_png_to_buffer()
	return textures


# Get textures paths from mtl path
static func _get_mtl_tex_paths(mtl_path: String) -> Array[String]:
	var file: FileAccess = FileAccess.open(mtl_path, FileAccess.READ)
	if file == null:
		return []

	var paths: Array[String] = []
	var lines: PackedStringArray = file.get_as_text().split("\n", false)
	for line in lines:
		var parts: PackedStringArray = line.split(" ", false, 1)
		if ["map_Kd", "map_Ks", "map_Ka"].has(parts[0]):
			if !paths.has(parts[1]):
				paths.push_back(parts[1])
	return paths


static func _get_mtl_filename(obj: String) -> String:
	var lines: PackedStringArray = obj.split("\n")
	for line in lines:
		var split: PackedStringArray = line.split(" ", false)
		if split.size() < 2:
			continue
		if split[0] != "mtllib":
			continue
		return split[1].strip_edges()
	return ""


static func _create_mtl(obj: String, textures: Dictionary) -> Dictionary:
	var mats: Dictionary = {}
	var current_mat: StandardMaterial3D = null

	var lines: PackedStringArray = obj.split("\n", false)
	for line in lines:
		var parts: PackedStringArray = line.split(" ", false)
		match parts[0]:
			"#":
				# Comment
				pass
			"newmtl":
				# Create a new material
				if DEBUG:
					prints("Adding new material", parts[1])
				current_mat = StandardMaterial3D.new()
				mats[parts[1]] = current_mat
			"Ka":
				# Ambient color
				#current_mat.albedo_color = Color(float(parts[1]), float(parts[2]), float(parts[3]))
				pass
			"Kd":
				# Diffuse color
				current_mat.albedo_color = Color(
					parts[1].to_float(), parts[2].to_float(), parts[3].to_float()
				)
				if DEBUG:
					prints("Setting material color", str(current_mat.albedo_color))
			_:
				if parts[0] in ["map_Kd", "map_Ks", "map_Ka"]:
					var path: String = line.split(" ", false, 1)[1]
					if textures.has(path):
						current_mat.albedo_texture = _create_texture(textures[path])
	return mats


static func _parse_mtl_file(path) -> Dictionary:
	return _create_mtl(_read_file_str(path), _get_mtl_tex(path))


static func _get_image(mtl_filepath: String, tex_filename: String) -> Image:
	if DEBUG:
		prints("Debug: Mapping texture file", tex_filename)
	var tex_filepath: String = tex_filename
	if tex_filename.is_relative_path():
		tex_filepath = "%s/%s" % [mtl_filepath.get_base_dir(), tex_filename]
	var file_type: String = tex_filepath.get_extension()
	if DEBUG:
		prints("Debug: texture file path:", tex_filepath, "of type", file_type)

	var img: Image = Image.new()
	img.load(tex_filepath)
	return img


static func _create_texture(data: PackedByteArray) -> ImageTexture:
	var img: Image = Image.new()
	img.load_png_from_buffer(data)
	return ImageTexture.create_from_image(img)


static func _get_texture(mtl_filepath, tex_filename) -> ImageTexture:
	var tex = ImageTexture.create_from_image(_get_image(mtl_filepath, tex_filename))
	if DEBUG:
		prints("Debug: texture is", str(tex))
	return tex


static func _create_obj(obj: String, mats: Dictionary) -> Mesh:
	# Setup
	var mesh: ArrayMesh = ArrayMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var faces: Dictionary = {}

	var mat_name: String = "default"
	var count_mtl: int = 0

	# Parse
	var lines: PackedStringArray = obj.split("\n", false)
	for line in lines:
		var parts: PackedStringArray = line.split(" ", false)
		match parts[0]:
			"#":
				# Comment
				pass
			"v":
				# Vertice
				var n_v: Vector3 = Vector3(
					parts[1].to_float(), parts[2].to_float(), parts[3].to_float()
				)
				vertices.append(n_v)
			"vn":
				# Normal
				var n_vn: Vector3 = Vector3(
					parts[1].to_float(), parts[2].to_float(), parts[3].to_float()
				)
				normals.append(n_vn)
			"vt":
				# UV
				var n_uv: Vector2 = Vector2(parts[1].to_float(), 1 - parts[2].to_float())
				uvs.append(n_uv)
			"usemtl":
				# Material group
				count_mtl += 1
				mat_name = parts[1].strip_edges()
				if !faces.has(mat_name):
					var mats_keys: Array = mats.keys()
					if !mats.has(mat_name):
						if mats_keys.size() > count_mtl:
							mat_name = mats_keys[count_mtl]
					faces[mat_name] = []
			"f":
				if !faces.has(mat_name):
					var mats_keys: Array = mats.keys()
					if mats_keys.size() > count_mtl:
						mat_name = mats_keys[count_mtl]
					faces[mat_name] = []
				# Face
				if parts.size() == 4:
					# Tri
					var face: Dictionary = {"v": [], "vt": [], "vn": []}
					for map in parts:
						var vertices_index: PackedStringArray = map.split("/")
						if vertices_index[0] != "f":
							face["v"].append(vertices_index[0].to_int() - 1)
							if vertices_index.size() > 1:
								face["vt"].append(vertices_index[1].to_int() - 1)
								if vertices_index.size() > 2:
									face["vn"].append(vertices_index[2].to_int() - 1)
					if faces.has(mat_name):
						faces[mat_name].append(face)
				elif parts.size() > 4:
					# Triangulate
					var points: Array[Array] = []
					for map in parts:
						var vertices_index: PackedStringArray = map.split("/")
						if vertices_index[0] != "f":
							var point: Array[int] = []
							point.append(vertices_index[0].to_int() - 1)
							point.append(vertices_index[1].to_int() - 1)
							if vertices_index.size() > 2:
								point.append(vertices_index[2].to_int() - 1)
							points.append(point)
					for i in points.size():
						if i != 0:
							var face = {"v": [], "vt": [], "vn": []}
							var point0: Array[int] = points[0]
							var point1: Array[int] = points[i]
							var point2: Array[int] = points[i - 1]
							face["v"].append(point0[0])
							face["v"].append(point2[0])
							face["v"].append(point1[0])
							face["vt"].append(point0[1])
							face["vt"].append(point2[1])
							face["vt"].append(point1[1])
							if point0.size() > 2:
								face["vn"].append(point0[2])
							if point2.size() > 2:
								face["vn"].append(point2[2])
							if point1.size() > 2:
								face["vn"].append(point1[2])
							faces[mat_name].append(face)

	# Make tri
	for matgroup in faces.keys():
		if DEBUG:
			prints(
				"Creating surface for matgroup",
				matgroup,
				"with",
				str(faces[matgroup].size()),
				"faces"
			)

		# Mesh Assembler
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if !mats.has(matgroup):
			mats[matgroup] = StandardMaterial3D.new()
		st.set_material(mats[matgroup])
		for face in faces[matgroup]:
			if face["v"].size() == 3:
				# Vertices
				var fan_v: PackedVector3Array = PackedVector3Array()
				fan_v.append(vertices[face["v"][0]])
				fan_v.append(vertices[face["v"][2]])
				fan_v.append(vertices[face["v"][1]])

				# Normals
				var fan_vn: PackedVector3Array = PackedVector3Array()
				if face["vn"].size() > 0:
					fan_vn.append(normals[face["vn"][0]])
					fan_vn.append(normals[face["vn"][2]])
					fan_vn.append(normals[face["vn"][1]])

				# Textures
				var fan_vt: PackedVector2Array = PackedVector2Array()
				if face["vt"].size() > 0:
					for k in [0, 2, 1]:
						var f = face["vt"][k]
						if f > -1:
							var uv = uvs[f]
							fan_vt.append(uv)
				st.add_triangle_fan(
					fan_v, fan_vt, PackedColorArray(), PackedVector2Array(), fan_vn, []
				)
		mesh = st.commit(mesh)

	for k in mesh.get_surface_count():
		var mat: Material = mesh.surface_get_material(k)
		mat_name = ""
		for m in mats:
			if mats[m] == mat:
				mat_name = m
		mesh.surface_set_name(k, mat_name)

	# Finish
	return mesh
