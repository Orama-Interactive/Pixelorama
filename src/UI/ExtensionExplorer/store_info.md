// This file is for online use.<br>

## Rules for writing a (store_info) file:
// 1.	The Store Entry is one large Array (referred to as "entry") consisting of sub-arrays (referred to as "data")<br>
//		e.g `[[keyword, ....], [keyword, ....], [keyword, ....], .......]`<br>
// 2.	Each data must have a keyword of type `String` at it's first index which helps in identifying what the data represents.<br>
//		e.g, ["name", "name of extension"] is the data giving information about "name".<br>
//		Valid keywords are `name`, `version`, `description`, `tags`, `thumbnail`, `download_link`<br>
//		Put quotation marks ("") to make it a string, otherwise error will occur.<br>
// 3.    One store entry must occupy only one line (and vice-versa).<br>
// 4.    Comments are supported. you can comment an entire line by placing `#` or `//` at the start of the line (comments between or at end of line are not allowed).<br>
// 5.    links to another store_info file can be placed inside another store_info file (it will get detected as a custom store file).<br>

## TIPS:
//	- `thumbnail` is the link you get by right clicking an image (uploaded somewhere on the internet) and selecting Copy Image Link.<br>
//	- `download_link` is ususlly od the form `{repo}/raw/{Path of extension within repo}`<br>
//		e.g, if `https://github.com/Variable-ind/Pixelorama-Extensions/blob/master/Extensions/Example.pck` is the URL path to your extension then replace "blob" with "raw"
//		and the link becomes `"https://github.com/Variable-ind/Pixelorama-Extensions/raw/master/Extensions/Example.pck"`<br>

// For further help see the entries below for reference of how it's done
## Entries:
// Put Official Extensions Here


## Other Store Links:
### VariableStore
https://raw.githubusercontent.com/Variable-ind/Pixelorama-Extensions/4.0/store_info.md
