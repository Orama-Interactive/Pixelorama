extends Node

func import_gpl(path : String) -> Palette:
	var result : Palette = null
	var file = File.new()
	if file.file_exists(path):
		file.open(path, File.READ)
		var text = file.get_as_text()
		var lines = text.split('\n')
		var line_number := 0
		var comments := ""
		for line in lines:
			# Check if valid Gimp Palette Library file
			if line_number == 0:
				if line != "GIMP Palette":
					break
				else:
					result = Palette.new()
					var name_start = path.find_last('/') + 1
					var name_end = path.find_last('.')
					if name_end > name_start:
						result.name = path.substr(name_start, name_end - name_start)

			# Comments
			if line.begins_with('#'):
				comments += line.trim_prefix('#') + '\n'
				pass
			elif line_number > 0 && line.length() >= 12:
				var red : float = line.substr(0, 4).to_float() / 255.0
				var green : float = line.substr(4, 4).to_float() / 255.0
				var blue : float = line.substr(8, 4).to_float() / 255.0
				var name : String = line.substr(12, line.length() - 12)
				var color = Color(red, green, blue)
				result.add_color(color, name)
			line_number += 1

		if result:
			result.comments = comments
		file.close()

	return result
