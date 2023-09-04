@tool
class_name AImgIOCRC32
extends Resource
# CRC32 implementation that uses a Resource for better caching

const INIT = 0xFFFFFFFF

# The reversed polynomial.
@export var reversed_polynomial: int = 0xEDB88320

# The mask (and initialization value).
@export var mask: int = 0xFFFFFFFF

var crc32_table = []
var _table_init_mutex: Mutex = Mutex.new()
var _table_initialized: bool = false


# Ensures the CRC32's cached part is ready.
# Should be called very infrequently, definitely not in an inner loop.
func ensure_ready():
	_table_init_mutex.lock()
	if not _table_initialized:
		# Calculate CRC32 table.
		var range8 := range(8)
		for i in range(256):
			var crc := i
			for j in range8:
				if (crc & 1) != 0:
					crc = (crc >> 1) ^ reversed_polynomial
				else:
					crc >>= 1
			crc32_table.push_back(crc & mask)
		_table_initialized = true
	_table_init_mutex.unlock()


# Performs the update step of CRC32 over some bytes.
# Note that this is not the whole story.
# The CRC must be initialized to 0xFFFFFFFF, then updated, then bitwise-inverted.
func update(crc: int, data: PackedByteArray) -> int:
	var i := 0
	var l := len(data)
	while i < l:
		var lb := data[i] ^ (crc & 0xFF)
		crc = crc32_table[lb] ^ (crc >> 8)
		i += 1
	return crc


# Finishes the CRC by XORing it with the mask.
func end(crc: int) -> int:
	return crc ^ mask
