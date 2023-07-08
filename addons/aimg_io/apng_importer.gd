@tool
class_name AImgIOAPNGImporter
extends RefCounted
# Will NOT import regular, unanimated PNGs - use Image.load_png_from_buffer
# This is because we don't want to import the default image as a frame
# Therefore it just uses the rule:
#  "fcTL chunk always precedes an APNG frame, even if that includes IDAT"


# Imports an APNG PoolByteArray into an animation as an Array of frames.
# Returns [error, frames] similar to some read functions.
# However, error is a string.
static func load_from_buffer(buffer: PackedByteArray) -> Array:
	var stream := AImgIOAPNGStream.new(buffer)
	var magic_str = stream.read_magic()
	if magic_str != null:
		# well, that was a nope
		return [magic_str, null]
	# Ok, so, before we continue, let's establish what is and is not okay
	#  for the target of this importer.

	# Firstly, thankfully, we don't have to worry about colour profiles or any
	#  ancillary chunks that involve them.
	# Godot doesn't care and caring would break images meant for non-colour use.
	# If for some reason you care and consider this a hot take:
	#  + Just perceptual-intent sRGB at display driver / hardware level.
	#  + Anyone who really cares about colourimetric intent should NOT use RGB.
	# (This said, the gAMA chunk has its uses in realistic usecases.
	#  Having a way to specify linear vs. non-linear RGB isn't inherently bad.)
	# Secondly, we DO have to worry about tRNS.
	# tRNS is an "optional" chunk to support.
	# ...same as fcTL is "optional".
	# The file would decode but actual meaningful data is lost.
	# Thirdly, the size of an APNG frame is not necessarily the original size.
	# So to convert an APNG frame to a PNG for reading, we need to stitch:
	# IHDR (modified), PLTE (if present), tRNS (if present), IDAT (from fdAT),
	#  and IEND (generated).
	var ihdr := PackedByteArray()
	var plte := PackedByteArray()
	var trns := PackedByteArray()
	# stored full width/height for buffer
	var width := 0
	var height := 0
	# parse chunks
	var frames: Array[BFrame] = []
	while stream.read_chunk() == OK:
		if stream.chunk_type == "IHDR":
			ihdr = stream.chunk_data
			# extract necessary information
			if len(ihdr) < 8:
				return ["IHDR not even large enough for W/H", null]
			var sp := StreamPeerBuffer.new()
			sp.data_array = ihdr
			sp.big_endian = true
			width = sp.get_32()
			height = sp.get_32()
		elif stream.chunk_type == "PLTE":
			plte = stream.chunk_data
		elif stream.chunk_type == "tRNS":
			trns = stream.chunk_data
		elif stream.chunk_type == "fcTL":
			var f := BFrame.new()
			var err = f.setup(stream.chunk_data)
			if err != null:
				return [err, null]
			frames.push_back(f)
		elif stream.chunk_type == "IDAT":
			# add to last frame if any
			# this uses the lack of the fcTL for the default image on purpose,
			# while still handling frame 0 as IDAT properly
			if len(frames) > 0:
				var f: BFrame = frames[len(frames) - 1]
				f.add_data(stream.chunk_data)
		elif stream.chunk_type == "fdAT":
			# it's just frame data
			# we ignore seq. nums. if they're wrong, file's invalid
			# so if there are issues, we don't have to support them
			if len(frames) > 0:
				var f: BFrame = frames[len(frames) - 1]
				if len(stream.chunk_data) >= 4:
					var data := stream.chunk_data.slice(4, len(stream.chunk_data))
					f.add_data(data)
	# theoretically we *could* store the default frame somewhere, but *why*?
	# just use Image functions if you want that
	if len(frames) == 0:
		return ["No frames", null]
	# prepare initial operating buffer
	var operating := Image.create(width, height, false, Image.FORMAT_RGBA8)
	operating.fill(Color(0, 0, 0, 0))
	var finished: Array[AImgIOFrame] = []
	for v in frames:
		var fv: BFrame = v
		# Ok, so to avoid having to deal with filters and stuff,
		#  what we do here is generate intermediary single-frame PNG files.
		# Whoever specced APNG either managed to make a good format by accident,
		#  or had a very good understanding of the concerns of people who need
		#  to retrofit their PNG decoders into APNG decoders, because the fact
		#  you can even do this is *beautiful*.
		var intermediary := fv.intermediary(ihdr, plte, trns)
		var intermediary_img := Image.new()
		if intermediary_img.load_png_from_buffer(intermediary) != OK:
			return ["error during intermediary load - corrupt/bug?", null]
		intermediary_img.convert(Image.FORMAT_RGBA8)
		# dispose vars
		var blit_target := operating
		var copy_blit_target := true
		# rectangles and such
		var blit_src := Rect2i(Vector2i.ZERO, intermediary_img.get_size())
		var blit_pos := Vector2i(fv.x, fv.y)
		var blit_tgt := Rect2i(blit_pos, intermediary_img.get_size())
		# early dispose ops
		if fv.dispose_op == 2:
			# previous
			# we handle this by never actually writing to the operating buffer,
			#  but instead a copy (so we don't have to make another later)
			blit_target = Image.new()
			blit_target.copy_from(operating)
			copy_blit_target = false
		# actually blit
		if blit_src.size != Vector2i.ZERO:
			if fv.blend_op == 0:
				blit_target.blit_rect(intermediary_img, blit_src, blit_pos)
			else:
				blit_target.blend_rect(intermediary_img, blit_src, blit_pos)
		# insert as frame
		var ffin := AImgIOFrame.new()
		ffin.duration = fv.duration
		if copy_blit_target:
			var img := Image.new()
			img.copy_from(operating)
			ffin.content = img
		else:
			ffin.content = blit_target
		finished.push_back(ffin)
		# late dispose ops
		if fv.dispose_op == 1:
			# background
			# this works as you expect
			operating.fill_rect(blit_tgt, Color(0, 0, 0, 0))
	return [null, finished]


# Imports an APNG file into an animation as an array of frames.
# Returns null on error.
static func load_from_file(path: String) -> Array:
	var o := FileAccess.open(path, FileAccess.READ)
	if o == null:
		return [null, "Unable to open file: " + path]
	var l = o.get_length()
	var data = o.get_buffer(l)
	o.close()
	return load_from_buffer(data)


# Intermediate frame structure
class BFrame:
	extends RefCounted
	var dispose_op: int
	var blend_op: int
	var x: int
	var y: int
	var w: int
	var h: int
	var duration: float
	var data: PackedByteArray

	func setup(fctl: PackedByteArray):
		if len(fctl) < 26:
			return ""
		var sp := StreamPeerBuffer.new()
		sp.data_array = fctl
		sp.big_endian = true
		sp.get_32()
		w = sp.get_32() & 0xFFFFFFFF
		h = sp.get_32() & 0xFFFFFFFF
		# theoretically these are supposed to be unsigned, but like...
		# that just contributes to the assertion of it being inbounds, really.
		# so since blitting will do the crop anyway, let's just be generous
		x = sp.get_32()
		y = sp.get_32()
		var num := float(sp.get_16() & 0xFFFF)
		var den := float(sp.get_16() & 0xFFFF)
		if den == 0.0:
			den = 100
		duration = num / den
		dispose_op = sp.get_8()
		blend_op = sp.get_8()
		return null

	# Creates an intermediary PNG.
	# This can be loaded by Godot directly.
	# This basically skips most of the APNG decoding process.
	func intermediary(
		ihdr: PackedByteArray, plte: PackedByteArray, trns: PackedByteArray
	) -> PackedByteArray:
		# Might be important to note this operates on a copy of ihdr (by-value).
		var sp := StreamPeerBuffer.new()
		sp.data_array = ihdr
		sp.big_endian = true
		sp.put_32(w)
		sp.put_32(h)
		var intermed := AImgIOAPNGStream.new()
		intermed.write_magic()
		intermed.write_chunk("IHDR", sp.data_array)
		if len(plte) > 0:
			intermed.write_chunk("PLTE", plte)
		if len(trns) > 0:
			intermed.write_chunk("tRNS", trns)
		intermed.write_chunk("IDAT", data)
		intermed.write_chunk("IEND", PackedByteArray())
		return intermed.finish()

	func add_data(d: PackedByteArray):
		data.append_array(d)
