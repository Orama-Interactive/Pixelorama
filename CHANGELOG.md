# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). All the dates are in YYYY-MM-DD format.
<br><br>

## [v1.2.1] - 2026-08-19
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)),  [Joseph Demarest](https://github.com/JosephDemarest), [Qmaker-programmer](https://github.com/Qmaker-programmer)

Built using Godot 4.7.1

### Added
- Exporting images as SVG files is now possible. Right now it's very basic, it just takes each non-transparent pixel and makes it a `<rect>` element. In the future we could add an option to merge pixels that have the same color into singular `<rect>` elements, resulting in a smaller file size, but taking a longer time to export.
- Added a new Corner Pin layer effect. [#1586](https://github.com/Orama-Interactive/Pixelorama/pull/1586)
- Right-clicking on a keyframe brings up a popup menu, which allows you to delete the keyframe.
- Support for texture blit Godot shaders have been added and users can now load their own texture blit shaders.

### Changed
- The Index Map effect has been made a lot more powerful. [#1580](https://github.com/Orama-Interactive/Pixelorama/pull/1580)
- Tool shortcuts can now be activated when the cursor is outside the canvas.
- Various quality of life improvements in the keyframe timeline, such as track folding, cursor snapping to frames, tracks are now visually distinguished from sections and the frame number appears larger if it is the current frame. [#1582](https://github.com/Orama-Interactive/Pixelorama/pull/1582)
- Sliders can now be dragged outside of their bounds, if their values can go out of bounds. Previously this was only possible either by manually typing the desired value, or by using the arrow buttons. [#1587](https://github.com/Orama-Interactive/Pixelorama/pull/1587)
- Quick tool shortcuts can now be activated when a tool is being used. [#1588](https://github.com/Orama-Interactive/Pixelorama/pull/1588)
- Projects are now marked as unsaved when you change their export directory path, file name or file format. [#1561](https://github.com/Orama-Interactive/Pixelorama/pull/1561)
- Export settings are now being stored inside pxo files. [#1574](https://github.com/Orama-Interactive/Pixelorama/pull/1574)
- The layer opacity slider is now disabled if the selected layer has opacity keyframes. [#1568](https://github.com/Orama-Interactive/Pixelorama/pull/1568)
- Sliders for 2D vectors are now separated visually in the layer effects window to make it more clear which sliders belong to which value. [#1586](https://github.com/Orama-Interactive/Pixelorama/pull/1586)

### Fixed
- Fixed gif & apng files not being exported from the CLI. [#1563](https://github.com/Orama-Interactive/Pixelorama/issues/1563)
- The quick tool shortcuts no longer get called when a multi-state tool is being used, such as the curve tool, polygon select and isometric box tool. [#1569](https://github.com/Orama-Interactive/Pixelorama/pull/1569)
- Fixed dynamics not changing the brush size, if it is set to 1px.
- The canvas can no longer move with arrow keys if the text tool is currently being used.
- Fixed the keyframe cursor being in wrong place when using mouse wheel for scroll. [#1582](https://github.com/Orama-Interactive/Pixelorama/pull/1582)
- Fixed frame auto scroll not working when keyframe cursor is moved to the left. [#1582](https://github.com/Orama-Interactive/Pixelorama/pull/1582)
- The bucket tool's pattern offset is now working on similar color & whole selection fill modes.
- Fixed text applied by the text tool not having correct transparent colors. [#1577](https://github.com/Orama-Interactive/Pixelorama/pull/1577)
- Fixed text tool options not reflecting correct settings on loading. [#1578](https://github.com/Orama-Interactive/Pixelorama/pull/1578)
- The text now respects the selection area. [#1579](https://github.com/Orama-Interactive/Pixelorama/pull/1579)
- Fixed the shape tool colored indicators not being updated to the correct size. [#1575](https://github.com/Orama-Interactive/Pixelorama/pull/1575)
- Fixed the color picker tool not defaulting to the assigned mouse button. [#1567](https://github.com/Orama-Interactive/Pixelorama/pull/1567)
- Fixed the curve editor looking wrong when adding a new Color Curves layer effect.
- Fixed rounding errors in the Index Map effect.
- Fixed an issue where the selection outline colors were not being updated when Pixelorama launches.
- Fixed a crash when using tools coming from extensions.

## [v1.2] - 2026-07-29
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), SOS1, [@SjamesE](https://github.com/SjamesE), [@Arthurmtro](https://github.com/Arthurmtro),  Luciano Leão ([@LeaoLuciano](https://github.com/LeaoLuciano))

Built using Godot 4.6.3

### Added
- Added a keyframe-based view on the timeline, allowing users to animate layer opacity and layer effects with interpolation support. [#1417](https://github.com/Orama-Interactive/Pixelorama/pull/1417)
- Implemented autotiling support for tilemap layers, with a new tool for tilemap layers that allows users to set the autotiling bits on each tile. [#1482](https://github.com/Orama-Interactive/Pixelorama/pull/1482)
- The 3D layer system has been completely re-written! 3D objects are now shared across all cels of a layer, instead of each cel having its own objects, making it possible to animate an object's properties. This re-write also allows for some other new features, such as material property editing (and animating!), importing GLTF scenes, and even drawing directly on 3D objects using the pencil tool! **IMPORTANT NOTE:** Due to this, the 3D layer data of pxo files is NO LONGER COMPATIBLE between v1.2 and older versions. The pxo files themselves should load just fine, but the 3D layers will be EMPTY. [#1429](https://github.com/Orama-Interactive/Pixelorama/pull/1429)
- The shape tools now support drawing with brushes.
- Implement rounded rectangle drawing in the rectangle tool.
- Added a "Flat to Isometric" image & layer effect.
- Users can now change the colors of the UI by changing the theme's base color, accent color & contrast directly from the Preferences, making Pixelorama even more configurable & accessible, without having to rely on extensions. [#1515](https://github.com/Orama-Interactive/Pixelorama/pull/1515)
- Added two new themes: `Black (OLED)` and `System`. `System` is a special theme that follows the Operating System's base & accent colors, and it even automatically updates if the OS' theme changes while Pixelorama is running! This should work for Windows, macOS and Android, while Linux only supports accent color at the moment. [#1515](https://github.com/Orama-Interactive/Pixelorama/pull/1515)
- Added quick tool activation shortcuts. When a quick tool shortcut is being held, that tool gets activated until the shortcut is released. By default, only the color picker tool has a shortcut, which ic set to <kbd>Alt</kbd>, but you can set shortcuts for every other tool in the Preferences.
- Added a new "Reselect" option in the Selection menu, which re-creates a previously cleared selection. By default, its shortcut is set to <kbd>Control + Shift + D</kbd>.
- Added new blend modes: Intersect and Match colors! [#1474](https://github.com/Orama-Interactive/Pixelorama/pull/1474)
- Added a hotkey to close the current project. Set to <kbd>Control + W</kbd> by default. [#1548](https://github.com/Orama-Interactive/Pixelorama/pull/1548)
- Added an option in the export dialog to repeat the animation as many times as you want. [#1508](https://github.com/Orama-Interactive/Pixelorama/pull/1508)
- Added a "crop to selection" mode in the advanced options of the export window. [#1521](https://github.com/Orama-Interactive/Pixelorama/pull/1521)
- Exporting tilesets is now also possible from the layer properties of a tilemap layer.
- Added a preview and a transpose option when exporting tilesets.
- New projects can now have the clipboard image (either app or system clipboard) as their content. Clipboard sizes have also been added in the Template list, if you just want to get the clipboard size but not the image itself.
- The paint select tool can now select entire grid cells. [#1533](https://github.com/Orama-Interactive/Pixelorama/pull/1533)
- A default license option for projects has been added in the preferences. [#1526](https://github.com/Orama-Interactive/Pixelorama/pull/1526)
- Exporting a tileset as a Godot TileSet resource now saves the probability of each tile.
- Importing Krita projects now also loads their layer opacity keyframe data, if they have any.

### Changed
- Reference images are now stored inside pxo files. **NOTE:** This is a breaking change as reference images will fail to load from pxo files saved in v1.1.10 and older.
- Made layer hierarchy status more readable by adding lines to layer buttons in the timeline, for layers that belong to groups.
- Selection gizmos are now hidden and disabled when there is no active selection tool. Now, you no longer have to worry about accidentally transforming selections while drawing.
- The brush no longer gets resized with mouse movement when a tool is being used. This prevents issues where you could hold <kbd>Control + Shift</kbd> to draw lines at snapped angles, and the brush would resize at the same time.
- The Command key is now used for selecting timeline properties on macOS. [#1544](https://github.com/Orama-Interactive/Pixelorama/pull/1544)
- Adding a new layer while a collapsed group layer is selected now places it outside of that group.
- Made some UI elements, such as tool, cel, layer & frame buttons be focusable with the keyboard and activatable by pressing <kbd>Space</kbd> and/or <kbd>Enter</kbd>.
- The bezier points of the curve tool now lie at the center of the pixels instead of their corner. [#1495](https://github.com/Orama-Interactive/Pixelorama/pull/1495)
- The mad width of project tabs has been limited to 256 pixels, to prevent issues where, if the project name was too long, it would hide parts of the UI.
- [Android] Project's read and write permissions now persist after the app is closed.

### Fixed
- Fixed resizing selection not being snapped to the pixel grid.
- Fixed crash when switching to a different project while a transformation is active on a tilemap layer.
- Fixed manual mode in tilemap layers not updating all cells when there is more than one tilemap layer sharing the same tileset.
- Tilemap layer bucket fill now works properly with random tiles.
- The bucket tool no longer affects locked & invisible layers.
- Fixed project tabs sometimes displaying the wrong project name. [#1489](https://github.com/Orama-Interactive/Pixelorama/issues/1489)
- If a layer is added in a collapsed group layer (such as when undoing a layer deletion) now expands that group.
- Various fixes and improvements in grid center snapping. [#1533](https://github.com/Orama-Interactive/Pixelorama/pull/1533) & [#1545](https://github.com/Orama-Interactive/Pixelorama/pull/1545)
- Fixed the bucket tool not auto-converting global palettes to project palettes. [#1538](https://github.com/Orama-Interactive/Pixelorama/pull/1538)
- The keyboard no longer gets stuck on activating elements in the user interface after renaming a layer. [#1524](https://github.com/Orama-Interactive/Pixelorama/pull/1524)
- The Gaussian blur effect no longer generates darkened edges. [#1523](https://github.com/Orama-Interactive/Pixelorama/pull/1523)
- Exporting split layers now works properly with a selected amount of layers. [#1532](https://github.com/Orama-Interactive/Pixelorama/pull/1532)
- Fixed exported file name being set to "untitled" even if the project has a name.
- Fixed issue where when you batch exported and the "Create new folder for each frame tag" option is enabled, the export folder became the folder of the first "tag", instead of the folder where the .pxo file is located. [#1540](https://github.com/Orama-Interactive/Pixelorama/pull/1540)
- Fixed issue where the tags were not being visible if Pixelorama is opened with a file.
- Fixed a crash when loading a Krita project that had keyframes for stuff like opacity, but no image data for frames.
- Fixed selection marching ants outline not appearing when pasting.
- Cel button previews are now properly updated when creating new frames for a project that has a fill color.
- Fixed the unfocused border color of embedded windows in non-dark themes.
- Fixed hardware related issue where layer opacity & blend mode did not update in certain mobile GPUs. [#1546](https://github.com/Orama-Interactive/Pixelorama/issues/1546)
- Make UI elements in the audio layer properties stack properly.
- Fixed extension exporters not working. [#1497](https://github.com/Orama-Interactive/Pixelorama/pull/1497)

### Removed
- Removed tool & background color options from the Preferences in favor of the new theming system. If there is enough demand for them, we could add them again. [#1515](https://github.com/Orama-Interactive/Pixelorama/pull/1515)

## [v1.1.10] - 2026-04-30
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 4.6.2

### Added
- Added a license text field in the project properties, so users can optionally add a license for projects they want to share.
- Added author information in the preferences, which are then stored in `.pxo` files.
- Added a shortcut to rename layers. By default, it's <kbd>F2</kbd>. [#1481](https://github.com/Orama-Interactive/Pixelorama/pull/1481)
- Added RGB color shifting to the adjust brightness/contrast effect. [#1494](https://github.com/Orama-Interactive/Pixelorama/pull/1494)
- Exposed preferences that allow users to choose whether they want changing the visibility and the locked status of a layer to be included in the undo history. [#1488](https://github.com/Orama-Interactive/Pixelorama/pull/1488)

### Changed
- Made the adjust hue, saturation & value effect produce more predictable results. [#1494](https://github.com/Orama-Interactive/Pixelorama/pull/1494)
- Disabled the overwrite file warning that appeared in the Export dialog's "Browse" file dialog. Instead, only show the warning when clicking on Export. [#1492](https://github.com/Orama-Interactive/Pixelorama/issues/1492)

### Fixed
- Fixed a critical regression from v1.1.9, which ruined projects with indexed mode that were saved in version 1.1.8 or older. [#1491](https://github.com/Orama-Interactive/Pixelorama/issues/1491)
- Fixed issues when, during transformations, the user switched to from a selection with content transformation to a selection-only transformation (by holding <kbd>Alt</kbd> by default), and vice versa.
- Fixed copying not working when a selection-only ransformation was active.
- Fixed final images on the export dialog, that have clipping masks and invisible layers, being wrongly rendered. [#1493](https://github.com/Orama-Interactive/Pixelorama/issues/1493)
- Fixed a crash when cloning a cel when there is only one frame, and the linked cels button is pressed.
- Fixed layers and cels being misaligned in the timeline when the font size is too small. [#1441](https://github.com/Orama-Interactive/Pixelorama/issues/1441)

## [v1.1.9] - 2026-04-12
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), [@Bartkk0](https://github.com/Bartkk0), Akane Angèle ([@AkaneAngele](https://github.com/AkaneAngele)), [@AlRado](https://github.com/AlRado),  Vance Palacio ([@vanceism7](https://github.com/vanceism7)), Olof Knight ([@InsaneAwesomeTony](https://github.com/InsaneAwesomeTony)), [@magley](https://github.com/magley), [@makinori](https://github.com/makinori)

Built using Godot 4.6.2

### Added
- It is now finally possible to split layers when exporting spritesheets! [#1456](https://github.com/Orama-Interactive/Pixelorama/pull/1456)
- Implemented the ability to export tilesets as images or Godot `TileSet` resources from the Project Properties window.
- Duplicating cels is now possible, either from the cel button menu, or by using a shortcut, which is <kbd>Alt + D</kbd> by default. [#1470](https://github.com/Orama-Interactive/Pixelorama/pull/1470)
- A search bar has been added in the Preferences.
- You can now load and save exr image files on desktop platforms.
- A read-only option for the global palettes has been added in the Preferences, that, if disabled, allows global palettes to be modified, without creating a project palette copy, like it used to work before version 1.1.5. [#1466](https://github.com/Orama-Interactive/Pixelorama/pull/1466)
- Added a "Collapse main menu" preference that unites the menu bar into a single "Main menu" button. This preference is turned on by default on mobiles, but turned off by default on other platforms.
- On mobile, quick access buttons for save, undo, redo, copy, cut, paste, delete as well as Shift, Control and Alt have been added on the top bar next to the menu.
- On the web version, a confirmation message when the user attempts to close the tab and has unsaved changes has been added.
- A max velocity setting for mice is now exposed in the dynamics panel. [#1430](https://github.com/Orama-Interactive/Pixelorama/pull/1430)
- Added new image size presets when creating a new project. [#1455](https://github.com/Orama-Interactive/Pixelorama/pull/1455)
- Added a shortcut for canvas rotation. [#1449](https://github.com/Orama-Interactive/Pixelorama/pull/1449)
- It is now possible to set a shortcut for the Grayscale View menu option. [#1443](https://github.com/Orama-Interactive/Pixelorama/pull/1443)
- Implemented support for the Thai language.

### Changed
- The export dialog's file browser has changed. Now, users select the entire path of the exported file from there, instead of just the folder, and the file name text field has been removed.
- The mimetype of pxo files has been changed to `application/x-pixelorama`.
- The export file directory & name are stored inside pxo files.
- Undo/redo now works for layer properties. [#1413](https://github.com/Orama-Interactive/Pixelorama/pull/#1413)
- Pixelorama now uses a more centralized crash monitor solution that detects both if a session has crashed, and if an extension caused Pixelorama to crash. [#1472](https://github.com/Orama-Interactive/Pixelorama/pull/1472)
- The brush size found in the dynamics panel is now relative to the brush size in the tool properties. [#1430](https://github.com/Orama-Interactive/Pixelorama/pull/1430)
- Marking folders as favorites in the file manager windows is now saved between sessions. Recent folders are also being saved. [#1434](https://github.com/Orama-Interactive/Pixelorama/pull/1434)
- The Android version no longer requires storage permissions, as now we are using the Storage Access Framework — thanks to the update to Godot 4.6.
- Extension tags are now arranged in alphabetical order in the Extension explorer, and tags are now case-insensitive. [#1458](https://github.com/Orama-Interactive/Pixelorama/pull/1458)
- Decimals are now allowed for reference image values. [#1468](https://github.com/Orama-Interactive/Pixelorama/pull/1468)

### Fixed
- Fixed major slowdown when pasting an image into a tilemap cel, or when deleting the entire cel.
- Improved idle GPU performance because the window was being constantly re-drawn, even if nothing was visibly changing.
- Brush size no longer changes in odd increments if share tool options is enabled.
- In tilesets, unselected tiles can now be deleted, if they are unused in any tilemap layer. [#1460](https://github.com/Orama-Interactive/Pixelorama/issues/1460)
- Fixed transformed tiles not getting erased in tilemaps that have place-only mode enabled.
- Fixed crash when deleting the content of a tilemap cel.
- Fixed Pixelorama freezing when exporting GIFs and when exporting to an already existing file, if single-window mode is disabled. [#1260](https://github.com/Orama-Interactive/Pixelorama/issues/1260) [#1333](https://github.com/Orama-Interactive/Pixelorama/issues/1333) 
- On mobile, the UI is no longer getting cut on fullscreen by camera notches and curved sides.
- Fixed right tool not selected by stylus when invert button is pressed. [#1426](https://github.com/Orama-Interactive/Pixelorama/pull/1426)
- Fixed various visual bugs during undo/redo. [#1432](https://github.com/Orama-Interactive/Pixelorama/pull/1432)
- Fixed toggling the "Display Layer Effects" option not updating the effects of the unselected layers. [#1457](https://github.com/Orama-Interactive/Pixelorama/pull/1457)
- In dynamics, fixed tools having a non-zero velocity even when it just started drawing. This previously caused unpredictability when modifying alpha through velocity. [#1430](https://github.com/Orama-Interactive/Pixelorama/pull/1430)
- Fixed horizontal/vertical/diagonal mirror button shortcuts not being unique.
- Undo/redo now updates all tilemap layers. [#1471](https://github.com/Orama-Interactive/Pixelorama/pull/1471)
- The cel button texture gets properly updated when importing an image to replace a cel. [#1469](https://github.com/Orama-Interactive/Pixelorama/pull/1469)
- Fixed measurements, color & tilemap indices not mirroring when "Mirror View" is toggled on. [#1465](https://github.com/Orama-Interactive/Pixelorama/issues/1465)
- Fixed project opened twice when "open last project" is enabled. [#1473](https://github.com/Orama-Interactive/Pixelorama/pull/1473)
- Fixed file override confirmation dialog from being overflown with text when exporting.
- Fixed animation tags not being visible if the last project gets loaded on startup.
- Fixed the "add extension" file dialog ignoring the "Use native file dialogs" preference.
- Fixed precision loss in perspective lines. [#1450](https://github.com/Orama-Interactive/Pixelorama/pull/1450)

## [v1.1.8] - 2025-12-31
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), [@Bartkk0](https://github.com/Bartkk0)

Built using Godot 4.5.1

### Added
- Added support for multi frame/cel swapping! [#1393](https://github.com/Orama-Interactive/Pixelorama/pull/1393)
- You can now search & rename tilesets in the project properties dialog. [#1383](https://github.com/Orama-Interactive/Pixelorama/pull/1383)
- Various improvements to the import image dialog have been made when importing an image as a spritesheet, such as a preset system and the ability to include or exclude empty tiles. [#1385](https://github.com/Orama-Interactive/Pixelorama/pull/1385)
- The recorder panel now has more options, such as the ability to use FFMPEG to export the recording as a gif file, and the ability to set a custom rectangular area of the screen to record. [#1387](https://github.com/Orama-Interactive/Pixelorama/pull/1387)

### Changed
- Gif files are now being exported frame by frame, which saves memory space and users can now see the current progress of the export. [#1396](https://github.com/Orama-Interactive/Pixelorama/pull/1396)
- The `override.cfg` file, which is used to store settings such as single-window mode, window transparency and audio driver is now stored in the same place as the `config.ini` file, instead of the same folder as the Pixelorama executable.
- When double clicking on a layer button to rename it, the entire text is now automatically selected. [#1411](https://github.com/Orama-Interactive/Pixelorama/pull/1411)

### Fixed
- The "apply all" toggle when importing multiple images is now faster. [#1390](https://github.com/Orama-Interactive/Pixelorama/pull/1390)
- Fixed a visual bug with clipping masks. [#1389](https://github.com/Orama-Interactive/Pixelorama/pull/1389)
- Clear the saved processed images from memory when closing the export dialog, so that they don't waste space in memory. [#1397](https://github.com/Orama-Interactive/Pixelorama/pull/1397)
- Fixed selection animated borders setting not being applied on startup.
- Non-valid names for projects are no longer allowed in the project properties. [#1383](https://github.com/Orama-Interactive/Pixelorama/pull/1383)
- Fixed guides being appended twice when loading Krita & Photoshop projects, leading to crashes when hovering over the canvas rulers.

## [v1.1.7] - 2025-11-29
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 4.5.1

### Added
- Importing GIF files is now possible without needing FFMPEG!
- Holding <kbd>Control + Shift</kbd> and moving the mouse right or left now changes the brush size. This shortcut can be changed from the Preferences.
- The shortcuts category in the Preferences now have search bars to filter by name, or by shortcut.
- Added mouse motion shortcuts to quickly change the color hue, saturation, value and alpha. By default, these shortcuts are empty, but they can be changed from the Preferences.
- Added a button in the palette panel that unlocks the palette grid, making the swatches automatically resize based on the available free space of the panel, instead of having a fixed width and height.
- A single tool mode has been added as a preference that makes the right mouse button activate the same tool as the left mouse button, instead of being independent.
- Selecting "Paste from clipboard" while having a Lospec Palette URI copied will now automatically download that palette.
- Removing all backups is now possible from the Preferences, under the Reset category.

### Changed
- The default UI scale factor now depends on the monitor properties, instead of always being set to 1.0.
- In the shortcut category of the Preferences, the Default shortcut profile is no longer selectable, and the Custom profile is now the default one. If you want to restore the default shortcuts, you can press the new "Reset" button.
- The distance between panels in the interface has been increased from 8 pixels to 12, making it a bit easier to grab the split handler in order to resize the panels.
- Palette swatches get selected on mouse button *release* and not *press*, making them more consistent with the rest of the buttons in the interface.
- Scrolling on the palette panel is now smoother and works like the rest of the scrollable areas on the interface.

### Fixed
- Fixed crash when drawing and there is no active palette.
- Fixed a crash that sometimes happened when loading multiple projects at once. [#1379](https://github.com/Orama-Interactive/Pixelorama/issues/1379)
- Fix crash when opening Pixelorama with a project which had a group layer saved as current layer. [#1378](https://github.com/Orama-Interactive/Pixelorama/pull/#1378)
- Fixed crash when adding a new palette when there is none.
- Fixed crash when drag and dropping something that is not a palette swatch (such as a cel button) into a swatch.
- Fixed crash when trying to import a zip file that is not an extension. [#1375](https://github.com/Orama-Interactive/Pixelorama/pull/#1375)
- The timeline now scrolls to the active cel when switching projects. [#1377](https://github.com/Orama-Interactive/Pixelorama/issues/1377)
- Exporting videos should no longer skip the last frame.
- Fixed subwindow dialogs being too big compared to the main window size, if the UI is scaled.
- Fixed error code 1 when saving a backup, if the current session backup directory is removed while Pixelorama is running. Now, it always checks if the directory exists and re-creates it, if it is deleted.

## [v1.1.6] - 2025-10-31
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 4.5.1

### Added
- Made a new website for Pixelorama! You can visit it on: https://www.pixelorama.org/
- Added buttons that enable diagonal symmetry!
- If Pixelorama crashed in the previous session, a window will appear the next time it is launched to let the user know that they can restore data, if there are any projects that can be restored.
- Two new color picker shapes, OK HS Rectangle and OK HL Rectangle.
- Users can now drag and drop font files to load them. Fonts can be used by the text tool, text meshes in 3D layers and the user interface itself.
- Added an Undo History dialog.
- The convolution matrix layer effect now has a kernel normalization factor.
- Added Arabic translation and made improvements to the UI so that it works better for Right-To-Left languages.
- Pixelorama can now load Lospec palettes if started with "lospec-palette://" plus the palette's name as a CLI argument. In theory, this allows Pixelorama to open when clicking on the "Open In App" button on a palette on Lospec's website, but for now **it does not work automatically**, as it requires different setup for different operating systems.
- A preview.png file is now saved inside pxo files. This can help file managers to generate thumbnails for pxo files. **Note that this doesn't mean that you will automatically see thumbnails for pxo files — it's up to file managers to implement this.**

### Changed
- **Extensions made for previous versions of Pixelorama will fail to load on this version.** Make sure to re-download the extensions you want.
- The timeline now scrolls when adding/moving layers, when the current cel is changing from shortcuts or from the timeline buttons, and when cels, frames and layers are being dragged.
- The layer effect settings dialog now scrolls automatically when dragging layer effects to re-order them.
- When moving frames using the arrow buttons in the timeline, all moved cels are now being selected. [#1358](https://github.com/Orama-Interactive/Pixelorama/pull/1358)
- The "Offset/Zoom" effect has been renamed to "Offset & Scale". [#1362](https://github.com/Orama-Interactive/Pixelorama/pull/1362)
- On Linux, the native screen color picker of the operating system is now used.
- The canvas can now be moved by arrow keys if there is a selection tool selected, but there is not an active selection. If there is, the selection itself gets moved, just like before.

### Fixed
- The canvas no longer jitters when it is zoomed out a lot and smooth zoom is enabled.
- The screen color picker now works properly on Linux, users can pick colors outside of Pixelorama's window.
- Optimized the "Mirror Image" effect when a selection is active. Now it should no longer lag on big canvases.
- Fixed a crash when a user selects a 3D object, then does an undo or redo [#1353](https://github.com/Orama-Interactive/Pixelorama/pull/1353)
- Fixed tilemap cells being erased in manual mode if there are cells outside of the canvas boundaries.
- Invisible layers are no longer included when exporting images in headless mode, such as from the command line. [#1368](https://github.com/Orama-Interactive/Pixelorama/issues/1368)
- Fixed transparent checkers not following canvas movement vertically, if "Follow canvas movement" was enabled, and "Follow canvas zoom level" was disabled from the Preferences.
- The color picker's RGB values can no longer go higher than 255. [#349](https://github.com/Orama-Interactive/Pixelorama/issues/349)
- Fixed the restore to default button in the Preferences not hiding after being clicked next to text fields and color buttons.
- Fixed the "Open last project" button in the splash screen not hiding in the Web version.

## [v1.1.5] - 2025-09-06
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 4.4.1

### Added
- Project palettes have been implemented, with undo/redo support! [#1335](https://github.com/Orama-Interactive/Pixelorama/pull/1335)
- Implemented loading Krita (`.kra`) files with animation support. Only projects using RGBA with 8-bit color depth are supported at the moment.
- Loading animations from Photoshop (`.psd`) files is now possible.
- Loading palettes from Aseprite (`.ase`/`.aseprite`) files is now possible.
- Implemented loading Piskel (`.piskel`) files with animation support.
- Added a zoom parameter to the offset shader. [#1330](https://github.com/Orama-Interactive/Pixelorama/pull/1330)
- The currently selected frame & layer are now remembered inside `.pxo` files.
- Added an option to transform content in Modify selection. [#1309](https://github.com/Orama-Interactive/Pixelorama/pull/1309)
- Relative paths are now supported in the CLI. [#1326](https://github.com/Orama-Interactive/Pixelorama/pull/1326)

### Changed
- Bumped extensions API version to 7.
- When clicking on the remove layer button, now all selected layers get removed. This is consistent with how frames get deleted, and is what users would expect.
- During animation playback on frames of a tag, if the user changes to a frame of a different tag, then the frames of that tag are being played. [#1311](https://github.com/Orama-Interactive/Pixelorama/pull/1311)
- Using the move tool on a tilemap layer while draw tiles mode is active now clears the selection, if there is any. [#1340](https://github.com/Orama-Interactive/Pixelorama/pull/1340)
- Current frame & layer are used as default values when importing an image as a new frame, new layer or to replace a cel.

### Fixed
- The bucket tool's flood fill has been further optimized. [#1306](https://github.com/Orama-Interactive/Pixelorama/pull/1306)
- Creating rectangular selections now snap to the grid correctly, if snapping is enabled. [#1338](https://github.com/Orama-Interactive/Pixelorama/pull/1338)
- Pasted selections now get snapped to grid. [#1340](https://github.com/Orama-Interactive/Pixelorama/pull/1340)
- Pasting a selection on a tilemap layer while draw tiles mode is active now updates the tileset. [#1340](https://github.com/Orama-Interactive/Pixelorama/pull/1340)
- Backups no longer appear in the recent project list. [#1341](https://github.com/Orama-Interactive/Pixelorama/pull/1341)
- The names of the projects are no longer being translated in tabs. [#1334](https://github.com/Orama-Interactive/Pixelorama/issues/1334)
- Fixed the drop shadow dialog not having a selected option by default for the affect option button.

## [v1.1.4] - 2025-08-13
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 4.4.1

### Added
- Implemented the ability to set shortcuts for toggling layer visibility and lock from the preferences. There are no default shortcuts for these at the moment.

### Fixed
- Fixed selection tools selecting pixels in wrong positions. [#1318](https://github.com/Orama-Interactive/Pixelorama/pull/1318)

## [v1.1.3] - 2025-08-06
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 4.4.1

### Added
- Implemented limited support of Photoshop (`.psd`) file importing. [#1308](https://github.com/Orama-Interactive/Pixelorama/pull/1308)
- Added ability to edit individual tiles in tilemap layers even in place only mode. [#1253](https://github.com/Orama-Interactive/Pixelorama/pull/1253)
- Added support for batch removal of unused tiles in tilemap layers. [#1253](https://github.com/Orama-Interactive/Pixelorama/pull/1253)
- Added a way to re-apply the last image effect from the Effects menu. [#1310](https://github.com/Orama-Interactive/Pixelorama/pull/1310)
- Clicking a palette swatch with the left/right color now directly adds the color to that swatch. [#1300](https://github.com/Orama-Interactive/Pixelorama/pull/1300)
- You can now remove colors from palette swatches by holding <kbd>Control</kbd> while clicking on them. [#1300](https://github.com/Orama-Interactive/Pixelorama/pull/1300)
- A new "Auto add colors" option has been added. When enabled, new colors drawn on canvas will automatically get added to the palette, if space is available. [#1300](https://github.com/Orama-Interactive/Pixelorama/pull/1300)
- An "ignore in onion skinning" layer property has been added.

### Changed
- The tilemap layer system has been refactored behind the scenes. **This has changed how isometric tiles are being handled, so make sure to keep backups of your old projects if they contain isometric tiles.** [#1253](https://github.com/Orama-Interactive/Pixelorama/pull/1253)
- Isometric tilemap layers now use a pixelated grid that is more accurate. [#1252](https://github.com/Orama-Interactive/Pixelorama/pull/1252)
- The backup system has been re-written, now multiple old sessions are being stored, regardless if Pixelorama crashes or not.  [#1299](https://github.com/Orama-Interactive/Pixelorama/pull/1299)
- Made the movement of frame tags more intuitive. [#1281](https://github.com/Orama-Interactive/Pixelorama/pull/1281)

### Fixed
- Fixed transformations making semi-transparent pixels darker due to alpha pre-multiplication.
- Resizing selections while holding Shift now works properly from all corners.
- Fixed resizing tilemap selection when the tilemap cel grid has an offset.
- Fixed loading APNGs.
- Significantly improved performance of the bucket tool, when a selection is active. [#1304](https://github.com/Orama-Interactive/Pixelorama/pull/1304)
- Made the offset pixels effect only accept integer values for the offset.
- The FX icon in the layer button is now being properly hidden if all effects have been applied.
- Fixed crash when increasing the width of a palette.
- Fixed crash when creating a convolution matrix layer effect.

## [v1.1.2] - 2025-06-26
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), [@VernalUmbrella](https://github.com/VernalUmbrella), [@zibetnu](https://github.com/zibetnu)

Built using Godot 4.4.1

### Added
- The selection transformation system has been completely remade, finally allowing support for easy rotation and skewing! [#1245](https://github.com/Orama-Interactive/Pixelorama/pull/1245)
- A new isometric box tool! [#1246](https://github.com/Orama-Interactive/Pixelorama/pull/1246)
- Added bucket tool fill mode where regions from the merging of all layers are filled. [#1258](https://github.com/Orama-Interactive/Pixelorama/pull/1258)
- Using the move tool on a layer group now moves the content of all of its children.
- You can now hide all other layers when holding Alt and clicking on the visibility button of a layer.
- Users can now change the alpha of the transformation preview from the preferences.
- Added the ability to double-click on the canvas preview to get at the same point on the main canvas. [#1244](https://github.com/Orama-Interactive/Pixelorama/pull/1244)

### Fixed
- Transformed content no longer gets lost when pressing Control + an arrow key. [#1245](https://github.com/Orama-Interactive/Pixelorama/pull/1245)
- Transformed content no longer gets lost when cloning layers & frames.
- Pressing Enter or Cancel when changing the value of a slider in the options of a selection tool when there is an active transformation, no longer confirms/cancels the transformation.
- Fixed a bug where some child layer of group layers were not rendered. [#1268](https://github.com/Orama-Interactive/Pixelorama/pull/1268)
- Group layers with blend modes other than passthrough received a performance boost. [#1269](https://github.com/Orama-Interactive/Pixelorama/pull/1269)
- Fixed a bug where pasting images from the clipboard sometimes did not work, due to them being in different formats than the project image. [#1245](https://github.com/Orama-Interactive/Pixelorama/pull/1245)
- Fixed a bug where changing a palette color in a copied palette also changed the color in the original palette as well. [#1274](https://github.com/Orama-Interactive/Pixelorama/issues/1274)
- Closing the app with Zen Mode no longer hides all panels when opening the app again. [#1238](https://github.com/Orama-Interactive/Pixelorama/issues/1238)
- Fixed broken tool shortcuts on some keyboard layouts. [#1283](https://github.com/Orama-Interactive/Pixelorama/pull/1283)
- The override.cfg file is now being saved to the correct directory. [#1285](https://github.com/Orama-Interactive/Pixelorama/pull/1285)
- Panels can no longer be moved if the Moveable Panels option is turned off. [#1242](https://github.com/Orama-Interactive/Pixelorama/pull/1242)
- Using the bucket tool now confirms the active transformation. [#1245](https://github.com/Orama-Interactive/Pixelorama/pull/1245)
- The canvas rotation now affects the direction of the arrow keys. [#1245](https://github.com/Orama-Interactive/Pixelorama/pull/1245)
- The pixel grid gets immediately redrawn when its visibility is toggled. [#1240](https://github.com/Orama-Interactive/Pixelorama/pull/1240)

## [v1.1.1] - 2025-05-06
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 4.4.1

### Added
- Implemented isometric & hexagonal tile shapes for tilemap layers! [#1213](https://github.com/Orama-Interactive/Pixelorama/pull/1213)
- Implemented a hexagonal grid type, with support for both pointy-top and flat-top orientations.
- It is now possible to flatten all selected layers into one layer.
- Hexagonal pointy-top and flat-top presets have been added in the tile mode offsets dialog.
- Added a single bezier mode in curve tool, that works similarly to Aseprite's curve tool. [#1216](https://github.com/Orama-Interactive/Pixelorama/pull/1216)
- OpenRaster (`.ora`) and Aseprite (`.ase`/`.aseprite`) files are now being displayed as options in the "Open" dialog.
- Added shortcuts for going to the previous/next frame of the same tag. By default, they are mapped to <kbd>Control + <</kbd> and <kbd>Control + ></kbd> respectively.
- Holding the "automatically change layer" shortcut (<kbd>Control + Alt</kbd> by default) now displays a rectangle around the selected cel, or around the cel whose non-transparent pixels are being hovered by the cursor.
- Users can now color code their cels in the timeline.
- A button for reporting extensions has been added to the extension explorer. [#1214](https://github.com/Orama-Interactive/Pixelorama/pull/1214)

### Changed
- Resizing the canvas, cropping to content and centering frames now moves the offset of each tilemap layer instead of affecting its tileset. [#1213](https://github.com/Orama-Interactive/Pixelorama/pull/1213)
- Scaling the project also scales the size of the tiles by the same amount that the project was scaled. For example, scaling a 64x64 project to 128x64 would scale 16x16 tiles to 32x16. [#1213](https://github.com/Orama-Interactive/Pixelorama/pull/1213)
- Switched "tags by column" and "tags by rows" in the export dialog, when exporting spritesheets.
- The minimum window size has been decreased to (300, 200). [#1221](https://github.com/Orama-Interactive/Pixelorama/discussions/1221)
- The pencil/eraser/shading brush flip/rotation UI is now consistent with the tiles panel flip/rotation UI, and it also supports the same shortcuts.
- The shortcut groups in the Preferences have been re-organized. The Buttons group has been removed, instead the shortcuts are grouped according to their respective panels, such as Timeline, Global Tool Options and Palettes.
- Cels with a non-zero z-index display a "z" in the timeline.
- The reference image rotation incerement step was changed to 0.01. [#1210](https://github.com/Orama-Interactive/Pixelorama/pull/#1210)
- When opening the new tag dialog, the name field automatically grabs focus.

### Fixed
- Value sliders and rulers are no longer displaying integers as floats.
- Fixed a crash when using the lasso and polygon select tools outside of the canvas.
- Using the bucket tool on draw tiles mode on an empty tilemap no longer crashes the app. [#1213](https://github.com/Orama-Interactive/Pixelorama/pull/1213)
- Fixed a crash when switching between tilemap layers with different tilesets, while having selected tiles the positions of which do not exist on the new tilemap's tileset. [#1213](https://github.com/Orama-Interactive/Pixelorama/pull/1213)
- Duplicating tilesets in the project properties no longer crashes the app when a previously deleted tileset is still selected. [#1213](https://github.com/Orama-Interactive/Pixelorama/pull/1213)
- Fixed the import tag option not pasting the frame content, and not working for tilemap and audio layers.
- Z-indexed cels are now being rendered with their proper order in the canvas. [#1220](https://github.com/Orama-Interactive/Pixelorama/issues/1220)
- The "change layer automatically" shortcut (<kbd>Control + Alt</kbd> by default) no longer works when a selection tool is active, thus preventing the shortcut conflict with the "transform copy selected content" shortcut.
- Prevent switching project tabs and saving, if a native save file dialog is already open. This prevents rare cases of saving two open projects with the same name, thus leading to data loss.
- The native save file dialog now always has a default name for the saved .pxo file.
- Fixed horizontal scrolling on the timeline on macOS. [#1219](https://github.com/Orama-Interactive/Pixelorama/pull/1219)
- Fixed selection resizing not working from the tool options. [#1212](https://github.com/Orama-Interactive/Pixelorama/issues/1212)
- The tile indices that appear when holding <kbd>Control</kbd> and a tilemap layer is selected, now scale based on the grid cell size. [#1213](https://github.com/Orama-Interactive/Pixelorama/pull/1213)
- Applying layer effects to passthrough group layer immediately updates the canvas.
- The "select pixels" from the cel menu now works properly with undo.
- Fixed a "section not found" error in the Preferences when launching Pixelorama for the first time. [#1211](https://github.com/Orama-Interactive/Pixelorama/pull/#1211)
- Fixed the pencil density slider value not updating when switching between tools.
- Fixed the color picker acting weirdly when the alpha of the color is set to 0.
- Rulers now update whenever the canvas panel resizes.
- Fixed a regression in v1.1 where mouse button shortcuts (such as the mouse thumb buttons) were not activating tools.
- Empty audio layers now only show the audio icon in the frame where the audio is supposed to start playing.
- Fixed issue where the wrong font would be chosen for the interface in certain circumstances. [#1217](https://github.com/Orama-Interactive/Pixelorama/pull/#1217)
- Fixed canvas preview's camera not being fit to frame when Pixelorama first launches and the canvas preview is visible.

### Removed
- The "All" grid type option has been removed, as it is no longer needed since we can now display multiple grids at once.

## [v1.1] - 2025-03-28
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), Spencer Beckwith ([@spencerjbeckwith](https://github.com/spencerjbeckwith)), [@myyc](https://github.com/myyc), João Vitor ([@dev-joaovitor](https://github.com/dev-joaovitor))

Built using Godot 4.4

### Added
- Tilemap layers have arrived! Tilemap layers allow artists to create tiles, and easily preview and dynamically modify them within Pixelorama. [#1146](https://github.com/Orama-Interactive/Pixelorama/pull/1146)
- Indexed mode has finally been implemented! [#1136](https://github.com/Orama-Interactive/Pixelorama/pull/1136)
- Audio layers have been added, allowing artists to easily synchronize their animations with audio. [#1149](https://github.com/Orama-Interactive/Pixelorama/pull/1149)
- Added a new text tool. Destructive only for now, meaning that once the text is confirmed, it cannot be changed later. [#1134](https://github.com/Orama-Interactive/Pixelorama/pull/1134)
- A "Paste from Clipboard" option has been added to the Edit menu, allowing images from the operating system's clipboard to be pasted into Pixelorama. Note that copying images from Pixelorama into the OS' clipboard has not been implemented at the moment.
- A color curves image and layer effect has been added.
- A gradient layer effect has been added, alongside its already existing image effect equivalent, allowing for non-destructive gradient generation.
- It is now possible to load custom Godot shaders as image and layer effects.
- Importing OpenRaster (`.ora`) and Aseprite (`.ase`/`.aseprite`) files is now possible. Exporting to these file formats is not yet supported.
- Loading custom dithering patterns as images is now possible. This is not exposed somewhere in the UI yet, users have to go to Pixelorama's data folder (the same place where its settings, backups etc are kept), and create a "dither_matrices" folder and add the images there.
- A new Reset layout option has been added to the Layouts submenu, that can be used to reset default layouts to their original state.
- Implemented support for multiple grids. [#1122](https://github.com/Orama-Interactive/Pixelorama/pull/1122)
- Overhauled the gradient edit widget's UI and added options such as reverse and evenly distribute points, and gradient presets.
- Users can now color code their layers in the timeline.
- A new "Select cel area" option has been added to the Selection menu that makes a rectangular selection around the content of the active cel, and it is mapped to <kbd>Control + T</kbd> by default.
- Added a "Select pixels" option in the right click popup menu button of cel buttons
- Added a shortcut to swap tools, <kbd>Shift + X</kbd> by default. [#1173](https://github.com/Orama-Interactive/Pixelorama/pull/1173)
- Added <kbd>V</kbd> as the default shortcut for the crop tool.
- A "Show Reference Images" option has been added to the View menu, allowing quick and easy reference image toggling.
- Hiding the notification labels is now possible from the Preferences.
- StartupWMClass has been added to Pixelorama's Linux .desktop file. [#1170](https://github.com/Orama-Interactive/Pixelorama/pull/1170)

### Changed
- The Manage Layouts dialog has been replaced by new items in the Layouts submenu, that are responsible for adding and deleting layouts.
- The default shortcuts of the Move tool and the Pan tool have been changed to <kbd>M</kbd> and <kbd>A</kbd> respectively.
- The "Image" menu has been renamed to "Project". This name should be more accurate, since this menu has options that affect the entire project.
- Simplified the change layer automatically shortcut to just <kbd>Control + Alt</kbd>.
- The image and layer effects have been organized into subcategories.
- Layer buttons in the timeline now have a small icon on their right side that denotes their type, such as pixel layers, group layers, 3D layers, tilemap layers and audio layers.
- Layer buttons in the timeline also have an icon if the layers contain at least one layer effect.
- The import dialog is always being opened when opening images from File > Open.
- The extension crash preventing system has been revised. [#1177](https://github.com/Orama-Interactive/Pixelorama/pull/1177)
- The minimum cel size is now smaller, and it can get even smaller by decreasing the font size from the Preferences.
- System font names are now sorted by alphabetical order.
- The red, green, blue and alpha buttons in invert and desaturate layer effects have been made into "RGBA" buttons instead of checkboxes, just like they are in their image effect counterparts.
- "Tile Mode" under the Selection menu has been renamed to "Wrap Strokes". This does not affect the "Tile Mode" option in the View menu. [#1150](https://github.com/Orama-Interactive/Pixelorama/pull/1150)
- Improved the look of 3D object gizmos. [#1194](https://github.com/Orama-Interactive/Pixelorama/pull/1194)
- Re-organized the licenses in the About dialog. There are now three license categories, the Pixelorama license, the Godot licenses and the third-party licenses.

### Fixed
- The text is no longer blurry and hard to read of menus and dialog windows, if the display scale is set to anything but 100%. This was fixed due to the update to Godot 4.4. [#1065](https://github.com/Orama-Interactive/Pixelorama/issues/1065)
- Saving pxo files should no longer freeze the application on GNOME, when using native file dialogs. This was fixed due to the update to Godot 4.4. [#1115](https://github.com/Orama-Interactive/Pixelorama/issues/1115)
- Fixed crash when Pixelorama starts without a palette.
- Undo/redo now works again when the cursor is hovering over the timeline.
- The first frame is no longer exported twice when using ping-pong loop.
- Fixed pencil/eraser/shading previews turning white for a brief moment when changing image brushes, and when switching between tools.
- Fixed the preview on the left tool not being visible, if the right tool had a preview. [#1157](https://github.com/Orama-Interactive/Pixelorama/issues/1157)
- Dialogs that are children of other dialogs now always appear on top, to avoid issues where they could hide behind their parents and causing confusion that made Pixelorama seem unresponsive.
- Palette swatches now get deleted when the user removes all palettes.
- The CLI's output option now works with filepaths instead of just filenames. [#1145](https://github.com/Orama-Interactive/Pixelorama/pull/1145)
- Fixed a crash when importing a model in a 3D layer. [952498a](https://github.com/Orama-Interactive/Pixelorama/commit/952498a2b8a72f0c7cdca87e763fc18ea12d8b5f)
- Loading obj files as custom models in 3D layers that are not paired with .mtl files now works. [#1165](https://github.com/Orama-Interactive/Pixelorama/issues/1165)
- Fixed a UI bug where the minimum size of the panels was not calculated correctly. [a28b526](https://github.com/Orama-Interactive/Pixelorama/commit/a28b526645d2cc085b0d3eca9d0756aee8a6f978)
- Dockable panels are now properly sorted when toggling movable panels. [d7ba7fe](https://github.com/Orama-Interactive/Pixelorama/commit/d7ba7fe6fc4f2efb587234634020bf567474dba9)
- Changing the name of pxo files when saving them in the Web version now works as intended. [faae464](https://github.com/Orama-Interactive/Pixelorama/commit/faae4648f0751b72cff0ff174c74cac2c499b994)
- Pixelorama's window no longer spawns at the position of a monitor that has been disconnected. [#1189](https://github.com/Orama-Interactive/Pixelorama/pull/1189)
- Fixed the resize canvas dialog's offset not resetting to zero on dialog popup. [f273918](https://github.com/Orama-Interactive/Pixelorama/commit/f273918368f568f860a8d08d28f5c9d9346461a4)
- Fixed group layer blending when they contain invisible layers. [#1166](https://github.com/Orama-Interactive/Pixelorama/issues/1166)
- Fixed color picker changing hue when modifying the saturation and value inside the color picker shape. [3f2245c](https://github.com/Orama-Interactive/Pixelorama/commit/3f2245cd9bc81b1a244ae394927aa074650a5d70)
- Fixed the Palettize effect and palette exporting to images storing slightly wrong color values. [77f6bcf](https://github.com/Orama-Interactive/Pixelorama/commit/77f6bcf07bd80bc042e478bb883d05900cebe436)
- Fixed some issues with the Palettize effect where the output would be different if the palette size changed and empty swatches were added, even if the colors themselves stayed the same. Initially fixed by [bd7d3b1](https://github.com/Orama-Interactive/Pixelorama/commit/bd7d3b19cc98804e9b99754153c4d553d2048ee3), but [1dcb696](https://github.com/Orama-Interactive/Pixelorama/commit/1dcb696c35121f8208bde699f87bb75deff99d13) is the proper fix.
- The lasso and polygon select tools now select all expected pixels without gaps, when the selection goes out of the canvas bounds.
- Fixed bug where the child windows of floating windows appear behind them.
- Fixed layouts overwriting the position info of panels, which were added by extensions. [#1172](https://github.com/Orama-Interactive/Pixelorama/pull/1172)
- Image export with split layers no longer ignores layer effects. [#1193](https://github.com/Orama-Interactive/Pixelorama/issues/1193)
- Fixed recorder label not updating when project is changed. [#1139](https://github.com/Orama-Interactive/Pixelorama/pull/1139)
- The vertical scrollbar in the timeline is no longer visible when it's not needed.
- Fixed a bug where the mouse cursor does not reset to default when hovering over a selection gizmo, and the selection gets cleared. [ead7593](https://github.com/Orama-Interactive/Pixelorama/commit/ead7593e7e4013238b9e935ee24d8cea0ad49b38)
- Fixed a curve tool preview bug where the preview was changing when the cursor was moving, but the end point was staying the same. [d0fef33](https://github.com/Orama-Interactive/Pixelorama/commit/d0fef332315a856d3ef0384eddee89c6c61eb6e0)

## [v1.0.5] - 2024-11-18
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 4.3

### Added
- Add density to the square & circle brushes. 100% density means that the brush gets completely drawn. Anything less leaves gaps inside the brush, acting like a spray tool.
- Selection expanding, shrinking and borders have been added as options in the Select menu.
- Mouse buttons can now be used as menu shortcuts. [#1070](https://github.com/Orama-Interactive/Pixelorama/issues/1070)
- Added confirm and cancel buttons in the selection tool options to confirm/cancel an active transformation.
- OKHSL Lightness sorting in palettes has been implemented. [#1126](https://github.com/Orama-Interactive/Pixelorama/pull/1126)

### Changed
- The brush size no longer changes by <kbd>Control</kbd> + Mouse Wheel when resizing the timeline cels or the palette swatches.
- Improved the UI of the Tile Mode Offsets dialog and added an "Isometric" preset button.
- The Recorder panel now automatically records for the current project. This also allows for multiple projects to be recorded at the same time.

### Fixed
- Opening the Tile Mode Offsets dialog no longer crashes the application.
- Panels no longer get scrolled when using the mouse wheel over a slider.
- Fixed layer effect slider values being rounded to the nearest integer.
- Fixed memory leak where the project remained referenced by a drawing tool, even when its tab was closed.
- Fixed memory leak where the first project remained forever references in memory by the Recorder panel.
- Slightly optimize circle brushes by only calling the ellipse algorithms once while drawing.

### Removed
- The Recorder panel has been removed from the Web version. It wasn't functional anyway in a way that was useful, and it's unsure if we can find a way to make it work.

## [v1.0.4] - 2024-10-25
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), Mariano Semelman ([@msemelman](https://github.com/msemelman))

Built using Godot 4.3

### Added
- It is now possible to make panels into floating windows. This allows for any panel in the user interface to be its own window, and if single window mode is disabled, you can move these windows anywhere you want. This is especially useful for multi-monitor setups.
- Added a new "color replace" mode to the Shading tool, that uses the colors of the palette to apply shading. [#1107](https://github.com/Orama-Interactive/Pixelorama/pull/1107)
- Added a new Erase blend mode. [#1117](https://github.com/Orama-Interactive/Pixelorama/pull/1117)
- It is now possible to change the font, depth and line spacing of 3D text.
- Implemented the ability to change the font of the interface from the preferences.
- Clipping to selection during export is now possible. [#1113](https://github.com/Orama-Interactive/Pixelorama/pull/1113)
- Added a preference to share options between tools. [#1120](https://github.com/Orama-Interactive/Pixelorama/pull/1120)
- Added an option to quickly center the canvas in the View menu. Mapped to <kbd>Shift + C</kbd> by default. [#1123](https://github.com/Orama-Interactive/Pixelorama/pull/1123)
- Added hotkeys to switch between tabs. <kbd>Control+Tab</kbd> to go to the next project tab, and <kbd>Control+Shift+Tab</kbd> to go to the previous. [#1109](https://github.com/Orama-Interactive/Pixelorama/pull/1109)
- Added menus next to each of the two mirroring buttons in the Global Tool Options, that allow users to automatically move the symmetry guides to the center of the canvas, or the view center.
- A new Reset category has been added to the Preferences that lets users easily restore certain options.

### Changed
- Bumped extensions API version to 5.
- The screen no longer remains on when idle, avoiding unnecessary power consumption. [#1125](https://github.com/Orama-Interactive/Pixelorama/pull/1125)
- The export dialog's resize slider now allows for values greater than 1000.
- Made some UI improvements to the rotate/flip image brush options. [#1105](https://github.com/Orama-Interactive/Pixelorama/pull/1105)
- The bucket tool now picks colors from the top-most layer, like the rest of the drawing tools.

### Fixed
- The move tool preview is now properly aligned to the pixel grid.
- Camera zoom is now being preserved when switching between projects.
- Projects are no longer being saved with the wrong name in the Web version.
- Fixed 3D Shape Edit tool option values not updating when switching between 3D objects.
- Using the bucket tool while moving the cursor and also holding the color picker shortcut (Alt by default), now picks colors instead of actually using the tool.
- Tool previews are now being properly cleared when switching to other tools before finishing the action being performed by the previous tool.
- Fixed icons not being set to the correct color when launching Pixelorama with the dark theme.
- Fixed some text in the About dialog not having the text color of the theme.
- Fixed the backup confirmation dialog closing when clicking outside of it when single window mode is disabled.
- The dynamics dialog is now set to its correct size when something is made visible or invisible. [#1104](https://github.com/Orama-Interactive/Pixelorama/pull/1104)
- The color picker values no longer change when using RAW mode. [#1108](https://github.com/Orama-Interactive/Pixelorama/pull/1108)
- Fixed some icon stretch and expand modes in the UI. [#1103](https://github.com/Orama-Interactive/Pixelorama/pull/1103)

## [v1.0.3] - 2024-09-13
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), [alikin12](https://github.com/alikin12), Vaibhav Kubre ([@kubre](https://github.com/kubre)), Donte ([@donte5405](https://github.com/donte5405))

Built using Godot 4.3

### Added
- Added new global layer buttons that change visibility, lock or expand all layers on the first level. [#1085](https://github.com/Orama-Interactive/Pixelorama/pull/1085)
- Added a new Gaussian blur image and layer effect.
- A new Index Map layer effect has been added. [#1093](https://github.com/Orama-Interactive/Pixelorama/pull/1093)
- Is it now possible to adjust the opacity of onion skinning. [#1091](https://github.com/Orama-Interactive/Pixelorama/pull/1091)
- Added option to trim the empty area of the exported images. [#1088](https://github.com/Orama-Interactive/Pixelorama/pull/1088)
- A quality slider has been added to the export dialog, when exporting jpg files.

### Changed
- The layer opacity and frame buttons are now fixed on top, always visible regardless of the vertical scroll position. [#1095](https://github.com/Orama-Interactive/Pixelorama/pull/1095)
- The default blend mode of layer groups is now pass-through.
- The color picker popup when editing gradients is now moveable.

### Fixed
- Fixed an issue where the '\n` escape character got inserted inside the palette name, causing the palette to fail to be saved.
- The export dialog has been optimized by caching all of the blended frames. Changing export options, besides the layers, no longer cause slowness by re-blending all of the frames.
- Optimized the lasso and polygon select tools, as well as the fill options of the pencil and curve tools. The time they take to complete now depends on the size of the selection, rather than checking all of the pixels of the entire canvas.
- Fixed a crash when re-arranging palette swatches while holding <kbd>Shift</kbd>.
- Fixed a crash when using the move tool snapped to the grid.
- Fixed wrong preview in the gradient dialog when editing the gradient and dithering is enabled.
- Fixed a visual bug with the preview of the resize canvas dialog.
- Fixed wrong stretch mode in the cel button previews. [#1097](https://github.com/Orama-Interactive/Pixelorama/pull/1097)

## [v1.0.2] - 2024-08-21
This update has been brought to you by the contributions of:
[kleonc](https://github.com/kleonc), [Hamster5295](https://github.com/Hamster5295), [alikin12](https://github.com/alikin12)

Built using Godot 4.3

### Added
- Group layer blending is now supported. To prevent a layer group from blending, you can set its blend mode to "Pass through". [#1077](https://github.com/Orama-Interactive/Pixelorama/pull/1077)
- Added <kbd>Control+Shift+Alt</kbd> as a shortcut that automatically selects a layer directly from the canvas when using tools.
- Added tolerance to the bucket tool's "similar area" mode and to the magic wand tool.
- It is now possible to move all selected cels between different frames, but they all have to be on the same layer.
- Added a convolution matrix layer effect, still work in progress.
- Native file dialogs now have a checkbox that lets you save blended images inside .pxo files.
- It is now possible to change the maximum undo steps from the Preferences.
- Cel properties of group and 3D cels can now be edited.

### Changed
- Renamed the "similarity" slider of the select by color tool and the bucket tool's "similar colors" mode to "tolerance", and made it work the inverse way to make it consistent with other art software.
- It is now possible to change the blend modes of multiple selected layers from the timeline's option button.

### Fixed
- The Web version no longer requires SharedArrayBuffer, so compatibility with certain browsers should be better now.
- Scaling with cleanEdge and OmniScale is now working again. [#1074](https://github.com/Orama-Interactive/Pixelorama/issues/1074)
- Layer effects are now being applied when exporting single layers.
- Exporting group layers now takes blending modes and layer effects into account.
- Fixed crashes when attempting to export specific layers or tags that have been deleted.
- Fixed crashes when importing brushes and palettes.
- Fixed an issue with the bucket tool filling with the wrong color.
- Fixed an issue when merging two layers, where if the bottom layer had layer/cel transparency, the transparency would be applied in the content destructively.
- Fixed an issue where color sliders wouldn't be visible during startup, if the color options button was expanded.
- Fixed bug where some buttons on the interface were not affected by the custom icon color on startup.
- Fixed an issue when loading a project, selecting a project brush and then switching tools. [#1078](https://github.com/Orama-Interactive/Pixelorama/pull/1078)
- Fixed wrong rendering of the isometric grid. [#1069](https://github.com/Orama-Interactive/Pixelorama/pull/1069)

## [v1.0.1] - 2024-08-05
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), [Kiisu_Master](https://github.com/Kiisu-Master).

Built using Godot 4.2.2

### Added
- Added an image effect that lets you adjust color properties of the image, such as brightness and contrast.
- It is now possible to toggle low processor usage mode in the Preferences (called "Update continuously"). [#1056](https://github.com/Orama-Interactive/Pixelorama/pull/1056)

### Changed
- It is no longer possible to click outside of a dialog to close it.
- Animation tag importing can now open from the frame button right-click menu. [#1041](https://github.com/Orama-Interactive/Pixelorama/pull/1041)
- The previews of the elliptical selection and the shape tools are now being mirrored, if a mirroring mode is enabled. This makes them consistent with the rectangle, lasso, paint and polygon selection tools.

### Fixed
- The previews of the shape and selection tools no longer make Pixelorama to be so slow.
- The performance of the shape tool drawing has been improved.
- Fixed an issue where if you increased a palette's width but also decreased its height, some colors would be lost, and re-ordering colors immediately after resizing would result in even more data loss. [#684](https://github.com/Orama-Interactive/Pixelorama/issues/684)
- Dialogs no longer close when Pixelorama's main window loses focus and regains it.
- When single window mode is disabled, popup dialogs are no longer unclickable. [#1054](https://github.com/Orama-Interactive/Pixelorama/issues/1054)
- Popups no longer appear in places outside the main window, if single window mode is disabled.
- The zoom tool modes now actually reflect their behavior.
- Fixed a bug where the opacity of multiple selected layers got automatically changed to be the same as the last selected layer's opacity.
- Fixed an issue with some Windows versions where the dialogs could not be re-opened. [#1061](https://github.com/Orama-Interactive/Pixelorama/issues/1061)
- The performance of the spritesheet smart slice has been improved. [#1046](https://github.com/Orama-Interactive/Pixelorama/pull/1046)
- Fixed issue with image effects changing the color of non-opaque pixels unintentionally.
- The clipping mask preview when using the move tool and the offset image effect now works correctly. [#1057](https://github.com/Orama-Interactive/Pixelorama/pull/1057)
- Fixed a crash that sometimes happened when selecting an imported model in a 3D cel.

## [v1.0] - 2024-07-29
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), Clara Hobbs ([Ratfink](https://github.com/Ratfink)), [TheLsbt](https://github.com/TheLsbt), [RorotoSic](https://github.com/RorotoSic), Ivan Kruger ([haythamnikolaidis](https://github.com/haythamnikolaidis)), [Kiisu_Master](https://github.com/Kiisu-Master), [Anaminus](https://github.com/Anaminus).

Built using Godot 4.2.2

### Added
- Multiple layer blend modes are finally here! Note that group blending is not currently supported. [#911](https://github.com/Orama-Interactive/Pixelorama/pull/911)
- Non-destructive layer effects have been implemented. [#940](https://github.com/Orama-Interactive/Pixelorama/pull/940)
- A new curve tool has been implemented. It contains a "fill shape" tool option, allowing it to be used as a polygon tool as well. [#1019](https://github.com/Orama-Interactive/Pixelorama/pull/1019)
- [Pixelorama is now available on Steam!](https://store.steampowered.com/app/2779170). Consider purchasing on Steam as a way to support the development of the project, and getting benefits such as automatic updates and even Steam Achievements!
- An extension explorer has been integrated into Pixelorama, allowing for easy extension downloading from the internet. [#910](https://github.com/Orama-Interactive/Pixelorama/pull/910)
- Export to video formats. FFMPEG is required to be installed in the device in order for video exporting to work. [#980](https://github.com/Orama-Interactive/Pixelorama/pull/980)
- Importing video formats and gif files is also possible, but FFMPEG is again required for this.
- Basic clipping mask functionality has been implemented. Enabling clipping mask on a layer will use the layer directly below it as the mask. Note that right now group layers cannot be used as masks.
- Alpha lock has been added as a global tool option. When enabled, users can only draw on non-transparent pixels.
- Export to webp and jpeg file formats. Webp is currently only for static images and does not support animations.
- A basic Command Line Interface has been implemented, to help with automating mass project file exporting. [#579](https://github.com/Orama-Interactive/Pixelorama/discussions/579)
- A 64-bit ARM build is now also available along with the 32-bit ARM build.
- Dragging and dropping multiple frames or layers to re-arrange them is now (finally!) supported, instead of only moving the last layer/frame selected.
- Users can now create new tags from the frame right-click menu, by clicking on "New Tag".
- It is now possible to edit a tag's properties by clicking on its name from the timeline, and to move and resize it by dragging its edges.
- Users can now resize the timeline's cel size from the timeline settings, which used to be onion skinning settings.
- Exporting the project's data to a separate JSON file is now possible from the export dialog.
- Native file dialogs are now supported and can be enabled from the Preferences!
- Dialog popups can now be native OS windows instead of embedded within Pixelorama's main window. This can be changed from the Preferences.
- Added some missing shortcuts for buttons. [#900](https://github.com/Orama-Interactive/Pixelorama/pull/900)
- Palette colors can now be sorted.
- Added new Pixelize and Palettize effects. Pixelize makes the image pixelated, and Palettize maps the color of the input to the nearest color in the selected palette. Useful for limiting color in pixel art and for artistic effects. Can also act as a workaround for the current lack of a proper indexed mode.
- Exporting each layer as a different file is now possible.
- The bucket tool now supports filling while the mouse is moving and the button is still being held.
- A new boot splash image is being shown when Pixelorama is loading, instead of a gray color.
- The brush increment/decrement shortcuts can now be changed. [#900](https://github.com/Orama-Interactive/Pixelorama/pull/900)
- Changing layers is now possible with keyboard shortcuts (Control + Up/Down arrow keys by default).
- A "Crop to Selection" option has been added to the Image menu, that crops the image based on the active selection.
- A stabilizer for smoother drawing has been implemented.
- Users can now add custom data in the form of text in their projects, layers, frames, tags and cels.
- Image brushes can now be flipped and rotated with 90 degree steps in the tool options. [#988](https://github.com/Orama-Interactive/Pixelorama/pull/988)
- Added support for inverted tablet pens. [#966](https://github.com/Orama-Interactive/Pixelorama/pull/966)
- Added new dialogs for cel, layer and project properties. Cel and layer which can be accessed by right-clicking cel and the layer buttons in the timeline respectively, while project properties can be found under the Image menu.
- A new z-index property has been added to the cel properties, allowing for independent, per-frame layer ordering.
- Dragging and dropping images directly from a Web browser into Pixelorama is now possible! Note that this may not work with all browsers.
- Pasting tags from other projects is now possible. [#946](https://github.com/Orama-Interactive/Pixelorama/pull/946)
- A new "Pixelorama" palette has been added to the default palettes.
- <kbd>Control + Shift + T</kbd> has been added as a default shortcut that opens the last project.
- Imported `.gpl` palettes now take into account their "Columns" field. [#1025](https://github.com/Orama-Interactive/Pixelorama/pull/1025)
- "Snap to" settings from the View menu are now being remembered between sessions.
- The step of the zoom and rotation canvas sliders can now be snapped, to 100 and 45 respectively.
- It is now possible to change the color space of gradients from sRGB, which is the default, to Linear sRGB and Oklab.
- 3D layers now support torus shapes. [#900](https://github.com/Orama-Interactive/Pixelorama/pull/900)
- Image effect animation now supports the tweening transition method of spring. [#900](https://github.com/Orama-Interactive/Pixelorama/pull/900)
- Added a new Rose theme.

### Changed
- The file format of pxo files has been changed. Pxo files are now zip files in disguise. [#952](https://github.com/Orama-Interactive/Pixelorama/pull/952)
- Similarly, the file format of Pixelorama's palette files has been changed from .tres back to .json as they used to be in the past. This change had to happen due to [security concerns regarding Godot's resource files](https://github.com/godotengine/godot-proposals/issues/4925). [#967](https://github.com/Orama-Interactive/Pixelorama/pull/967)
- Changes made to the User Interface layouts are now automatically being saved. To restore a default layout, users can go to Window > Manage Layouts > Add and select from one of the default layouts.
- Pixelorama's icon has changed.
- The config file has been renamed from "cache.ini" to "config.ini". This effectively means that preferences edited in v0.x will not be automatically be carried over to v1.0.
- The colors of the themes has been limited and grouped to allow for easier theming, using this [new stand-alone tool](https://github.com/Orama-Interactive/PixeloramaThemeCreator).
- The color picker is now always visible in the user interface as its own panel, instead of being a popup. The previous color buttons have been re-purposed to allow for setting whether the color being selected is for the left or the right tool.
- The color pickers has been vastly improved, thanks to the update to Godot 4. Users can now use the OKHSL color mode, and choose between four different picker shapes: HSV Rectangle (default), HSV Wheel, VHS Circle and OKHSL Circle.
- The opacity slider in the timeline now affects layer opacity and not cel opacity. Cel opacity has been moved to the cel properties dialog.
- Bucket tool's "similar colors" mode now changes the same color in all selected cels, acting as a color replace for multiple cels.
- The timeline's UI has been changed to better indicate which cels are selected and improves on how child layers of groups are being shown.
- The onion skinning settings has been changed into general timeline settings.
- Cel-specific effects have been moved from the Image menu into the new Effects menu.
- Linked cels no longer have a colored outline, they now have a rectangle behind their preview which makes linked cels look like they are chained together.
- "Crop Image" has been renamed to "Crop to Content".
- Imported images automatically become new projects without opening the import dialog, if there is only one project open, and that project is empty.
- Window opacity is disabled by default to improve performance, but it can be enabled in the Preferences.
- Reference images have received some nice improvements, including undo/redo and easy transformations directly on the canvas. [#961](https://github.com/Orama-Interactive/Pixelorama/pull/961)
- The add/remove swatch color buttons have been moved to the same horizontal container as the palette select and add/edit palette buttons, allowing for Inkscape-like horizontal placement of the palette panel, without any wasted space.
- Cel buttons now hide their transparent background when their corresponding cels are empty, instead of just dimming them.
- Every shader-based image effect is automatically working without the need to change renderers, and they all work now on the Web version. This comes at the cost of less compatibility, as the desktop version now requires OpenGL 3.3 minimum instead of 2.1, and the Web version requires WebGL 2 instead of WebGL 1. [#900](https://github.com/Orama-Interactive/Pixelorama/pull/900)
- The dynamics popup only show the relevant properties to which dynamics are currently toggled on.
- When attempting to enable an extension, a confirmation dialog appears, as an extra security step.
- The aspect ratio button in the Scale Image dialog is toggled on by default.
- Negative values in shading tool options are now allowed. [#1015](https://github.com/Orama-Interactive/Pixelorama/issues/1015)
- If "Include frame tags in the file name" is enabled in the export window, the tag name is included even when exporting a single file.
- When deleting an extension, a confirmation window now appears that lets users either to delete the palette permanently, move it to trash, or cancel. [#919](https://github.com/Orama-Interactive/Pixelorama/pull/919)
- "Developers" and "Contributors" have been merged into "Authors" in the About dialog. "Donate" has also been removed from there, and a new "Support Pixelorama's Development" option has been added to the Help menu.

### Fixed
- There should be less crashes overall. 0.x versions crashed randomly on some devices, probably due to how Godot 3 handled memory management for images, but 1.0 no longer seems to cause these crashes.
- Performance when drawing and doing operations such as bucket area fill should be better now. [#900](https://github.com/Orama-Interactive/Pixelorama/pull/900)
- Selections now scale properly when they are not transforming any image content. [#774](https://github.com/Orama-Interactive/Pixelorama/issues/774)
- The aspect ratio is now being kept correctly in image effect dialog previews.
- Dividing by zero in value sliders and spinboxes no longer crashes the program.
- Default palettes are now available for clean installs on macOS. [#1008](https://github.com/Orama-Interactive/Pixelorama/pull/1008)
- When drawing, the focus of other GUI elements of the application now gets released. This prevents behaviors such as switching the focus of GUI elements with, for example, the arrow keys while moving the canvas or an active selection with the arrow keys.
- The canvas no longer remains in the drag state when the mouse it outside of it. Meaning, if the middle mouse button or space is being pressed to drag the canvas, and the mouse gets out of the canvas while the button is still pressed and then it is released, when the mouse re-enters the canvas, it is no longer being dragged.
- Pixelorama no longer quits when saving from the File menu, if the user attempted to save on exit before and cancelled the save file dialog.
- The delete layer button is now immediately disabled when locking a layer, thus preventing the user from being able to delete a locked layer.
- Button shortcuts, such as <kbd>X</kbd> for switch colors, no longer get activated when they shouldn't, like when pressing <kbd>Control + X</kbd>. [#1014](https://github.com/Orama-Interactive/Pixelorama/issues/1014)
- System language should now pick locales more reliably. [#372](https://github.com/Orama-Interactive/Pixelorama/issues/372)
- Fixed a bug where the exported files had the wrong tag name, if "Include frame tags in the file name" was enabled.
- The text of the rulers is now being properly clipped. [#1023](https://github.com/Orama-Interactive/Pixelorama/pull/1023)

### Removed
- BubbleGum16, Complementary, Monochromatic, Shades and Triad palettes have been removed from the default palettes.
- The frame tag button has been removed from the timeline.
- It is no longer possible to change the renderer from the Preferences, as GLES3 is now the only option.
