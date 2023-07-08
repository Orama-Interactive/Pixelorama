extends RefCounted


func int_to_2bytes(value: int) -> PackedByteArray:
	return PackedByteArray([value & 255, (value >> 8) & 255])
