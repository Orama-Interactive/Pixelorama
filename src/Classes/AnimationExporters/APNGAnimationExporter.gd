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

func export_animation(images: Array, durations: Array, fps_hint: float, progress_report_obj: Object, progress_report_method, progress_report_args) -> PoolByteArray:
	var result = StreamPeerBuffer.new()
	result.big_endian = true
	# Magic number
	result.put_32(0x89504E47)
	result.put_32(0x0D0A1A0A)
	# From here on out, all data is written in "chunks".
	# Final chunk.
	write_chunk(result, "IEND", PoolByteArray())
	return result.data_array

func write_chunk(sp: StreamPeer, type: String, data: PoolByteArray):
	sp.put_32(len(data))
	var at = type.to_ascii()
	sp.put_data(at)
	sp.put_data(data)
	var crc = crc32_data(0xFFFFFFFF, at)
	crc = crc32_data(crc, data) ^ 0xFFFFFFFF
	sp.put_32(crc)
