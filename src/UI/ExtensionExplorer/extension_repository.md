// This file is for online use.<br>

## Rules for writing a repository file:
// 1. A repository entry is one large Array (referred to as "entry") consisting of sub-arrays (referred to as "data")<br>
// e.g `[[keyword, ....], [keyword, ....], [keyword, ....], .......]`<br>
// 2. Each data must have a keyword of type `String` at it's first index which helps in identifying what the data represents.<br>
// e.g, ["name", "name of extension"] is the data giving information about "name".<br>
// Valid keywords are `name`, `version`, `description`, `tags`, `thumbnail`, `download_link`<br>
// Put quotation marks ("") to make it a string, otherwise errors will occur.<br>
// 3. One repository entry must occupy only one line.<br>
// 4. Comments are supported. You can comment an entire line by placing `#` or `//` at the start of the line. Comments between or at end of line are not allowed.<br>
// 5. Links to another extension_repository file can be placed inside another extension_repository file, and it will get detected as a custom repository file.<br>

## TIPS:
// - `thumbnail` is the link you get by right clicking an image (uploaded somewhere on the internet) and selecting Copy Image Link.<br>
// - `download_link` is usually of the form `{repo}/raw/{Path of extension within repo}`<br>
// e.g, if `https://github.com/Variable-ind/Pixelorama-Extensions/blob/master/Extensions/Example.pck` is the URL path to your extension then replace "blob" with "raw"
// and the link becomes `"https://github.com/Variable-ind/Pixelorama-Extensions/raw/master/Extensions/Example.pck"`<br>

// For further help see the entries below for reference of how it's done
## Entries:

[["name", "Voxelorama"], ["version", 1.0], ["description", "An extension for Pixelorama that generates 3D voxel art out of 2D pixel art."], ["tags", "Tool", "3D"], ["thumbnail", "https://user-images.githubusercontent.com/35376950/185218214-c8356f86-00ed-4f39-b0f8-458a29d0061b.png"], ["download_link", "https://github.com/Orama-Interactive/VoxeloramaExtension/releases/download/1.0/Voxelorama.pck"]]

[["name", "LospecPaletteImporter"], ["version", 1.1], ["description", "A Pixelorama extension for downloading and importing palettes directly from Lospec."], ["tags", "Palettes"], ["thumbnail", "https://github.com/Variable-ind/Lospec-Palette-Importer/assets/77773850/7ac86623-c428-4409-8f81-c7406527126f"], ["download_link", "https://github.com/OverloadedOrama/Lospec-Palette-Importer/releases/download/v1.1/LospecPaletteImporter.pck"]]

[["name", "OpenDyslexicFont"], ["version", 1.0], ["description", "A Pixelorama extension that sets the OpenDyslexic font as the main font of the user interface."], ["tags", "Fonts"], ["download_link", "https://github.com/OverloadedOrama/OpenDyslexic-Pixelorama-Extension/releases/download/v1.0/OpenDyslexicFont.pck"]]

[["name", "ExtensionCreator"], ["version", 1.0], ["description", "Used as a guide by beginers for creating extensions (Open from help menu)"], ["tags", "Tutorial"], ["thumbnail", "https://user-images.githubusercontent.com/77773850/283574411-952f6032-dadb-4bab-998c-f90c236f7fe8.png"], ["download_link", "https://github.com/Variable-ind/Pixelorama-Extensions/raw/4.0/Extensions/ExtensionCreator.pck"]]

[["name", "Audia"], ["version", 1.0], ["description", "Allows to play a specific audio on a specific tag. (Open it through Window Menu > Audia) How to use: Change the driver from (Dummy) to something other driver. Drag and drop the audio to place it in (Music Library). Write any tag's name in (Play on Tag) field. You will hear sound whenever that tag is played"], ["tags", "UI", "Exporter", "Audio"], ["thumbnail", "https://user-images.githubusercontent.com/77773850/261408793-3f80c3be-4dd8-41cd-ad99-f04291064333.png"], ["download_link", "https://github.com/Variable-ind/Pixelorama-Extensions/raw/4.0/Extensions/Audia.pck"]]

[["name", "KeyDisplay"], ["version", 1.0], ["description", "Handy extension to display shortcuts for use in videos etc.)"], ["tags", "UI"], ["thumbnail", "https://github.com/Variable-ind/Pixelorama-Extensions/assets/77773850/dcedd193-1c37-4311-8dc2-ee0b65de8cec"], ["download_link", "https://github.com/Variable-ind/Pixelorama-Extensions/raw/4.0/Extensions/KeyDisplay.pck"]]

[["name", "Swappy"], ["version", 0.2], ["description", "Helper Extension for Re-Coloring. Replaces all instances of a Color with a New Color."], ["tags", "Tool", "UI"], ["thumbnail", "https://user-images.githubusercontent.com/77773850/246190032-e4d1e2b9-03d8-4a6d-9834-e29ca7fbf463.png"], ["download_link", "https://github.com/Variable-ind/Pixelorama-Extensions/raw/4.0/Extensions/Swappy.pck"]]

[["name", "TimeTracking"], ["version", 0.2], ["description", "Saves project statistics in the .pxo file (access with Help>Project Statistics)"], ["tags", "Analytics"], ["thumbnail", "https://user-images.githubusercontent.com/77773850/272894172-5c2aec0e-944e-4e91-90ee-8fe1803cf83d.png"], ["download_link", "https://github.com/Variable-ind/Pixelorama-Extensions/raw/4.0/Extensions/TimeTracking.pck"]]
