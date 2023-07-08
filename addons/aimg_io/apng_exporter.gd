class_name AImgIOAPNGExporter
extends AImgIOBaseExporter
# APNG exporter. To be clear, this is effectively magic.


func _init():
	mime_type = "image/apng"


func export_animation(
	frames: Array,
	fps_hint: float,
	progress_report_obj: Object,
	progress_report_method,
	progress_report_args
) -> PackedByteArray:
	var frame_count := len(frames)
	var result := AImgIOAPNGStream.new()
	# Magic number
	result.write_magic()
	# From here on out, all data is written in "chunks".
	# IHDR
	var image: Image = frames[0].content
	var chunk := result.start_chunk()
	chunk.put_32(image.get_width())
	chunk.put_32(image.get_height())
	chunk.put_32(0x08060000)
	chunk.put_8(0)
	result.write_chunk("IHDR", chunk.data_array)
	# acTL
	chunk = result.start_chunk()
	chunk.put_32(frame_count)
	chunk.put_32(0)
	result.write_chunk("acTL", chunk.data_array)
	# For each frame... (note: first frame uses IDAT)
	var sequence := 0
	for i in range(frame_count):
		image = frames[i].content
		# fcTL
		chunk = result.start_chunk()
		chunk.put_32(sequence)
		sequence += 1
		# image w/h
		chunk.put_32(image.get_width())
		chunk.put_32(image.get_height())
		# offset x/y
		chunk.put_32(0)
		chunk.put_32(0)
		write_delay(chunk, frames[i].duration, fps_hint)
		# dispose / blend
		chunk.put_8(0)
		chunk.put_8(0)
		# So depending on who you ask, there might be supposed to be a second
		#  checksum here. The problem is, if there is, it's not well-explained.
		# Plus, actual readers don't seem to require it.
		# And the W3C specification just copy/pastes the (bad) Mozilla spec.
		# Dear Mozilla spec writers: If you wanted a second checksum,
		#  please indicate it's existence in the fcTL chunk structure.
		result.write_chunk("fcTL", chunk.data_array)
		# IDAT/fdAT
		chunk = result.start_chunk()
		if i != 0:
			chunk.put_32(sequence)
			sequence += 1
		# setup chunk interior...
		var ichk := result.start_chunk()
		write_padded_lines(ichk, image)
		chunk.put_data(ichk.data_array.compress(FileAccess.COMPRESSION_DEFLATE))
		# done with chunk interior
		if i == 0:
			result.write_chunk("IDAT", chunk.data_array)
		else:
			result.write_chunk("fdAT", chunk.data_array)
		# Done with this frame!
		progress_report_obj.callv(progress_report_method, progress_report_args)
	# Final chunk.
	result.write_chunk("IEND", PackedByteArray())
	return result.finish()


func write_delay(sp: StreamPeer, duration: float, fps_hint: float):
	# Obvious bounds checking
	duration = max(duration, 0)
	fps_hint = min(32767, max(fps_hint, 1))
	# The assumption behind this is that in most cases durations match the FPS hint.
	# And in most cases the FPS hint is integer.
	# So it follows that num = 1 and den = fps.
	# Precision is increased so we catch more complex cases.
	# But you should always get perfection for integers.
	var den := min(32767, max(fps_hint, 1))
	var num: float = max(duration, 0) * den
	# If the FPS hint brings us out of range before we start, try some obvious integers
	var fallback := 10000
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
		push_warning("Image format in AImgIOAPNGExporter should only ever be RGBA8.")
		return
	var data := img.get_data()
	var y := 0
	var w := img.get_width()
	var h := img.get_height()
	var base := 0
	while y < h:
		var nl := base + (w * 4)
		var line := data.slice(base, nl)
		sp.put_8(0)
		sp.put_data(line)
		y += 1
		base = nl
