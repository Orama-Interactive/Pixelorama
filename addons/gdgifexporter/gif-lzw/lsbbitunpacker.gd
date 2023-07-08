extends RefCounted


class LSBLZWBitUnpacker:
	var chunk_stream: PackedByteArray
	var bit_index: int = 0
	var byte: int
	var byte_index: int = 0

	func _init(_chunk_stream: PackedByteArray):
		chunk_stream = _chunk_stream
		self.get_byte()

	func get_bit(value: int, index: int) -> int:
		return (value >> index) & 1

	func set_bit(value: int, index: int) -> int:
		return value | (1 << index)

	func get_byte():
		byte = chunk_stream[byte_index]
		byte_index += 1
		bit_index = 0

	func read_bits(bits_count: int) -> int:
		var result: int = 0
		var result_bit_index: int = 0

		for _i in range(bits_count):
			if self.get_bit(byte, bit_index) == 1:
				result = self.set_bit(result, result_bit_index)
			result_bit_index += 1
			bit_index += 1

			if bit_index == 8:
				self.get_byte()

		return result

	func remove_bits(bits_count: int) -> void:
		self.read_bits(bits_count)
