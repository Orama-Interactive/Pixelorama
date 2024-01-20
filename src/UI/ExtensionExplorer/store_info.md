// This file is for online use.
//
// RULES FOR WRITING A (store_info) FILE:
//
// 1.	The Store Entry is one large Array (reffered to as "entry") consisting of sub-arrays (reffered to as "data")
//		e.g `[[keyword, ....], [keyword, ....], [keyword, ....], .......]`
// 2.	Each data must have a keyword of type `String` at it's first index which helps in identifying what the data represents.
//		e.g, ["name", "name of extension"] is the data giving information about "name"
//		Valid keywords are `name`, `version`, `description`, `tags`, `thumbnail`, `download_link`
//		Put quotation marks ("") to make it a string, otherwise error will occur.
// 3.    One store entry must occupy only one line (and vice-versa)
// 4.    Comments are supported. you can comment an entire line by placing `#` or `//` at the start of the line (comments between or at end of line are not allowed).
// 5.    links to another store_info file can be placed inside another store_info file (it will get detected as a custom store file)

// TIPS:
//	- `thumbnail` is the link you get by right clicking an image (uploaded somewhere on the internet) and selecting Copy Image Link
//	- `download_link` is ususlly od the form {repo}/raw/{Path of extension within repo}
//		e.g, if `https://github.com/Variable-ind/Pixelorama-Extensions/blob/master/Extensions/Example.pck` is the URL path to your extension then replace "blob" with "raw"
//		and the link becomes `"https://github.com/Variable-ind/Pixelorama-Extensions/raw/master/Extensions/Example.pck"`

// For further help see the entries below for reference of how it's done

[["name", "Swappy"], ["version", 0.2], ["description", "Helper Extension for Re-Coloring. Replaces all instances of a Color with a New Color."], ["tags", "Tool", "UI"], ["thumbnail", "https://user-images.githubusercontent.com/77773850/246190032-e4d1e2b9-03d8-4a6d-9834-e29ca7fbf463.png"], ["download_link", "https://github.com/Variable-ind/Pixelorama-Extensions/raw/4.0/Extensions/Swappy.pck"]]
