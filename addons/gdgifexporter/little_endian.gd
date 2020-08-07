extends Node


func int_to_2bytes(value: int) -> PoolByteArray:
	return PoolByteArray([value & 255, (value >> 8) & 255])
