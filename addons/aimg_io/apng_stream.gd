@tool
class_name AImgIOAPNGStream
extends RefCounted
# APNG IO context. To be clear, this is still effectively magic.

# Quite critical we preload this. Preloading creates static variables.
# (Which GDScript doesn't really have, but we need since we have no tree access)
var crc32: AImgIOCRC32 = preload("apng_crc32.tres")

var chunk_type: String
var chunk_data: PackedByteArray

# The reason this must be a StreamPeerBuffer is simple:
# 1. We need to support in-memory IO for HTML5 to really work
# 2. We need get_available_bytes to be completely accurate in all* cases
#    * A >2GB file doesn't count. Godot limitations.
#     because get_32 can return arbitrary nonsense on error.
# It might have been worth trying something else if StreamPeerFile was a thing.
# Though even then that's betting the weirdness of corrupt files against the
#  benefits of using less memory.
var _target: StreamPeerBuffer


func _init(t: PackedByteArray = PackedByteArray()):
	crc32.ensure_ready()
	_target = StreamPeerBuffer.new()
	_target.big_endian = true
	_target.data_array = t


# Reading


# Reads the magic number. Returns the method of failure or null for success.
func read_magic():
	if _target.get_available_bytes() < 8:
		return "Not enough bytes in magic number"
	var a := _target.get_32() & 0xFFFFFFFF
	if a != 0x89504E47:
		return "Magic number start not 0x89504E47, but " + str(a)
	a = _target.get_32() & 0xFFFFFFFF
	if a != 0x0D0A1A0A:
		return "Magic number end not 0x0D0A1A0A, but " + str(a)
	return null


# Reads a chunk into chunk_type and chunk_data. Returns an error code.
func read_chunk() -> int:
	if _target.get_available_bytes() < 8:
		return ERR_FILE_EOF
	var dlen := _target.get_32()
	var a := char(_target.get_8())
	var b := char(_target.get_8())
	var c := char(_target.get_8())
	var d := char(_target.get_8())
	chunk_type = a + b + c + d
	if _target.get_available_bytes() >= dlen:
		chunk_data = _target.get_data(dlen)[1]
	else:
		return ERR_FILE_EOF
	# we don't care what this reads anyway, so don't bother checking it
	_target.get_32()
	return OK


# Writing


# Writes the PNG magic number.
func write_magic():
	_target.put_32(0x89504E47)
	_target.put_32(0x0D0A1A0A)


# Creates a big-endian StreamPeerBuffer for writing PNG data into.
func start_chunk() -> StreamPeerBuffer:
	var result := StreamPeerBuffer.new()
	result.big_endian = true
	return result


# Writes a PNG chunk.
func write_chunk(type: String, data: PackedByteArray):
	_target.put_32(len(data))
	var at := type.to_ascii_buffer()
	_target.put_data(at)
	_target.put_data(data)
	var crc := crc32.update(crc32.mask, at)
	crc = crc32.end(crc32.update(crc, data))
	_target.put_32(crc)


# Returns the data_array of the stream (to be used when you're done writing the file)
func finish() -> PackedByteArray:
	return _target.data_array
