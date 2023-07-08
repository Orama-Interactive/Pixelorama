extends RefCounted

var converter := preload("../converter.gd").new()
var transparency := false


func longest_axis(colors: Array) -> int:
	var start: PackedInt32Array = [255, 255, 255]
	var end: PackedInt32Array = [0, 0, 0]
	for color in colors:
		for i in 3:
			start[i] = mini(color[i], start[i])
			end[i] = maxi(color[i], end[i])

	var max_r := end[0] - start[0]
	var max_g := end[1] - start[1]
	var max_b := end[2] - start[2]

	if max_r > max_g:
		if max_r > max_b:
			return 0
	else:
		if max_g > max_b:
			return 1
	return 2


func get_median(colors: Array) -> Vector3:
	return colors[colors.size() >> 1]


func median_cut(colors: Array) -> Array:
	var axis := longest_axis(colors)

	var axis_sort := []
	for color in colors:
		axis_sort.append(color[axis])
	axis_sort.sort()

	var cut := axis_sort.size() >> 1
	var median: int = axis_sort[cut]
	axis_sort = []

	var left_colors := []
	var right_colors := []

	for color in colors:
		if color[axis] < median:
			left_colors.append(color)
		else:
			right_colors.append(color)

	return [left_colors, right_colors]


func average_color(bucket: Array) -> Array:
	var r := 0
	var g := 0
	var b := 0
	for color in bucket:
		r += color[0]
		g += color[1]
		b += color[2]
	return [r / bucket.size(), g / bucket.size(), b / bucket.size()]


func average_colors(buckets: Array) -> Dictionary:
	var avg_colors := {}
	for bucket in buckets:
		if bucket.size() > 0:
			avg_colors[average_color(bucket)] = avg_colors.size()
	return avg_colors


func pixels_to_colors(image: Image) -> Array:
	var result := []
	var data: PackedByteArray = image.get_data()

	for i in range(0, data.size(), 4):
		if data[i + 3] == 0:
			transparency = true
			continue
		result.append([data[i], data[i + 1], data[i + 2]])
	return result


func remove_smallest_bucket(buckets: Array) -> Array:
	if buckets.size() == 0:
		return buckets
	var i_of_smallest_bucket := 0
	for i in range(buckets.size()):
		if buckets[i].size() < buckets[i_of_smallest_bucket].size():
			i_of_smallest_bucket = i
	buckets.remove_at(i_of_smallest_bucket)
	return buckets


func remove_empty_buckets(buckets: Array) -> Array:
	if buckets.size() == 0:
		return buckets

	var i := buckets.find([])
	while i != -1:
		buckets.remove_at(i)
		i = buckets.find([])

	return buckets


## Quantizes to gif ready codes
func quantize(image: Image) -> Array:
	var pixels := pixels_to_colors(image)
	if pixels.size() == 0:
		return pixels

	var buckets := [pixels]
	var done_buckets := []

	# it tells how many times buckets should be divided into two
	var dimensions := 8

	for i in range(0, dimensions):
		var new_buckets := []
		for bucket in buckets:
			# don't median cut if bucket is smaller than 2, because
			# it won't produce two new buckets.
			if bucket.size() > 1:
				var res := median_cut(bucket)
				# sometimes when you try to median cut a bucket, the result
				# is one with size equal to 0 and other with full size as the
				# source bucket. Because of that it's useless to try to divide
				# it further so it's better to put it into separate list and
				# process only those buckets witch divide further.
				if res[0].size() == 0 or res[1].size() == 0:
					done_buckets += res
				else:
					new_buckets += res
		buckets = []
		buckets = new_buckets

	var all_buckets := remove_empty_buckets(done_buckets + buckets)

	buckets = []
	done_buckets = []

	if transparency:
		if all_buckets.size() == pow(2, dimensions):
			all_buckets = remove_smallest_bucket(all_buckets)

	# dictionaries are only for speed.
	var color_array := average_colors(all_buckets).keys()

	# if pixel_to_colors detected that the image has transparent pixels
	# then add transparency color at the beginning so it will be properly
	# exported.
	if transparency:
		color_array = [[0, 0, 0]] + color_array

	var data: PackedByteArray = converter.get_similar_indexed_datas(image, color_array)

	return [data, color_array, transparency]
