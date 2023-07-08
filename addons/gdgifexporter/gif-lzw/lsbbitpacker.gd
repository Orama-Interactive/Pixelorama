extends RefCounted


class LSBLZWBitPacker:
	var bit_index: int = 0
	var stream: int = 0

	var chunks: PackedByteArray = PackedByteArray([])

	func put_byte():
		chunks.append(stream & 0xff)
		bit_index -= 8
		stream >>= 8

	func write_bits(value: int, bits_count: int) -> void:
		value &= (1 << bits_count) - 1
		value <<= bit_index
		stream |= value
		bit_index += bits_count
		while bit_index >= 8:
			self.put_byte()

	func pack() -> PackedByteArray:
		if bit_index != 0:
			self.put_byte()
		return chunks

	func reset() -> void:
		bit_index = 0
		stream = 0
		chunks = PackedByteArray([])
