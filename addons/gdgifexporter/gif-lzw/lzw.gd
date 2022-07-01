extends Reference

var lsbbitpacker = preload("./lsbbitpacker.gd")
var lsbbitunpacker = preload("./lsbbitunpacker.gd")

var code_table := {}
var entries_counter := 0


func get_bit_length(value: int):
	# bitwise or on value does ensure that the function works with value 0
	# long number at the end is log(2.0)
	return ceil(log(value | 0x1 + 1) / 0.6931471805599453)


func initialize_color_code_table(colors: PoolByteArray) -> void:
	code_table.clear()
	entries_counter = 0
	for color_id in colors:
		# warning-ignore:return_value_discarded
		code_table[PoolByteArray([color_id])] = entries_counter
		entries_counter += 1
	# move counter to the first available compression code index
	var last_color_index: int = colors.size() - 1
	var clear_code_index: int = pow(2, get_bit_length(last_color_index))
	entries_counter = clear_code_index + 2


# compression and decompression done with source:
# http://www.matthewflickinger.com/lab/whatsinagif/lzw_image_data.asp


func compress_lzw(index_stream: PoolByteArray, colors: PoolByteArray) -> Array:
	# Initialize code table
	initialize_color_code_table(colors)
	# Clear Code index is 2**<code size>
	# <code size> is the amount of bits needed to write down all colors
	# from color table. We use last color index because we can write
	# all colors (for example 16 colors) with indexes from 0 to 15.
	# Number 15 is in binary 0b1111, so we'll need 4 bits to write all
	# colors down.
	var last_color_index: int = colors.size() - 1
	var clear_code_index: int = pow(2, get_bit_length(last_color_index))
	var current_code_size: int = get_bit_length(clear_code_index)
	var binary_code_stream = lsbbitpacker.LSBLZWBitPacker.new()

	# initialize with Clear Code
	binary_code_stream.write_bits(clear_code_index, current_code_size)

	# Read first index from index stream.
	var index_buffer := PoolByteArray([index_stream[0]])
	var data_index: int = 1
	# <LOOP POINT>
	while data_index < index_stream.size():
		# Get the next index from the index stream.
		var k := index_stream[data_index]
		data_index += 1
		# Is index buffer + k in our code table?
		var new_index_buffer := PoolByteArray(index_buffer)
		new_index_buffer.push_back(k)
		if code_table.has(new_index_buffer):  # if YES
			# Add k to the end of the index buffer
			index_buffer = new_index_buffer
		else:  # if NO
			# Add a row for index buffer + k into our code table
			binary_code_stream.write_bits(code_table.get(index_buffer, -1), current_code_size)

			# We don't want to add new code to code table if we've exceeded 4095
			# index.
			var last_entry_index: int = entries_counter - 1
			if last_entry_index != 4095:
				# Output the code for just the index buffer to our code stream
				# warning-ignore:return_value_discarded
				code_table[new_index_buffer] = entries_counter
				entries_counter += 1
			else:
				# if we exceeded 4095 index (code table is full), we should
				# output Clear Code and reset everything.
				binary_code_stream.write_bits(clear_code_index, current_code_size)
				initialize_color_code_table(colors)
				# get_bits_number_for(clear_code_index) is the same as
				# LZW code size + 1
				current_code_size = get_bit_length(clear_code_index)

			# Detect when you have to save new codes in bigger bits boxes
			# change current code size when it happens because we want to save
			# flexible code sized codes
			var new_code_size_candidate: int = get_bit_length(entries_counter - 1)
			if new_code_size_candidate > current_code_size:
				current_code_size = new_code_size_candidate

			# Index buffer is set to k
			index_buffer = PoolByteArray([k])
	# Output code for contents of index buffer
	binary_code_stream.write_bits(code_table.get(index_buffer, -1), current_code_size)

	# output end with End Of Information Code
	binary_code_stream.write_bits(clear_code_index + 1, current_code_size)

	var min_code_size: int = get_bit_length(clear_code_index) - 1

	return [binary_code_stream.pack(), min_code_size]
