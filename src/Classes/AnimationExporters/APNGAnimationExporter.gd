class_name APNGAnimationExporter
extends BaseAnimationExporter
# APNG exporter. To be clear, this is effectively magic.

var crc32_table := []


func _init():
	mime_type = "image/apng"
	# Calculate CRC32 table.
	var range8 = range(8)
	for i in range(256):
		var crc = i
		for j in range8:
			if (crc & 1) != 0:
				crc = (crc >> 1) ^ 0xEDB88320
			else:
				crc >>= 1
		crc32_table.push_back(crc & 0xFFFFFFFF)


# Performs the update step of CRC32 over some bytes.
# Note that this is not the whole story.
# The CRC must be initialized to 0xFFFFFFFF, then updated, then bitwise-inverted.
func crc32_data(crc: int, data: PoolByteArray):
	var i = 0
	var l = len(data)
	while i < l:
		var lb = data[i] ^ (crc & 0xFF)
		crc = crc32_table[lb] ^ (crc >> 8)
		i += 1
	return crc


func export_animation(
	images: Array,
	durations: Array,
	fps_hint: float,
	progress_report_obj: Object,
	progress_report_method,
	progress_report_args
) -> PoolByteArray:
	var result = open_chunk()
	# Magic number
	result.put_32(0x89504E47)
	result.put_32(0x0D0A1A0A)
	# From here on out, all data is written in "chunks".
	# IHDR
	var image: Image = images[0]
	var chunk = open_chunk()
	chunk.put_32(image.get_width())
	chunk.put_32(image.get_height())
	chunk.put_32(0x08060000)
	chunk.put_8(0)
	write_chunk(result, "IHDR", chunk.data_array)
	# acTL
	chunk = open_chunk()
	chunk.put_32(len(images))
	chunk.put_32(0)
	write_chunk(result, "acTL", chunk.data_array)
	# For each frame... (note: first frame uses IDAT)
	var sequence = 0
	for i in range(len(images)):
		image = images[i]
		# fcTL
		chunk = open_chunk()
		chunk.put_32(sequence)
		sequence += 1
		# image w/h
		chunk.put_32(image.get_width())
		chunk.put_32(image.get_height())
		# offset x/y
		chunk.put_32(0)
		chunk.put_32(0)
		write_delay(chunk, durations[i], fps_hint)
		# dispose / blend
		chunk.put_8(0)
		chunk.put_8(0)
		write_chunk(result, "fcTL", chunk.data_array)
		# IDAT/fdAT
		chunk = open_chunk()
		if i != 0:
			chunk.put_32(sequence)
			sequence += 1
		# setup chunk interior...
		var ichk = open_chunk()
		write_padded_lines(ichk, image)
		chunk.put_data(ichk.data_array.compress(File.COMPRESSION_DEFLATE))
		# done with chunk interior
		if i == 0:
			write_chunk(result, "IDAT", chunk.data_array)
		else:
			write_chunk(result, "fdAT", chunk.data_array)
		# Done with this frame!
		progress_report_obj.callv(progress_report_method, progress_report_args)
	# Final chunk.
	write_chunk(result, "IEND", PoolByteArray())
	return result.data_array


func write_delay(sp: StreamPeer, duration: float, fps_hint: float):
	# Obvious bounds checking
	duration = max(duration, 0)
	fps_hint = min(32767, max(fps_hint, 1))
	# The assumption behind this is that in most cases durations match the FPS hint.
	# And in most cases the FPS hint is integer.
	# So it follows that num = 1 and den = fps.
	# Precision is increased so we catch more complex cases.
	# But you should always get perfection for integers.
	var den = min(32767, max(fps_hint, 1))
	var num = max(duration, 0) * den
	# If the FPS hint brings us out of range before we start, try some obvious integers
	var fallback = 10000
	while num > 32767:
		num = max(duration, 0) * den
		den = fallback
		if fallback == 1:
			break
		fallback /= 10
	# If the fallback plan failed, give up and set the duration to 1 second.
	if num > 32767:
		sp.put_16(1)
		sp.put_16(1)
		return
	# Raise to highest safe precision
	# This is what handles the more complicated cases (usually).
	while num < 16384 and den < 16384:
		num *= 2
		den *= 2
	# Write out
	sp.put_16(int(round(num)))
	sp.put_16(int(round(den)))


func write_padded_lines(sp: StreamPeer, img: Image):
	if img.get_format() != Image.FORMAT_RGBA8:
		push_warning("Image format in APNGAnimationExporter should only ever be RGBA8.")
		return
	var data = img.get_data()
	var y = 0
	var w = img.get_width()
	var h = img.get_height()
	var base = 0
	while y < h:
		var nl = base + (w * 4)
		var line = data.subarray(base, nl - 1)
		sp.put_8(0)
		sp.put_data(line)
		y += 1
		base = nl


func open_chunk() -> StreamPeerBuffer:
	var result = StreamPeerBuffer.new()
	result.big_endian = true
	return result


func write_chunk(sp: StreamPeer, type: String, data: PoolByteArray):
	sp.put_32(len(data))
	var at = type.to_ascii()
	sp.put_data(at)
	sp.put_data(data)
	var crc = crc32_data(0xFFFFFFFF, at)
	crc = crc32_data(crc, data) ^ 0xFFFFFFFF
	sp.put_32(crc)
