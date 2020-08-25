extends Reference


var lsbbitpacker = preload('./lsbbitpacker.gd')
var lsbbitunpacker = preload('./lsbbitunpacker.gd')

class CodeEntry:
	var sequence: PoolByteArray
	var raw_array: Array

	func _init(_sequence):
		raw_array = _sequence
		sequence = _sequence

	func add(other):
		return CodeEntry.new(self.raw_array + other.raw_array)

	func to_string():
		var result: String = ''
		for element in self.sequence:
			result += str(element) + ', '
		return result.substr(0, result.length() - 2)

class CodeTable:
	var entries: Dictionary = {}
	var counter: int = 0
	var lookup: Dictionary = {}

	func add(entry) -> int:
		self.entries[self.counter] = entry
		self.lookup[entry.raw_array] = self.counter
		counter += 1
		return counter

	func find(entry) -> int:
		return self.lookup.get(entry.raw_array, -1)

	func has(entry) -> bool:
		return self.find(entry) != -1

	func get(index) -> CodeEntry:
		return self.entries.get(index, null)

	func to_string() -> String:
		var result: String = 'CodeTable:\n'
		for id in self.entries:
			result += str(id) + ': ' + self.entries[id].to_string() + '\n'
		result += 'Counter: ' + str(self.counter) + '\n'
		return result

func log2(value: float) -> float:
	return log(value) / log(2.0)

func get_bits_number_for(value: int) -> int:
	if value == 0:
		return 1
	return int(ceil(log2(value + 1)))

func initialize_color_code_table(colors: PoolByteArray) -> CodeTable:
	var result_code_table: CodeTable = CodeTable.new()
	for color_id in colors:
		# warning-ignore:return_value_discarded
		result_code_table.add(CodeEntry.new([color_id]))
	# move counter to the first available compression code index
	var last_color_index: int = colors.size() - 1
	var clear_code_index: int = pow(2, get_bits_number_for(last_color_index))
	result_code_table.counter = clear_code_index + 2
	return result_code_table

# compression and decompression done with source:
# http://www.matthewflickinger.com/lab/whatsinagif/lzw_image_data.asp

func compress_lzw(image: PoolByteArray, colors: PoolByteArray) -> Array:
	# Initialize code table
	var code_table: CodeTable = initialize_color_code_table(colors)
	# Clear Code index is 2**<code size>
	# <code size> is the amount of bits needed to write down all colors
	# from color table. We use last color index because we can write
	# all colors (for example 16 colors) with indexes from 0 to 15.
	# Number 15 is in binary 0b1111, so we'll need 4 bits to write all
	# colors down.
	var last_color_index: int = colors.size() - 1
	var clear_code_index: int = pow(2, get_bits_number_for(last_color_index))
	var index_stream: PoolByteArray = image
	var current_code_size: int = get_bits_number_for(clear_code_index)
	var binary_code_stream = lsbbitpacker.LSB_LZWBitPacker.new()

	# initialize with Clear Code
	binary_code_stream.write_bits(clear_code_index, current_code_size)

	# Read first index from index stream.
	var index_buffer: CodeEntry = CodeEntry.new([index_stream[0]])
	var data_index: int = 1
	# <LOOP POINT>
	while data_index < index_stream.size():
		# Get the next index from the index stream.
		var K: CodeEntry = CodeEntry.new([index_stream[data_index]])
		data_index += 1
		# Is index buffer + K in our code table?
		var new_index_buffer: CodeEntry = index_buffer.add(K)
		if code_table.has(new_index_buffer): # if YES
			# Add K to the end of the index buffer
			index_buffer = new_index_buffer
		else: # if NO
			# Add a row for index buffer + K into our code table
			binary_code_stream.write_bits(code_table.find(index_buffer), current_code_size)

			# We don't want to add new code to code table if we've exceeded 4095
			# index.
			var last_entry_index: int = code_table.counter - 1
			if last_entry_index != 4095:
				# Output the code for just the index buffer to our code stream
				# warning-ignore:return_value_discarded
				code_table.add(new_index_buffer)
			else:
				# if we exceeded 4095 index (code table is full), we should
				# output Clear Code and reset everything.
				binary_code_stream.write_bits(clear_code_index, current_code_size)
				code_table = initialize_color_code_table(colors)
				# get_bits_number_for(clear_code_index) is the same as
				# LZW code size + 1
				current_code_size = get_bits_number_for(clear_code_index)

			# Detect when you have to save new codes in bigger bits boxes
			# change current code size when it happens because we want to save
			# flexible code sized codes
			var new_code_size_candidate: int = get_bits_number_for(code_table.counter - 1)
			if new_code_size_candidate > current_code_size:
				current_code_size = new_code_size_candidate

			# Index buffer is set to K
			index_buffer = K
	# Output code for contents of index buffer
	binary_code_stream.write_bits(code_table.find(index_buffer), current_code_size)

	# output end with End Of Information Code
	binary_code_stream.write_bits(clear_code_index + 1, current_code_size)

	var min_code_size: int = get_bits_number_for(clear_code_index) - 1

	return [binary_code_stream.pack(), min_code_size]

func decompress_lzw(code_stream_data: PoolByteArray, min_code_size: int, colors: PoolByteArray) -> PoolByteArray:
	var code_table: CodeTable = initialize_color_code_table(colors)
	var index_stream: PoolByteArray = PoolByteArray([])
	var binary_code_stream = lsbbitunpacker.LSB_LZWBitUnpacker.new(code_stream_data)
	var current_code_size: int = min_code_size + 1
	var clear_code_index: int = pow(2, min_code_size)

	# CODE is an index of code table, {CODE} is sequence inside
	# code table with index CODE. The same goes for PREVCODE.

	# Remove first Clear Code from stream. We don't need it.
	binary_code_stream.remove_bits(current_code_size)

	# let CODE be the first code in the code stream
	var code: int = binary_code_stream.read_bits(current_code_size)
	# output {CODE} to index stream
	index_stream.append_array(code_table.get(code).sequence)
	# set PREVCODE = CODE
	var prevcode: int = code
	# <LOOP POINT>
	while true:
		# let CODE be the next code in the code stream
		code = binary_code_stream.read_bits(current_code_size)
		# Detect Clear Code. When detected reset everything and get next code.
		if code == clear_code_index:
			code_table = initialize_color_code_table(colors)
			current_code_size = min_code_size + 1
			code = binary_code_stream.read_bits(current_code_size)
		elif code == clear_code_index + 1: # Stop when detected EOI Code.
			break
		# is CODE in the code table?
		var code_entry: CodeEntry = code_table.get(code)
		if code_entry != null: # if YES
			# output {CODE} to index stream
			index_stream.append_array(code_entry.sequence)
			# let K be the first index in {CODE}
			var K: CodeEntry = CodeEntry.new([code_entry.sequence[0]])
			# warning-ignore:return_value_discarded
			# add {PREVCODE} + K to the code table
			code_table.add(code_table.get(prevcode).add(K))
			# set PREVCODE = CODE
			prevcode = code
		else: # if NO
			# let K be the first index of {PREVCODE}
			var prevcode_entry: CodeEntry = code_table.get(prevcode)
			var K: CodeEntry = CodeEntry.new([prevcode_entry.sequence[0]])
			# output {PREVCODE} + K to index stream
			index_stream.append_array(prevcode_entry.add(K).sequence)
			# add {PREVCODE} + K to code table
			# warning-ignore:return_value_discarded
			code_table.add(prevcode_entry.add(K))
			# set PREVCODE = CODE
			prevcode = code

		# Detect when we should increase current code size and increase it.
		var new_code_size_candidate: int = get_bits_number_for(code_table.counter)
		if new_code_size_candidate > current_code_size:
			current_code_size = new_code_size_candidate

	return index_stream
