extends Node


func parse(error: int, start := "", end := ""):
	var message: String
	match error:
		OK:
			message = "everything is fine"
		FAILED:
			message = "Generic error."
		ERR_UNAVAILABLE:
			message = "Unavailable error."
		ERR_UNCONFIGURED:
			message = "Unconfigured error."
		ERR_UNAUTHORIZED:
			message = "Unauthorized error."
		ERR_PARAMETER_RANGE_ERROR:
			message = "Parameter range error."
		ERR_OUT_OF_MEMORY:
			message = "Out of memory (OOM) error."
		ERR_FILE_NOT_FOUND:
			message = "File: Not found error."
		ERR_FILE_BAD_DRIVE:
			message = "File: Bad drive error."
		ERR_FILE_BAD_PATH:
			message = "File: Bad path error."
		ERR_FILE_NO_PERMISSION:
			message = "File: No permission error."
		ERR_FILE_ALREADY_IN_USE:
			message = "File: Already in use error."
		ERR_FILE_CANT_OPEN:
			message = "File: Can't open error."
		ERR_FILE_CANT_WRITE:
			message = "File: Can't write error."
		ERR_FILE_CANT_READ:
			message = "File: Can't read error."
		ERR_FILE_UNRECOGNIZED:
			message = "File: Unrecognized error."
		ERR_FILE_CORRUPT:
			message = "File: Corrupt error."
		ERR_FILE_MISSING_DEPENDENCIES:
			message = "File: Missing dependencies error."
		ERR_FILE_EOF:
			message = "File: End of file (EOF) error."
		ERR_CANT_OPEN:
			message = "Can't open error."
		ERR_CANT_CREATE:
			message = "Can't create error."
		ERR_QUERY_FAILED:
			message = "Query failed error."
		ERR_ALREADY_IN_USE:
			message = "Already in use error."
		ERR_LOCKED:
			message = "Locked error."
		ERR_TIMEOUT:
			message = "Timeout error."
		ERR_CANT_CONNECT:
			message = "Can't connect error."
		ERR_CANT_RESOLVE:
			message = "Can't resolve error."
		ERR_CONNECTION_ERROR:
			message = "Connection error."
		ERR_CANT_ACQUIRE_RESOURCE:
			message = "Can't acquire resource error."
		ERR_CANT_FORK:
			message = "Can't fork process error."
		ERR_INVALID_DATA:
			message = "Invalid data error."
		ERR_INVALID_PARAMETER:
			message = "Invalid parameter error."
		ERR_ALREADY_EXISTS:
			message = "Already exists error."
		ERR_DOES_NOT_EXIST:
			message = "Does not exist error."
		ERR_DATABASE_CANT_READ:
			message = "Database: Read error."
		ERR_DATABASE_CANT_WRITE:
			message = "Database: Write error."
		ERR_COMPILATION_FAILED:
			message = "Compilation failed error."
		ERR_METHOD_NOT_FOUND:
			message = "Method not found error."
		ERR_LINK_FAILED:
			message = "Linking failed error."
		ERR_SCRIPT_FAILED:
			message = "Script failed error."
		ERR_CYCLIC_LINK:
			message = "Cycling link (import cycle) error."
		ERR_INVALID_DECLARATION:
			message = "Invalid declaration error."
		ERR_DUPLICATE_SYMBOL:
			message = "Duplicate symbol error."
		ERR_PARSE_ERROR:
			message = "Parse error."
		ERR_BUSY:
			message = "Busy error."
		ERR_SKIP:
			message = "Skip error."
		ERR_HELP:
			message = "Help error."
		ERR_BUG:
			message = "Bug error."
		ERR_PRINTER_ON_FIRE:
			message = "Printer on fire error. (This is an easter egg, no engine methods return this error code.)"
		_:
			message = "Unknown error"
	return str(start, message, end)
