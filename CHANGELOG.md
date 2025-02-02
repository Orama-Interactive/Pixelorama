# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). All the dates are in YYYY-MM-DD format.
<br><br>

## [v1.1] - Unreleased
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), Spencer Beckwith ([@spencerjbeckwith](https://github.com/spencerjbeckwith))

Built using Godot 4.3

### Added
- Tilemap layers have arrived! Tilemap layers allow artists to create tiles, and easily preview and dynamically modify them within Pixelorama. [#1146](https://github.com/Orama-Interactive/Pixelorama/pull/1146)
- Indexed mode has finally been implemented! [#1136](https://github.com/Orama-Interactive/Pixelorama/pull/1136)
- Audio layers have been added, allowing artists to easily synchronize their animations with audio. [#1149](https://github.com/Orama-Interactive/Pixelorama/pull/1149)
- Added a new text tool. Destructive only for now, meaning that once the text is confirmed, it cannot be changed later. [#1134](https://github.com/Orama-Interactive/Pixelorama/pull/1134)
- A "Paste from Clipboard" option has been added to the Edit menu, allowing images from the operating system's clipboard to be pasted into Pixelorama. Note that copying images from Pixelorama into the OS' clipboard has not been implemented at the moment.
- A color curves image and layer effect has been added.
- It is now possible to load custom Godot shaders as image and layer effects.
- A new Reset layout option has been added to the Layouts submenu, that can be used to reset default layouts to their original state.
- Implemented support for multiple grids. [#1122](https://github.com/Orama-Interactive/Pixelorama/pull/1122)
- Overhauled the gradient edit widget's UI and added options such as reverse and evenly distribute points, and gradient presets.
- Added <kbd>V</kbd> as the default shortcut for the crop tool.
- A "Show Reference Images" option has been added to the View menu, allowing quick and easy reference image toggling.

### Changed
- The Manage Layouts dialog has been replaced by new items in the Layouts submenu, that are responsible for adding and deleting layouts.
- The image and layer effects have been organized into subcategories.
- Layer buttons in the timeline now have a small icon on their right side that denotes their type, such as pixel layers, group layers, 3D layers, tilemap layers and audio layers.
- Layer buttons in the timeline also have an icon if the layers contain at least one layer effect.
- System font names are now sorted by alphabetical order.
- The red, green, blue and alpha buttons in invert and desaturate layer effects have been made into "RGBA" buttons instead of checkboxes, just like they are in their image effect counterparts.
- "Tile Mode" under the Selection menu has been renamed to "Wrap Strokes". This does not affect the "Tile Mode" option in the View menu. [#1150](https://github.com/Orama-Interactive/Pixelorama/pull/1150)

### Fixed
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
- Fixed the resize canvas dialog's offset not resetting to zero on dialog popup. [f273918](https://github.com/Orama-Interactive/Pixelorama/commit/f273918368f568f860a8d08d28f5c9d9346461a4)
- Fixed group layer blending when they contain invisible layers. [#1166](https://github.com/Orama-Interactive/Pixelorama/issues/1166)
- Fixed color picker changing hue when modifying the saturation and value inside the color picker shape. [3f2245c](https://github.com/Orama-Interactive/Pixelorama/commit/3f2245cd9bc81b1a244ae394927aa074650a5d70)
- Fixed the Palettize effect and palette exporting to images storing slightly wrong color values. [77f6bcf](https://github.com/Orama-Interactive/Pixelorama/commit/77f6bcf07bd80bc042e478bb883d05900cebe436)
- Fixed some issues with the Palettize effect where the output would be different if the palette size changed and empty swatches were added, even if the colors themselves stayed the same. Initially fixed by [bd7d3b1](https://github.com/Orama-Interactive/Pixelorama/commit/bd7d3b19cc98804e9b99754153c4d553d2048ee3), but [1dcb696](https://github.com/Orama-Interactive/Pixelorama/commit/1dcb696c35121f8208bde699f87bb75deff99d13) is the proper fix.
- Fixed recorder label not updating when project is changed. [#1139](https://github.com/Orama-Interactive/Pixelorama/pull/1139)
- The vertical scrollbar in the timeline is no longer visible when it's not needed.
- Fixed a bug where the mouse cursor does not reset to default when hovering over a selection gizmo, and the selection gets cleared. [ead7593](https://github.com/Orama-Interactive/Pixelorama/commit/ead7593e7e4013238b9e935ee24d8cea0ad49b38)

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

## [v0.11.4] - 2024-04-17
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 3.5.2

### Added
- Exporting palettes to png files is now possible.
- Progressive Web App (PWA) has been enabled for the Web version.

### Changed
- When quitting, multiple save confirmation dialogs now appear, each for every project that has changes.
- Loop through frames when clicking on go to previous/next frame buttons on the timeline.
- High res display is now enabled on macOS. [#936](https://github.com/Orama-Interactive/Pixelorama/issues/936)
- Make cloned frames only select a cel if its corresponding original cel was selected as well. [#941](https://github.com/Orama-Interactive/Pixelorama/pull/941)
- All of the timeline buttons now have the same size (24x24).

### Fixed
- Memory usage has been greatly optimized when doing operations such as drawing, image effects, selecting, transforming, etc, as the images stored in memory are now compressed. [#883](https://github.com/Orama-Interactive/Pixelorama/issues/883)
- Fixed memory leak when applying image effects. [7235617db7c21837edc7ba7b95f2e7eeb1140691](https://github.com/Orama-Interactive/Pixelorama/commit/7235617db7c21837edc7ba7b95f2e7eeb1140691)
- Fixed memory leak when previewing layouts in the Manage Layouts dialog. [b2f511c45be61cd26f01e134bf7a6a55109f46ad](https://github.com/Orama-Interactive/Pixelorama/commit/b2f511c45be61cd26f01e134bf7a6a55109f46ad)
- Attempting to load an invalid pxo file no longer crashes the application. [3f6e1385e06cd7801fe12fbf90a9649557ea8f2e](https://github.com/Orama-Interactive/Pixelorama/commit/3f6e1385e06cd7801fe12fbf90a9649557ea8f2e)
- Tool shortcuts can now work with <kbd>Control</kbd>. [#935](https://github.com/Orama-Interactive/Pixelorama/issues/935)
- Optimize canvas drawing by only updating it when the image(s) have changed. [ac6a4db43d9296ebc03e639d8199dd3878a25d86](https://github.com/Orama-Interactive/Pixelorama/commit/ac6a4db43d9296ebc03e639d8199dd3878a25d86)
- Fix bug where using shortcuts to switch between frames also moved the selection, causing deletions.
- Pxo files can now be loaded from the Open menu option in the Web version. [3dcc51705a999145e53a8e6d4de217dc03b0f147](https://github.com/Orama-Interactive/Pixelorama/commit/3dcc51705a999145e53a8e6d4de217dc03b0f147)
- The same frames are no longer being exported multiple times when "Selected frames" is selected, and multiple cels of the same frames are currently selected on the timeline. [#1001](https://github.com/Orama-Interactive/Pixelorama/issues/1001)
- Fixed crash due to division by zero when locking two or three ValueSliders, and one of them has the value of 0 and the user attempts to change it. [3b8c63c4a6a3325707ef624942ea50834634e45c](https://github.com/Orama-Interactive/Pixelorama/commit/3b8c63c4a6a3325707ef624942ea50834634e45c)
- Fixed exporting selected layers not including the non-selected frames. [324e21776de853e6ea24703d5724a491547371ab](https://github.com/Orama-Interactive/Pixelorama/commit/324e21776de853e6ea24703d5724a491547371ab)
- Fix bug where images with width or height 1 are being completely cleared by image effects. [fcfc606861d247856db5473b702628ebd71df43f](https://github.com/Orama-Interactive/Pixelorama/commit/fcfc606861d247856db5473b702628ebd71df43f)
- Made the color picker not select fully transparent pixels that are not black. [#999](https://github.com/Orama-Interactive/Pixelorama/issues/999)
- Brushes are no longer being drawn outside the selection, if the selection is outside the canvas. [5f43a3e2829a7119d18d0762796222f20170f410](https://github.com/Orama-Interactive/Pixelorama/commit/5f43a3e2829a7119d18d0762796222f20170f410)
- Bucket "similar color" and "whole selection" modes and image effects no longer affect pixels outside the selection area, if the selection is outside the canvas. [436406a527f0db67c5e2b58a90b43597b3168600](https://github.com/Orama-Interactive/Pixelorama/commit/436406a527f0db67c5e2b58a90b43597b3168600)
- The ellipse tool no longer produces gaps with large sizes. [4f3a7a305a264e0d2fe86c201af76eca4b2fea0a](https://github.com/Orama-Interactive/Pixelorama/commit/4f3a7a305a264e0d2fe86c201af76eca4b2fea0a)
- Fix "visible layers" option on the export dialog producing wrong results. [346d1f071a8c6b1defb1072d39aea9c642f1ef59](https://github.com/Orama-Interactive/Pixelorama/commit/346d1f071a8c6b1defb1072d39aea9c642f1ef59)
- Random brushes now work again. [1317e40ffa5e9f01a9d214221bb5133db20a1de9](https://github.com/Orama-Interactive/Pixelorama/commit/1317e40ffa5e9f01a9d214221bb5133db20a1de9)
- Fixed issue where the override.cfg file would be created at the wrong location, if Pixelorama is launched through a shortcut. [0c6566de761a683a0e8a781131024a1dedb9734f](https://github.com/Orama-Interactive/Pixelorama/commit/0c6566de761a683a0e8a781131024a1dedb9734f)
- The gizmo in the rotation image effect dialog is now accurately following the mouse.
- Fixed the size label not being updated on the Export dialog's spritesheet tab when the direction changes. [9a5eb9720d2328f914f8efc3b9aa605dadca99b0](https://github.com/Orama-Interactive/Pixelorama/commit/9a5eb9720d2328f914f8efc3b9aa605dadca99b0)
- The "Export dimensions" label in the export dialog no longer shows fractions as the final image's size.

## [v0.11.3] - 2023-10-30
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 3.5.2

### Changed
- When deleting a palette, a confirmation window now appears that lets users either to delete the palette permanently, move it to trash, or cancel. [#914](https://github.com/Orama-Interactive/Pixelorama/pull/914)

### Fixed
- Fixed undo/redo history not working when the tool changes. [#916](https://github.com/Orama-Interactive/Pixelorama/pull/916)
- Pixelorama no longer closes when the project fails to be saved if "Save & Exit" is selected. [#920](https://github.com/Orama-Interactive/Pixelorama/pull/920)

## [v0.11.2] - 2023-08-31
This update has been brought to you by the contributions of:
[@Lsbt1](https://github.com/Lsbt1), Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 3.5.2

### Added
- An option for reference images to only appear as silhouettes. [#898](https://github.com/Orama-Interactive/Pixelorama/pull/898)
- Snapping to the center of the rectangular grid is now possible. [#905](https://github.com/Orama-Interactive/Pixelorama/pull/905)

### Fixed
- Fixed a critical bug causing data loss when moving around the tabs of opened projects and then saving them. [#901](https://github.com/Orama-Interactive/Pixelorama/pull/901)
- Loading corrupt pxo files no longer crashes the program. [#904](https://github.com/Orama-Interactive/Pixelorama/pull/904)

### Removed
- Pxo files saved with versions prior to v0.8 can no longer get loaded starting version 0.11.2. If you have old files that you need to load, load them in an earlier version first (from v0.8 to v0.11.1) and save them again. [#904](https://github.com/Orama-Interactive/Pixelorama/pull/904)

## [v0.11.1] - 2023-08-12
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), [@20kdc](https://github.com/20kdc), Matteo Piovanelli ([@MatteoPiovanelli-Laser](https://github.com/MatteoPiovanelli-Laser))

Built using Godot 3.5.2

### Added
- A new offset image effect to easily move the image around, with animation support.
- Implemented a "smart slicer" system that lets the software automatically slice a spritesheet in separate frames on image import, without the user having to specify horizontal and vertical frames. [#893](https://github.com/Orama-Interactive/Pixelorama/pull/893)
- Added optional integer zooming for the canvas, which can be enabled from the Preferences. Disabled by default. [#894](https://github.com/Orama-Interactive/Pixelorama/pull/894)
- Fast way to clone frames of a tag. [#861](https://github.com/Orama-Interactive/Pixelorama/pull/861)
- Added a reverse frames option on the right click menu of the frame buttons, to easily reverse the order of the selected frames.
- A new Timeline category in the Preferences with options such as the colors of onion skinning's color mode, and whether a layer should be selected when a layer button (such as lock, visibility etc) gets pressed.
- It is now possible to disable saving frames that have a tag to a different folder, as well as specifying a separator character in the file names.
- Palette file types now exist as filters in the Open file dialog.
- .bmp and .tga file types now exist in the Open dialog of the Web version.

### Changed
- The image effect animation system introduced in v0.11 has been overhauled with a better user interface, and with tweening options. [#879](https://github.com/Orama-Interactive/Pixelorama/pull/879)
- Images stored in RAM for the undo/redo system when draw tools are used are now compressed. This reduces RAM usage. [#890](https://github.com/Orama-Interactive/Pixelorama/pull/890)
- The cel opacity slider now affects all of the selected cels. [#865](https://github.com/Orama-Interactive/Pixelorama/pull/865)
- The right click menu of the frame buttons now works for all selected frames, besides "move left" and "move right".
- The canvas is automatically enlarged when importing an image of a larger size to the project.
- Error codes are now being explained in the error messages. [#891](https://github.com/Orama-Interactive/Pixelorama/pull/891)
- Newly cloned frames are now automatically selected. [#861](https://github.com/Orama-Interactive/Pixelorama/pull/861)
- "Centralize Image" has been moved from the Image menu to the frame button right click menu. [#884](https://github.com/Orama-Interactive/Pixelorama/pull/884)
- The project's name is no longer saved inside .pxo files. Loaded projects now get their name directly from the file name.
- Clicking on a layer button (such as lock, visibility etc) no longer selects the layer by default. This behavior can now be changed in the Preferences.
- The image menu has been re-arranged. [#878](https://github.com/Orama-Interactive/Pixelorama/pull/878)
- The "OK" button of the save and export dialogs are now named "Save" and "Export" respectively. [#876](https://github.com/Orama-Interactive/Pixelorama/pull/876)

### Fixed
- Generating palettes from the current project no longer crashes when group and 3D layers exist.
- Fixed wrong saturation and value values. They were divided by 360, while they should have been divided by 100. [#879](https://github.com/Orama-Interactive/Pixelorama/pull/879)
- Fixed image effect animations appearing when changing the affected option, even if that image effect had no animatable properties. [#879](https://github.com/Orama-Interactive/Pixelorama/pull/879)

## [v0.11] - 2023-06-13
This update has been brought to you by the contributions of:
[@mrtripie](https://github.com/mrtripie), Martin Novák ([@novhack](https://github.com/novhack)), Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), [@20kdc](https://github.com/20kdc), Arron Washington ([@radicaled](https://github.com/radicaled)), Christos Tsoychlakis ([@ChrisTs8920](https://github.com/ChrisTs8920))

Built using Godot 3.5.2.

### Added
- Layer groups in the timeline, for better organization. [#698](https://github.com/Orama-Interactive/Pixelorama/pull/698)
- Support for reference images has been implemented. [#771](https://github.com/Orama-Interactive/Pixelorama/pull/771)
- Specific layer exporting is now possible as part of the export dialog overhaul. [#781](https://github.com/Orama-Interactive/Pixelorama/pull/781)
- 3D layers have now been implemented, which allows for non-destructive usage of 3D geometry inside Pixelorama. The 3D objects get automatically rasterized (pixelated) depending on the size of the canvas. [#840](https://github.com/Orama-Interactive/Pixelorama/pull/840)
- A perspective editor has been added, that aims to help artists use perspective in their work. [#806](https://github.com/Orama-Interactive/Pixelorama/pull/806)
- Dynamics are finally here! You can now use tablet pen pressure and/or mouse/pen velocity to affect the size and the alpha of the brush. More options will come in the future!
- A new crop tool has been added. It can resize the canvas without resizing the content. [#830](https://github.com/Orama-Interactive/Pixelorama/pull/830)
- The pencil tool now has a spacing option. [#813](https://github.com/Orama-Interactive/Pixelorama/pull/813)
- Exporting and loading APNG files is now possible. [#772](https://github.com/Orama-Interactive/Pixelorama/pull/772) and [#797](https://github.com/Orama-Interactive/Pixelorama/pull/797)
- Implemented [cleanEdge](http://torcado.com/cleanEdge/) as a new rotation and scaling algorithm. [#794](https://github.com/Orama-Interactive/Pixelorama/pull/794)
- [GLES 3 only] Implemented [OmniScale](https://github.com/nobuyukinyuu/godot-omniscale) as a new rotation and scaling algorithm. [08e00d3](https://github.com/Orama-Interactive/Pixelorama/commit/08e00d3c31dd134be037b672b7ac1d192400ac4d)
- Added a new Posterize image effect, with optional dithering. It's used to automatically reduce colors of an image.
- A new select by drawing tool has been added. [#792](https://github.com/Orama-Interactive/Pixelorama/pull/792)
- Some image effect properties can now be animated for multiple cels. [#836](https://github.com/Orama-Interactive/Pixelorama/pull/836)
- It is now possible to change the selection creation behavior (replace, add, subtract or intersect) from the tool settings. [#798](https://github.com/Orama-Interactive/Pixelorama/pull/798)
- Your art progress inside Pixelorama can now be recorded and saved as screenshots, for you to combine into a video. Useful for art timelapses. [#823](https://github.com/Orama-Interactive/Pixelorama/pull/823)
- Control + Mouse wheel can now be used to adjust the brush size and shape thickness. Unfortunately, this shortcut cannot be edited at the moment, but it will be in the future (most likely once we port to Godot 4.x). [#776](https://github.com/Orama-Interactive/Pixelorama/discussions/776)
- Snapping to the grid and guides has been implemented.
- Changing the renderer from GLES2 to GLES3 and vice versa is now possible in the preferences.
- Selections now have their own tile mode option, that works within the boundaries of the selection. [#834](https://github.com/Orama-Interactive/Pixelorama/pull/834)
- A way to easily preview an animation that has frames drawn in the form of a spritesheet/atlas has been added in the canvas preview. [#835](https://github.com/Orama-Interactive/Pixelorama/pull/835)
- The average color between the two selected colors is now shown in the color pickers, and can be easily picked. [#822](https://github.com/Orama-Interactive/Pixelorama/pull/822)
- A list of the recently used project sizes now appears on the new project dialog. [#819](https://github.com/Orama-Interactive/Pixelorama/pull/819)
- [Windows only] Changing the tablet driver is now possible in the preferences.

### Changed
- The palette panel is now more reactive; it automatically resizes in order to show/hide swatches based on its size. It is also now possible to scroll palettes with the mouse wheel, and resize the swatches with Control + mouse wheel. [#761](https://github.com/Orama-Interactive/Pixelorama/pull/761)
- The UI of the animation timeline has been improved. [#769](https://github.com/Orama-Interactive/Pixelorama/pull/769)
- The entire export dialog UI has been overhauled. [#781](https://github.com/Orama-Interactive/Pixelorama/pull/781)
- Linked cels have been refactored, which allows for having multiple linked sets of cels in the same layer. [#764](https://github.com/Orama-Interactive/Pixelorama/pull/764)
- Most Slider + SpinBox combinations have been replaced by a custom slider, made by [@mrtripie](https://github.com/mrtripie).
- Gradient generation is now more powerful; there is now support for multi-color gradients and they can be repeated. Step gradients have been removed in favor of linear gradients with constant interpolation.
- The color picker now picks any visible color on the canvas, regardless of layer. A toggle has also been added in the tool options to let the user change back to the previous behavior of only picking a color on the selected layer. [#816](https://github.com/Orama-Interactive/Pixelorama/pull/816)
- A single popup appears when exporting multiple files that already exist, instead of showing one popup for each file to overwrite. [#585](https://github.com/Orama-Interactive/Pixelorama/discussions/585)
- Most dialogs received some UI changes, such as making their elements expand vertically, and making their Cancel and OK buttons a little bigger.
- The look of the brushes popup has been improved. [#815](https://github.com/Orama-Interactive/Pixelorama/pull/815)
- The cel buttons on the timeline are now dimmed if the cel is empty/transparent.
- The manage layout dialog now has a preview for the selected layout. [#787](https://github.com/Orama-Interactive/Pixelorama/pull/787)
- Layer adding behavior has been changed. [#767](https://github.com/Orama-Interactive/Pixelorama/pull/767)
- The canvas rulers can now display floating point numbers. [#800](https://github.com/Orama-Interactive/Pixelorama/pull/800)
- The tile mask, used in tile mode, is now being set automatically. [#833](https://github.com/Orama-Interactive/Pixelorama/pull/833)
- When having multiple cels selected and onion skinning is enabled, using the Move tool now also has an immediate visible effect on the onion skinning preview. [#862](https://github.com/Orama-Interactive/Pixelorama/pull/862)
- Onion skinning settings are now being saved and are remembered between sessions. [#857](https://github.com/Orama-Interactive/Pixelorama/pull/857)
- Contributors and donors in the About dialog are now sorted in alphabetical order.

### Fixed
- The timeline has been refactored behind the scenes, and its performance has been massively improved for projects with a lot of frames and layers. [#698](https://github.com/Orama-Interactive/Pixelorama/pull/698)
- If Pixelorama crashes during saving of a .pxo file and a file of the same name already exists in that directory, it no longer gets replaced with an empty 0 byte file. [#763](https://github.com/Orama-Interactive/Pixelorama/issues/763)
- [macOS] Fixed issue where tool shortcuts changed tools. [#784](https://github.com/Orama-Interactive/Pixelorama/pull/784)
- The movement preview now works as intended for all selected cels [#811](https://github.com/Orama-Interactive/Pixelorama/pull/811) for the move tool, [5cb0edd](https://github.com/Orama-Interactive/Pixelorama/commit/5cb0eddae5983b29a378a34ad4919116f911a403) for the selected content.
- The UI scale no longer is 0.75 by default. This fixes blurry fonts on small monitors.
- Opening the rotate image dialog twice on large canvases no longer results in a crash. [ad61ddc](https://github.com/Orama-Interactive/Pixelorama/commit/ad61ddc2c0c251e8e20da3369c072e48380c0cd3)
- Pasted content should no longer get placed in sub-pixel positions. [403539b](https://github.com/Orama-Interactive/Pixelorama/commit/403539bb4794d81289214c4eda5226e70b9af19a)
- The notifications always appear on the bottom left of the main canvas and are no longer dependent on the position of the timeline.
- The recent files option in the File menu is now disabled in the Web version, instead of save.
- Drawing with image brushes no longer results in pixels outside the selection, if it exists. [30d279c](https://github.com/Orama-Interactive/Pixelorama/commit/30d279c4948b5712dac87bf6575932ca30d1c4dc)
- Using the selection gizmos when an overlay window is directly on top of them is no longer possible.
- Fix bug where the tool changes from a draw tool to a non-draw tool, while having an image brush selected. The bug was that the indicator was appearing as a white square, until the user moved their mouse.
- Fix bug where clicking on previous/next frame when only one frame exists makes the cel unselected. [6b58768](https://github.com/Orama-Interactive/Pixelorama/commit/6b587688f12dcc027c2f43832f179e4dca73a702)
- Mirror symmetry axes are now properly centered by default. [#843](https://github.com/Orama-Interactive/Pixelorama/pull/843)
- The "File(s) exported" notification now only appears on successful export.
- Fix selection handles and shape tool previews not working properly when mirror view is enabled. [#860](https://github.com/Orama-Interactive/Pixelorama/pull/860)
- Undoing after pasting now shows the previous selection as normal.
- The right tool gets activated only if the right mouse button (or whatever input action is assigned) is first pressed. [cc332c6](https://github.com/Orama-Interactive/Pixelorama/commit/cc332c6cbf3f9265a95a4bdc4998c9ca6c4f750a)
- No more errors in the debugger or the terminal appear when attempting to undo/redo while drawing. [af2b1fe](https://github.com/Orama-Interactive/Pixelorama/commit/af2b1feb1f63144ebce00520ea2f8ee832dc49bd)

## [v0.10.3] - 2022-09-26
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind))

Built using Godot 3.5.

### Added
- The UI now automatically gets scaled, based on the dpi and resolution of the monitor. Resolves [#643](https://github.com/Orama-Interactive/Pixelorama/issues/643).
- A "Divide into equal parts" button has been added in Gradient Map. This is meant for easy gradient bisecting, which is helpful for converting Linear/Cubic interpolated gradients into Constant. This will eventually be used in gradient generation as well, once multi-color gradient generation support gets implemented.
- A new fill area option has been added to the bucket tool options, "Whole Selection". This fills the entire selection with a color or pattern, regardless of the colors of the pixels.
- The UI can now be scaled down to 0.5 and 0.75.
- Palette swatches now get highlighted if their color is selected from the color buttons. [#730](https://github.com/Orama-Interactive/Pixelorama/pull/730)
- Project tabs can now be closed with the middle mouse button.
- Non-keyboard shortcut bindings for tools are now allowed. You can, for example, map your tools to a mouse or gamepad button.
- The background color of the canvas is now configurable, as requested in [#586](https://github.com/Orama-Interactive/Pixelorama/discussions/586).

### Changed
- Circle brushes now scale properly and support even-numbered diameters.
- Copy, cut & delete now affect the entire cel if there is no selection.
- The paste placement behavior has been changed. Paste now places the pasted content in the middle of the canvas view, instead of its original position. A new option in the Edit menu has been added, "Paste in Place", that preserves the previous behavior.
- If a layer is locked or invisible, the cursor changes into forbidden when the user is hovering the mouse over the canvas.
- The left & right tool options now have a header with the name of the currently selected tool, and a color indicator on the top.
- The preferences dialog has been polished. Headers have been added for each segment, and all of the elements are now vertically aligned with each other.
- hiDPI is now enabled - solves [#159](https://github.com/Orama-Interactive/Pixelorama/issues/159).
- The recent projects menu now makes the most recent project appear on top, and if you open a project already in the recent projects list, it would then be moved to the most recent spot on the list. [#755](https://github.com/Orama-Interactive/Pixelorama/pull/755)
- The import dialog now remembers the last option. [#754](https://github.com/Orama-Interactive/Pixelorama/pull/754)
- In the bucket tool options, "Same color area" and "Same color pixels" have been renamed to "Similar area" and "Similar colors" respectively.
- The splash and preference dialogs can now be resized to a smaller size than the default.

### Fixed
- Deleting content from locked/invisible layers is no longer possible.
- Selection can no longer be moved if there is a dialog open.
- Tool and menu shortcuts no longer get activated if a dialog is open. [#709](https://github.com/Orama-Interactive/Pixelorama/issues/709).
- Onion skinning now works properly with mirror view. Addresses part of [#717](https://github.com/Orama-Interactive/Pixelorama/issues/717).
- Fix invalid pattern image error when using the bucket tool to replace colors.
- Fixed issue with the bucket tool where if the selected color is the same as the pixel's color in mouse position, the operation stops even if there are other cels selected.
- The "Close" button in the preferences no longer remains stuck in the previous language, if the language changes and the previous one was not English.

## [v0.10.2] - 2022-08-18
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), [@GrantMoyer](https://github.com/GrantMoyer)

Built using Godot 3.5.

### Added
- A gradient map image effect. Addresses the second half of [#595](https://github.com/Orama-Interactive/Pixelorama/discussions/595).
- A new rotation type, Rotxel with smear. Thanks to [azagaya](https://github.com/azagaya) for the shader code.
- The pivot in the rotate image dialog can now be changed by the user. [#720](https://github.com/Orama-Interactive/Pixelorama/pull/720)
- New offset options in tile mode that allow for non-rectangular tiling. [#707](https://github.com/Orama-Interactive/Pixelorama/pull/707)
- A basic API for Extensions. Has not been documented yet and is still experimental.
- A similarity option in the Select by Color tool. [#710](https://github.com/Orama-Interactive/Pixelorama/pull/710)
- The left and right tool colors in the background of the tool buttons and the indicators on the canvas can now be changed from the Preferences.
- Added Danish translations.

### Changed
- Copying now works between multiple Pixelorama instances, and the clipboard is even being remembered when the app closes. Note that you cannot copy image data to another software, and you cannot paste image data from another software into Pixelorama. [#693](https://github.com/Orama-Interactive/Pixelorama/pull/693)
- Importing multiple images at once from File, Open is now possible.
- On image effect dialogs, the preview will show all of the selected cels instead of only one cel. [#722](https://github.com/Orama-Interactive/Pixelorama/pull/722)
- The indicator for the right tool is now enabled and orange by default.
- On quit, the "Save & Exit" button is now focused by default.
- The icon for onion skinning options has changed. [#711](https://github.com/Orama-Interactive/Pixelorama/pull/711)
- Extensions are now being automatically reloaded if the user installs an already-existing extension, without the need to restart Pixelorama.

### Fixed
- Fixed a macOS crash on startup. [90d2473](https://github.com/Orama-Interactive/Pixelorama/commit/90d2473f5256425146a8c10f539b7737aa37fd23)
- Even-numbered thickness sizes on the rectangle and ellipse shape tools now work as expected. The thickness of the shapes no longer goes up by 2 pixels. [23f591a](https://github.com/Orama-Interactive/Pixelorama/commit/23f591a8626c12fd7e6344ab59f8e33b8d20cb99)
- [[Keychain](https://github.com/Orama-Interactive/Keychain)] Fixed issue with menu events being triggered by actions that are not exact matches. This means that, for example, "Control + Shift + S" will no longer activate both "Save" and "Save as", but only "Save as". [09c9583](https://github.com/Orama-Interactive/Keychain/commit/09c95835ef034effa949732cf9cf9bd315ed08a8)
- Massively improved the performance of the selection system, most notably the Rectangle Selection and Select by Color tools, and selection content deletion. [#710](https://github.com/Orama-Interactive/Pixelorama/pull/710)
- Performance when drawing big lines on big canvases has been increased, thanks to the update to Godot 3.5. Most likely due to [godotengine/godot#62826](https://github.com/godotengine/godot/pull/62826)
- Fixed issue with save file dialog taking the name of the first file it sees. [5d65e82](https://github.com/Orama-Interactive/Pixelorama/commit/5d65e820708ed7586fdb7f0ac4633f7b468ec73d)
- Fixed grid-based snapped movement when the offset of the grid was larger than the grid size. [#712](https://github.com/Orama-Interactive/Pixelorama/pull/712)
- Fixed the symmetry points being on the wrong location on project initialization. [f432def](https://github.com/Orama-Interactive/Pixelorama/commit/f432defd1f92fde0677a5d10fde87e5219e47065)
- The quick color picker shortcut of the shape tools is now mapped to the correct action. [55935bc](https://github.com/Orama-Interactive/Pixelorama/commit/55935bcfd2597b9fc6be94c40542934e5f99aefc)
- The canvas preview play button now respects frame tags.
- Implemented a crash protection measure when loading extensions. [#715](https://github.com/Orama-Interactive/Pixelorama/pull/715)
- Fixed a crash when importing a spritesheet as a new layer, undoing and then exporting. [dcebf89](https://github.com/Orama-Interactive/Pixelorama/commit/dcebf894bf14b7de371f4661ec80c5f158087a23)
- Window transparency now only affects the transparency of the Main Canvas's TabContainer. [#734](https://github.com/Orama-Interactive/Pixelorama/pull/734)

## [v0.10.1] - 2022-06-06
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), Matteo Piovanelli ([@MatteoPiovanelli-Laser](https://github.com/MatteoPiovanelli-Laser)), [@AlphinAlbukhari](https://github.com/AlphinAlbukhari), Martin Novák ([@novhack](https://github.com/novhack))

### Added
- The [Keychain plugin](https://github.com/Orama-Interactive/Keychain) has been implemented. Keychain makes Pixelorama's shortcut system fully configurable, and it provides the ability to the users to set custom shortcuts of every input type for all input actions. The plugin is developed by us and it's free to use for your own Godot projects as well! [#700](https://github.com/Orama-Interactive/Pixelorama/pull/700)
- The cursor can now be moved with the numpad arrow keys and gamepad's left stick and d-pad, the canvas can be moved with gamepad's right stick and it is also possible to map the activate left and right tool actions to keyboard and gamepad buttons, to allow drawing from these devices, making Pixelorama a lot more accessible. Made possible by the Keychain plugin.
- A lot more gradient options have been added. Apart from the Linear Step gradient, there are now Linear, Radial, Radial Step, Linear Dithering and Radial Dithering gradient types. They are all shader-based, so they are a lot faster than the previous method. [#677](https://github.com/Orama-Interactive/Pixelorama/pull/677)
- A drop shadow image effect has been added. [#674](https://github.com/Orama-Interactive/Pixelorama/pull/674)
- A new rotation method has been added. It is shader-based, therefore faster than the other methods. [#683](https://github.com/Orama-Interactive/Pixelorama/pull/683)
- All menu items now have changeable shortcuts. Made possible by the Keychain plugin.
- The dimensions of the exported file(s) are now visible in the export dialog. [#686](https://github.com/Orama-Interactive/Pixelorama/pull/686)

### Changed
- The outline effect is now generated using shaders, except in the Web platform. This makes outline generation more faster and gives better results.
- In the backup confirmation dialog, "Delete" has been changed to "Discard all" and a Cancel button has been added.
- Grid, pixel grid, rulers and guides view menu settings are now being remembered when Pixelorama closes and opens again.
- The export window is now more clear if the directory path, the file name or both are invalid. [#669](https://github.com/Orama-Interactive/Pixelorama/pull/669)
- Timeline scroll behavior has been tweaked. [#682](https://github.com/Orama-Interactive/Pixelorama/pull/682)
- Image brush size is now using percentage suffix (%) instead of pixels (px). [#671](https://github.com/Orama-Interactive/Pixelorama/pull/671)
- The brushes popup tab alignment and position has changed depending on where it's asked to popup. [#671](https://github.com/Orama-Interactive/Pixelorama/pull/671)
- It is now possible to delete content from all selected cels.

### Fixed
- The flood fill algorithm (bucket tool's "same color area" mode) is now a lot faster. [#667](https://github.com/Orama-Interactive/Pixelorama/pull/667) and [#672](https://github.com/Orama-Interactive/Pixelorama/pull/672)
- Based on the above, the magic wand tool is also a lot faster.
- Shader-based image effects are now a lot faster if there is no selection.
- GIF exporting is now faster. [#696](https://github.com/Orama-Interactive/Pixelorama/pull/696)
- Fixed issue with the bucket tool's "same color pixels" method not working in all selected cels.
- Fixed broken 90-degree rotation. [#676](https://github.com/Orama-Interactive/Pixelorama/pull/676)
- Fixed export bug where the path is being changed if there's a folder with the same name as the file.
- Fixed visual bug caused by window opacity. [#680](https://github.com/Orama-Interactive/Pixelorama/pull/680)
- It is no longer possible to delete content from cels belonging to invisible or locked cels.
- Scale image aspect ratio is now updating correctly when the dialog is about to appear.
- Going into fullscreen mode and then exiting it no longer makes the window opacity not working properly. Note that window opacity still does not work when in fullscreen mode.

## [v0.10] - 2022-04-15
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), Martin Novák ([@novhack](https://github.com/novhack)), Lili Zoey ([@sayaks](https://github.com/sayaks)), [@ArthyChaux](https://github.com/ArthyChaux)

### Added
- A new Window menu has been added that has the new UI system options, as well as Zen mode and Fullscreen mode that were previously under the View menu.
- A similarity option has been added to the "same color pixels" mode of the bucket tool. [#649](https://github.com/Orama-Interactive/Pixelorama/pull/649)
- Added an experimental Extensions system that will let the users make their own extensions that add new functionality to Pixelorama. Keep in mind that this is still experimental and backwards compatibility is NOT guaranteed - use at your own risk.
- A grayscale mode for the canvas has been added to the View menu. [#646](https://github.com/Orama-Interactive/Pixelorama/pull/646)
- Bulk importing images has been made easier by adding an "Apply to all" checkbox that uses the same import options for all images that are to be imported. [#624](https://github.com/Orama-Interactive/Pixelorama/pull/624)
- Extra cursor options have been added to the Preferences that let the user use the native mouse cursors of the OS and toggle the cross cursor on or off for the canvas, and the "Indicators" tab has been renamed to "Cursors".
- Frame duration now appears as a hint tooltip of the frame buttons.
- Added Portuguese translation.

### Changed
- The UI system has changed completely. Users can re-arrange all of the panels and place them wherever they want, resize them or hide them from view. It is also possible to save and load custom UI layouts. [#640](https://github.com/Orama-Interactive/Pixelorama/pull/640)
- The secondary canvas is hidden from view by default, but it can become visible by going to the Window > Panels.
- The mirroring and pixel perfect options are now global tool options and affect both left and right tools.
- Various timeline improvements, like deleting and cloning multiple selected frames and when creating new frames, tags that are in front of them are being pushed. If the currently selected frames are inside a tag, creating new frames makes the tag bigger. [#648](https://github.com/Orama-Interactive/Pixelorama/pull/648)
- The custom mouse cursor now scales with the UI. [#642](https://github.com/Orama-Interactive/Pixelorama/issues/642)
- Importing an image will replace the previous project, if that project is empty.
- Clicking on a layer toggle button (lock, visible & cel linking) now selects that layer.
- Resize Canvas will always display the current size of the project.
- Imported images can now be immediately exported, and for imported png images "Overwrite" is being displayed instead of "Export", until the user uses "Export as...".
- The toolbar and the animation timeline now have a scrollbar.
- Cut no longer works in invisible/locked layers.
- You can now move guides with the pan tool. [#647](https://github.com/Orama-Interactive/Pixelorama/pull/647)
- "Flip" has been renamed to "Mirror Image".
- The documentation keyboard shortcut has been changed from F12 to F1.

### Fixed
- Drawing with big brush sizes has been optimized. [#657](https://github.com/Orama-Interactive/Pixelorama/pull/657) - which was based on [#554](https://github.com/Orama-Interactive/Pixelorama/pull/554)
- The "same color pixels" mode of the bucket tool has become a lot faster because it now uses a shader. [#649](https://github.com/Orama-Interactive/Pixelorama/pull/649) - which was based on [#613](https://github.com/Orama-Interactive/Pixelorama/pull/613)
- Fixed crash when importing non-palette .tres files.
- Deferred mode for the color pickers of gradients has been enabled, so that the gradient preview color only changes on mouse release. Addressed a part of [#645](https://github.com/Orama-Interactive/Pixelorama/issues/645).
- "From Current Palette" preset option is now disabled when creating a new palette, if there is no current palette, which fixes [#659](https://github.com/Orama-Interactive/Pixelorama/issues/659)
- Aspect ratio in scale image no longer sets width and height to have the same value, but it works as expected like it does in the create new image dialog.
- macOS shortcuts have been fixed, only Command is needed again instead of Command + Control.
- Fixed a bug where the selection got stuck to the canvas boundaries when they were 1px away from them.
- The export status of a project no longer resets when saving it as a pxo.
- Fixed a rare issue where the splash screen never appears and the program is unresponsive.
- Canvas texture updating has been slightly optimized. [#661](https://github.com/Orama-Interactive/Pixelorama/pull/661)

### Removed
- The Panel Layout menu option with Widescreen and Tallscreen panel layouts have been removed in favor of the new UI system.

## [v0.9.2] - 2022-01-21
This update has been brought to you by the contributions of:
Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), Darshan Phaldesai ([@luiq54](https://github.com/luiq54)), [@mrtripie](https://github.com/mrtripie)

### Added
- Added an option in the preferences that toggles confirmation while quitting. This has no effect if there are unsaved changes in any of the projects, the confirmation will always appear in that case.

### Changed
- The spritesheet importing as layer workflow has been improved. [#623](https://github.com/Orama-Interactive/Pixelorama/pull/623)
- The duration of a frame also gets copied when that frame is being cloned.
- The user can no longer delete the content of a cel that belongs to a locked or invisible layer.
- Window transparency has been re-enabled in macOS.
- Guides are a little easier to select and drag now.
- The monochromatic palette has been changed.

### Fixed
- Massively improved memory management by fixing a memory leak. Previously, every time the user made a change, memory kept going up and never coming down. Now, data that can never be recovered, like undo data that have been rewritten in history, are also removed from memory. [4832690](https://github.com/Orama-Interactive/Pixelorama/commit/48326900d9d9f0b32fd435e56fd5a39bbf13fa36)
- Fixed application being unresponsive if the user draws outside of the canvas, or on a locked or invisible layer.
- Fixed issue with some of the image effects unintentionally affecting the colors of the image. [#625](https://github.com/Orama-Interactive/Pixelorama/pull/625)
- The mirroring guides now automatically get centered when opening a project. [#626](https://github.com/Orama-Interactive/Pixelorama/issues/626)
- While quitting, the confirmation dialog now detects if there are unsaved changes in any of the projects.
- While drawing with the pencil tool, the transparency of the colors will not blend if overwrite is set to false until the mouse button is released.
- The user can no longer draw in cels that belong to locked/invisible layers.

## [v0.9.1] - 2021-12-20
This update has been brought to you by the contributions of:
Laurenz Reinthaler ([@Schweini07](https://github.com/Schweini07)), Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), Marquis Kurt ([@alicerunsonfedora](https://github.com/alicerunsonfedora)), Xenofon Konitsas ([@huskeee](https://github.com/huskeee)), Silent Orb ([@silentorb](https://github.com/silentorb)), Jeremy Behreandt ([@behreajj](https://github.com/behreajj)), [@mrtripie](https://github.com/mrtripie), [@JumpJetAvocado](https://github.com/JumpJetAvocado)

### Added
- Pixelorama is now available on the [Open Store](https://open-store.io/app/pixelorama.orama-interactive) for Ubuntu Touch. [#517](https://github.com/Orama-Interactive/Pixelorama/pull/517)
- A new ARM32 build for the Raspberry Pi 4 is now available! [#598](https://github.com/Orama-Interactive/Pixelorama/pull/598)
- It is now possible to hold <kbd>Control</kbd> to quickly change a tool's mode. [#429](https://github.com/Orama-Interactive/Pixelorama/discussions/429)
- Holding <kbd>Alt</kbd> while having a draw tool selected now works as a color picker. [#125](https://github.com/Orama-Interactive/Pixelorama/issues/125)
- Added an opacity option in the Eraser's tool options, which lets the user change the strength of the tool.
- You can now rotate the canvas non-destructively. [#558](https://github.com/Orama-Interactive/Pixelorama/pull/558)
- A timer has been added in the HSV and Rotation image effect dialogs that let the user change the delay between the preview refresh, in order to prevent performance issues. [#531](https://github.com/Orama-Interactive/Pixelorama/pull/531)
- The zoom tool behavior has been enhanced, clicking and dragging to the left now zooms out, and clicking and dragging to the right zooms in. [#540](https://github.com/Orama-Interactive/Pixelorama/discussions/540)
- New left and right arrows on the splash screen to switch between the different artworks. [#538](https://github.com/Orama-Interactive/Pixelorama/pull/538)
- New setting in the Preferences that lets the user change the idle FPS. [#543](https://github.com/Orama-Interactive/Pixelorama/pull/543)
- Added a README file for the macOS version that provides more information regarding the Gatekeeper. [#545](https://github.com/Orama-Interactive/Pixelorama/pull/545)
- Added an "Open Logs Folder" option in the Help menu. [#546](https://github.com/Orama-Interactive/Pixelorama/pull/546)
- Options to place the onion skinning previews above or below the canvas are now available. [#600](https://github.com/Orama-Interactive/Pixelorama/pull/600)
- Added a clipboard pattern button. This lets the users fill patterns taken from the application's clipboard (copying selected content).

### Changed
- Flipping the image's selected content now works as expected. The selection gets flipped with the content as well.
- Cache Save/Open Sprite Dialog's directory, and keep dialogs synced. [#559](https://github.com/Orama-Interactive/Pixelorama/pull/559)
- The color pickers now display the previous color and allow selecting it back - because of the update to Godot 3.4.
- The desaturation effect now uses luminance. [#557](https://github.com/Orama-Interactive/Pixelorama/pull/557)
- A random color now appears when creating a new animation tag, along with other various improvements and fixes. [#560](https://github.com/Orama-Interactive/Pixelorama/pull/560)
- The guides now become transparent when they out of canvas bounds, along with other various improvements and fixes. [#561](https://github.com/Orama-Interactive/Pixelorama/pull/561)
- Moved window opacity settings to a dedicated dialog with a slider and a spinbox.
- The fill color of a projects now only gets applied to the cels of the bottom-most layer.
- The step of the UI scale slider has been changed to 0.25 from 0.1.
- "New Brush" in the Edit menu is now disabled when there is no active selection.
- The application now pauses when it loses focus instead of limiting its FPS. Of course, this behavior remains toggleable by the user.
- The undo/redo notification text for selection has been renamed to "Select" from "Rectangle Select".

### Fixed
- The "Pixelorama.app is damaged" error in macOS should no longer appear. macOS builds are now ad-hoc signed. [#602](https://github.com/Orama-Interactive/Pixelorama/pull/602)
- Removing a project tab that is on the left of the currently active tab will no longer result in a crash when attempting to save.
- Merging layers with less than 100% opacity no longer crashes the application. [#541](https://github.com/Orama-Interactive/Pixelorama/issues/541)
- Fixed crash when drawing and switching tools using shortcuts. [#618](https://github.com/Orama-Interactive/Pixelorama/issues/618)
- Fixed issue with copying and pasting content between projects of different sizes.
- Project data no longer remain in memory after the user has removed their tab.
- Fixed issues with guides and notifications not working properly when the UI is scaled.
- A bug was fixed where when the user has another application as their focus and reenters Pixelorama with the mouse but not focusing it and then exiting with the mouse, the target FPS would be set to the standard. [#543](https://github.com/Orama-Interactive/Pixelorama/pull/543)
- Fixed issue with the backup confirmation dialog extending horizontally infinitely, which made the buttons disappear. Its text has also been changed.
- Fixed unexpected behavior which occurred while undoing in the middle of drawing. [#603](https://github.com/Orama-Interactive/Pixelorama/pull/603)
- Pressing X on the backup confirmation dialog should start the backup autosave timer.
- The "Brush color from" tool option no longer appears in the Eraser and Shading tool's options.
- Fixed Alt-Tab causing the cursor to get stuck. [#552](https://github.com/Orama-Interactive/Pixelorama/issues/552)
- Some optimizations have been made, which should result in Pixelorama opening a bit faster, and input event handling is also using less CPU usage.
- Fixed project not having the correct size if the default image size has been changed in the Preferences.
- Fix issue where the timeline would be unresponsive if zen mode was toggled off and on.

## [v0.9] - 2021-09-18
This update has been brought to you by the contributions of:

Kawan Weege ([@DragonOfWar](https://github.com/DragonOfWar)), Martin Novák ([@novhack](https://github.com/novhack)), Fayez Akhtar ([@Variable-ind](https://github.com/Variable-ind)), Darshan Phaldesai ([@luiq54](https://github.com/luiq54)), Xenofon Konitsas ([@huskeee](https://github.com/huskeee)), Igor Santarek ([@jegor377](https://github.com/jegor377)), Álex Román Núñez ([@EIREXE](https://github.com/EIREXE)), [@mrtripie](https://github.com/mrtripie)

### Added
- A total of 9 new tools!
- New selection tools, including elliptical, magic wand, select by color, lasso (freehand selection) and polygonal selection tools.
- A new move tool, that lets you move the content of the current cel, or the content of the selection, if there is any.
- New rectangle and ellipse shape tools. [#456](https://github.com/Orama-Interactive/Pixelorama/pull/456)
- A new line tool.
- An installer for Windows will be available for v0.9 and future versions! [#486](https://github.com/Orama-Interactive/Pixelorama/pull/486)
- You can now select multiple cels in the timeline and edit them all at once!
- Frame numbers in the timeline above the cels are now clickable buttons that can be dragged and dropped to re-arrange the frames. Right clicking on these buttons brings up a frame-related menu with options that used to be on the cel right click menu.
- You can now right click a cel to delete its contents.
- Layer dragging and dropping is now also possible.
- A new "fill inside" option has been added in the Pencil tool options. [#489](https://github.com/Orama-Interactive/Pixelorama/pull/489), based off [#459](https://github.com/Orama-Interactive/Pixelorama/pull/459)
- You can now name the project name on the "create new project" dialog. [#490](https://github.com/Orama-Interactive/Pixelorama/pull/490)
- A tool button size option has been added in the Preferences. This lets you choose between small or big tool button sizes.
- Added a "Licenses" tab in the About menu, which displays Pixelorama's license as well as the software it depends on, such as Godot.
- Added Norwegian Bokmål and Ukrainian translations.

### Changed
- The selection system has been completely changed and has become a lot more powerful. See [#129](https://github.com/Orama-Interactive/Pixelorama/issues/129#issuecomment-756799706) for more details.
- The palette system has been completely replaced with a new one. See [#447](https://github.com/Orama-Interactive/Pixelorama/pull/447) for more details.
- UI icons have been changed to single-color "symbolic" textures. This removes the need for multiple graphics for each theme type as these new textures can change their modulation on runtime.
- Image color inverting, desaturation and HSV adjusting are now shader based. This improves the performance of these image effects and prevents crashes on large images. [#475](https://github.com/Orama-Interactive/Pixelorama/pull/475)
- The lighten/darken tool has been renamed to Shading tool.
- Brushes now work with the Shading tool.
- You now have to double click a layer button to rename a layer. Clicking it once just selects the layer.
- Pixelorama's icon has been changed - proposed by creepertron95.
- The color picker tool now works on the surrounding tiles when tile mode is enabled. [#506](https://github.com/Orama-Interactive/Pixelorama/issues/506)
- The toolbar on the left can now be resized by the user.
- The frame delay minimum value is now 0.01 instead of 0.
- Cloning frames now create linked cels on layers where the cel linking button is enabled.
- Window transparency has been temporarily disabled in macOS due to [#491](https://github.com/Orama-Interactive/Pixelorama/issues/491).
- The close button on tabs is always being displayed, which lets the user close projects other than the current one.

### Fixed
- Issues such as not being able to create guides at random times, which are a result of PoolVectorArray locking issues, may have finally been solved. [#331](https://github.com/Orama-Interactive/Pixelorama/issues/331)
- Cropping large images no longer crash the application.
- Zen mode now hides the animation timeline again. [#478](https://github.com/Orama-Interactive/Pixelorama/pull/478)
- Pixelorama should no longer crash when loading a project and the symmetry axes fail to load. They will still fail to load, but the app will no longer crash. [e8b36bbc61154641ce9eec1f0a845a0061d3585d](https://github.com/Orama-Interactive/Pixelorama/commit/e8b36bbc61154641ce9eec1f0a845a0061d3585d)
- Fixed gif exporting stuck on 0% on large projects. [#488](https://github.com/Orama-Interactive/Pixelorama/pull/488)
- Cropping images should now work as expected. Before, there were times when it did not crop the image at the correct size.
- Fixed a rare division by zero crash when changing the display scale under Preferences.
- Changed pixel grid shortcut on macOS because it conflicted with a system hotkey. [#494](https://github.com/Orama-Interactive/Pixelorama/pull/494)
- The shading tool now has correct Hue, Saturation and Value changes, as well as some other tweaks, like limiting the darkening hue to 240 instead of 270. [#519](https://github.com/Orama-Interactive/Pixelorama/pull/519) and [#522](https://github.com/Orama-Interactive/Pixelorama/pull/522)
- The disabled buttons on the light theme are no longer invisible. [#518](https://github.com/Orama-Interactive/Pixelorama/issues/518)
- Fix the canvas preview having incorrect zoom when switching between projects.
<br><br>

## [v0.8.3] - 2021-05-04
This update has been brought to you by the contributions of:

Laurenz Reinthaler (Schweini07), kleonc, Fayez Akhtar (Variable), THWLF, Gamespleasure, ballerburg9005, kevinms

### Added
- A new pan tool, used to move around the canvas. ([#399](https://github.com/Orama-Interactive/Pixelorama/pull/399))
- Dragging and dropping individual cels in the timeline to change their position is now possible.
- You can now resize cels in the timeline by holding `Control` and scrolling with the mouse wheel.
- Added a new "Performance" tab in the Preferences that exposes options related to the application's FPS to the user.
- You can now change the transparency of the application's window, allowing for easier tracing/rotoscoping. (Does not work on the Web version) ([#444](https://github.com/Orama-Interactive/Pixelorama/pull/444))
- Added a new pixel grid, which is a grid of size 1px and it appears after a certain zoom level. ([#427](https://github.com/Orama-Interactive/Pixelorama/pull/427))
- Added offset options to the grid. ([#434](https://github.com/Orama-Interactive/Pixelorama/pull/434))
- The isometric grid has been refactored to work better and to offer more changeable options, such as the width and height of the cell bounds. ([#430](https://github.com/Orama-Interactive/Pixelorama/pull/430))
- Pixelorama macOS binaries are now universal, which means that they should work with both x86_64 and ARM64 Mac devices. - Thanks to Godot 3.3
- Added portrait and landscape buttons in the new image dialog.
- Full support for auto Tallscreen/Widescreen has been implemented. ([#458](https://github.com/Orama-Interactive/Pixelorama/pull/458))
- Added a new Centralize Image option in the Image menu, which places the visible pixels of the image in the center of the canvas. ([#441](https://github.com/Orama-Interactive/Pixelorama/pull/441))
- Implemented the options to import a spritesheet as a new layer and to import an image and have it replace an already existing frame. ([#453](https://github.com/Orama-Interactive/Pixelorama/pull/453))
- More templates have been added when creating a new sprite. ([#450](https://github.com/Orama-Interactive/Pixelorama/pull/450))
- Added a keyboard shortcut for clear selection, `Control-D`. ([#457](https://github.com/Orama-Interactive/Pixelorama/pull/457))
- Added an option in the Preferences for interface dimming on dialog popup. If this is enabled, the application background gets darker when a dialog window pops up.

### Changed
- Undo and redo now work when their respective keyboard shortcuts are being held. ([#405](https://github.com/Orama-Interactive/Pixelorama/pull/405))
- CPU usage has been significantly been lowered when Pixelorama is idle. ([#394](https://github.com/Orama-Interactive/Pixelorama/pull/394))
- The FPS of the project animation is now stored in the pxo file. This effectively means that every project can have its own FPS.
- You can no longer draw on hidden layers.
- You can now toggle if you want the grid to be drawn over the tile mode or just the original part of the canvas. ([#434](https://github.com/Orama-Interactive/Pixelorama/pull/434))
- Frame tags can now be set for frames larger than 100. ([#408](https://github.com/Orama-Interactive/Pixelorama/pull/408))
- The "lock aspect ratio" button in the create new image dialog has been changed to a texture button.
- Improved the "Scale Image" dialog. It now automatically sets the size to the current project's size, has a button to lock aspect ratio, and resizing based on percentage.
- Having no active selection no longer treats all the pixels of the canvas as selected. This is also a performance boost, especially for larger images, as Pixelorama no longer has to loop through all of the pixels to select them.
- Tile mode rects are now cached for a little speedup. ([#443](https://github.com/Orama-Interactive/Pixelorama/pull/443))
- The zoom tool now works on the second canvas too.

### Fixed
- Fixed issue with pixels being selected outside of the canvas boundaries, when the selection rectangle was outside the canvas and its size got reduced.
- Major performance increase when drawing large images.
- Fixed layer button textures not being updated properly when changing theme. ([#404](https://github.com/Orama-Interactive/Pixelorama/issues/404))
- Keyboard shortcut conflicts between tool shortcuts and other shortcuts that use the "Control" key, like menu shortcuts, have been resolved. ([#407](https://github.com/Orama-Interactive/Pixelorama/pull/407))
- The opacity of a cel and the tile mode opacity are now multiplicative. ([#414](https://github.com/Orama-Interactive/Pixelorama/pull/414))
- Fixed an issue where adding a new layer did not select it, rather it was selecting the above layer of the previously selected layer. ([#424](https://github.com/Orama-Interactive/Pixelorama/pull/424))
- Fixed issue that occurred when the application window regained focus and the tool was immediately activated. ([35f97eb](https://github.com/Orama-Interactive/Pixelorama/commit/35f97ebe6f90bd2a5994b294231738ef4a6b998c))
- Fixed cel opacity not always being updated on the UI. ([#420](https://github.com/Orama-Interactive/Pixelorama/pull/420))
- Loading empty backed up projects no longer result in a crash. ([#445](https://github.com/Orama-Interactive/Pixelorama/issues/445))
- Fixed potential index out of bounds error when loading backup files. ([#446](https://github.com/Orama-Interactive/Pixelorama/pull/446))
- Mirroring view should now work on all tools.
- Fixed hue and saturation getting reset when dragging value slider to zero. ([#473](https://github.com/Orama-Interactive/Pixelorama/pull/473))
- Image effects will not longer get applied to locked and/or hidden layers.
- Fixed memory leaks when opening and closing Pixelorama. ([#387](https://github.com/Orama-Interactive/Pixelorama/issues/387))
- The color picker now displays "HSV" and "Raw" next to the respective CheckButtons - thanks to Godot 3.3.
<br><br>

## [v0.8.2] - 2020-12-12
This update has been brought to you by the contributions of:

PinyaColada, Rémi Verschelde (akien-mga), dasimonde, gschwind, AbhinavKDev, Laurenz Reinthaler (Schweini07)

### Added
- The lighten/darken tool now has a hue shifting mode. It lets users configure the shift in hue, saturation and value of the new shaded pixels. ([#189](https://github.com/Orama-Interactive/Pixelorama/issues/189))
- Added a "frame properties" option on the popup menu that appears when right-clicking on a cel. This lets the user choose a custom frame delay for that specific frame. ([#357](https://github.com/Orama-Interactive/Pixelorama/pull/357))
- You can now select if you want rotation to apply in the selection, the current cel, the entire frame, all frames or even all projects (tabs)!
- You can now change the transparency of the Tile Mode in the Preferences. ([#368](https://github.com/Orama-Interactive/Pixelorama/pull/368))
- Added a "Recent Projects" option in the File menu, to contain the most recently opened projects. ([#370](https://github.com/Orama-Interactive/Pixelorama/pull/370))
- HiDPI support - Pixelorama's UI can now be scaled in the Preferences. ([#140](https://github.com/Orama-Interactive/Pixelorama/issues/140))
- More options have been added to Tile mode; Tile only in X Axis, Y Axis or both Axis. ([#378](https://github.com/Orama-Interactive/Pixelorama/pull/378))
- Added a "Mirror View" option in the View menu, which is used to flip the canvas horizontally and non-destructively. ([#227](https://github.com/Orama-Interactive/Pixelorama/issues/227))
- macOS: It is now possible to pan and zoom the canvas from a touchpad. ([#391](https://github.com/Orama-Interactive/Pixelorama/pull/391))
- Added Turkish and Japanese translations.

### Changed
- `~` is now used as a random brush prefix instead of `%`. ([#362](https://github.com/Orama-Interactive/Pixelorama/pull/362))
- The default path of the dialogs for opening and saving is now the user's desktop folder.
- When there are errors in opening and saving files, the errors appear in the form of a popup dialog, instead of a notification or an OS alert.
- The CJK font (for Chinese & Korean) was changed to DroidSansFallback from NotoSansCJKtc. This results in a much smaller exported `.pck` (over 10MB less!)
- Onion skinned previous and next frames are now being drawn on top of the current frame. This fixes issues where onion skinning would not work with an opaque background.
- In onion skinning, you can now set the past and future steps to 0. ([#380](https://github.com/Orama-Interactive/Pixelorama/pull/380))
- Tile mode is now project-specific. ([#388](https://github.com/Orama-Interactive/Pixelorama/pull/388))
- macOS: Shortcuts with the Control keyboard button have now been changed to use "Command" instead. ([#393](https://github.com/Orama-Interactive/Pixelorama/pull/393))

### Fixed
- Made .pxo saving safer. In case of a crash while parsing JSON data, the old .pxo file, if it exists, will no longer be overwritten and corrupted.
- Fixed issue where the user could grab and could not let go of the focus of guides even when they were invisible.
- Fixed issues where fully transparent color could not be picked. One of these cases was [#364](https://github.com/Orama-Interactive/Pixelorama/issues/364).
- Fixed "Export" option in the File menu not working properly and not remembering the directory path and file name when switching between projects (tabs).
- When opening a .pxo project which has guides, they will no longer be added to the project at the first tab too.
- Symmetry guides now adjust their position when the image is being resized. ([#379](https://github.com/Orama-Interactive/Pixelorama/issues/379))
- Fixed various issues with the transparent background checker size. ([#377](https://github.com/Orama-Interactive/Pixelorama/issues/377))
- Fixed Chinese and Korean characters not being displayed properly in the Splash dialog and the About dialog.
- Fixed crash when importing an incorrectly formatted GIMP Color Palette file. ([#363](https://github.com/Orama-Interactive/Pixelorama/issues/363))
- Using the lighten/darken tool on pixels with an alpha value of 0 no longer has an effect on them.
- Fixed freeze when switching to a project of a larger size and using an image effect, with the affected parts being set to something different that "Current cel".
<br><br>

## [v0.8.1] - 2020-10-14
This update has been brought to you by the contributions of:

Laurenz Reinthaler (Schweini07), PinyaColada

### Added
- Buttons for moving the current frame left or right. ([#344](https://github.com/Orama-Interactive/Pixelorama/pull/344))
- Creating palettes from sprites has been enhanced - you can now choose if you want to get colors from the selection, current cel, entire frame or all frames, and if you want the colors to have an alpha component.
- A new "Cut" option in the Edit menu or by pressing `Ctrl-X`. It cuts (deletes & copies) the selection, and you can later paste it. ([#345](https://github.com/Orama-Interactive/Pixelorama/pull/345))
- Added a warning dialog when clicking the remove palette button, to prevent accidental palette deletions.
- A new purple theme.

### Changed
- Guides now move with a step of 0.5 pixels. That makes it possible to have guides (and symmetry guides) to be in the middle of pixels.
- Changed how Dark, Gray, Caramel and Light themes look. All theme elements now have the same spacing and margins.

### Fixed
- Most likely fixed an issue that occurred when the user attempted to export the project, which failed due to a locking error (error code 23). (Part of [#331](https://github.com/Orama-Interactive/Pixelorama/issues/3391))
- Fixed crash where Pixelorama could not load a cached sub-resource. ([#339](https://github.com/Orama-Interactive/Pixelorama/issues/339))
- When moving tabs, the projects now move along with their respective tabs.
- Fixed crash where the animation was playing in the mini canvas preview and then the user switched to a project with less frames.
- Fixed issue with the selection rectangle, where if it was being moved while using paste or delete, it went back to its original position. ([#346](https://github.com/Orama-Interactive/Pixelorama/pull/346))
<br><br>

## [v0.8] - 2020-09-23
This update has been brought to you by the contributions of:

Darshan Phaldesai (luiq54), Igor Santarek (jegor377), rob-a-bolton, Kinwailo, Michael Alexsander (YeldhamDev), Hugo Locurcio (Calinou), Martin Novák (novhack), Xenofon Konitsas (huskeee), Matthew Paul (matthewpaul-us)

### Added
- The Web (HTML5) is now a supported platform of Pixelorama! It is now possible to save .png and .pxo files, as well as load image and palette files in the Web version. Made possible thanks to https://github.com/Pukkah/HTML5-File-Exchange-for-Godot
- Windows, Linux, macOS and Web builds are now automatically generated every time a commit is pushed to master by GitHub Actions.
- Project tabs! You can now have multiple projects open at the same time, and access each one with tabs. 
- Gradient generation. A new option under the "Image" menu that lets you generate a RGB gradient.
- The dialog windows of most image effects have been improved. You can now select if you want the effect to apply in the selection, the current cel, the entire frame, all frames or even all projects (tabs)!
- Added previews in all image effect dialog windows with a checkerboard background. Also placed checkerboard backgrounds in the cel buttons of the timeline, and the Export window. ([#206](https://github.com/Orama-Interactive/Pixelorama/issues/206))
- A new isometric grid!
- Ability to remove the current palette. ([#239](https://github.com/Orama-Interactive/Pixelorama/pull/239))
- You can now drag & drop files into the program while it's running to open them. You can open .pxo files, image files and palette (json, gpl and pal) files this way.
- You can now draw on the tiling mode previews! ([#65](https://github.com/Orama-Interactive/Pixelorama/issues/65))
- Added Resize Canvas option to Image menu.
- Added Symmetry Guides. They let you change the axis of symmetry for mirroring. ([#133](https://github.com/Orama-Interactive/Pixelorama/issues/133))
- Palettes can now be created from the colors of the selected sprite.
- You can now preview how the frames of the spritesheet you are importing will look.
- You can now import image files as layers. Their size will be cropped to the project's size.
- You can import image files as brushes, patterns and palettes.
- Buttons have been added in Preferences to restore each setting to its default state.
- Created a NSIS installer for Windows. ([#303](https://github.com/Orama-Interactive/Pixelorama/pull/303))
- Added Scale3X algorithm as an option to scale sprites ([#290](https://github.com/Orama-Interactive/Pixelorama/pull/290))
- Added "Copy", "Paste" and "Delete" options in the Edit menu. ([#281](https://github.com/Orama-Interactive/Pixelorama/pull/281))
- Selection region and size are now being shown when making a selection on the top, next to the position label. ([#281](https://github.com/Orama-Interactive/Pixelorama/pull/281))
- Added color overwrite option for the Pencil tool. ([#282](https://github.com/Orama-Interactive/Pixelorama/pull/282))
- Flip, desaturation and invert colors now have dialogs with previews and extra options. You can now choose individual color channels to invert, including alpha.
- A play button has been added for playing the animation exclusively on the small canvas preview area. A zoom slider for the preview area has been added, too.
- Added color previews next to the themes in Preferences.
- Added options for the checkerboard background to follow camera movement and zoom level. ([#311](https://github.com/Orama-Interactive/Pixelorama/pull/311))
- Added support for importing PAL palette files. ([#315](https://github.com/Orama-Interactive/Pixelorama/pull/315))
- Added Hungarian, Korean and Romanian translations.

### Changed
- The GDNative gif exporter addon has been replaced with a GDScript equivalent. This makes gif exporting possible in all currently supported platforms, and it also adds support for transparency. ([#295](https://github.com/Orama-Interactive/Pixelorama/pull/295))
- Drawing is no longer limited by the canvas boundaries. This means that, if you have a brush largen than 1px, you can draw on the edges of the canvas. All pixels that are being drawn outside of the canvas will still have no effect.
- The guides are now the same for all frames.
- Imported frames are now being cropped to the project's size. It is no longer possible to have multiple sizes for each frame at all in the same project.
- Pixel perfect is no longer enabled when the brush size is bigger than 1px.
- The .pxo file structure has been changed. It's now consisted of a JSON-structured metadata part, where all the data that can be stored as text are, and a binary part, that contain all the actual image data for each cel and project brush.
- You can now choose if you want your .pxo to use ZSTD compression or not.
- To make a straight line, you now have to hold Shift while dragging (moving and pressing) your mouse. Releasing your mouse button makes the line. ([#281](https://github.com/Orama-Interactive/Pixelorama/pull/281))
- When making a straight line, a preview of how the line's pixels will look is now being shown. ([#260](https://github.com/Orama-Interactive/Pixelorama/pull/260))
- Drawing lines with Ctrl are now constrained at 1:1 and 1:2 ([#201](https://github.com/Orama-Interactive/Pixelorama/issues/201))
- Pixelorama now remembers the selected colors, tools and their options when it's closed and re-opened. ([#281](https://github.com/Orama-Interactive/Pixelorama/pull/281))
- The "pixelorama" folder, which contains data like Brushes, Patterns and Palettes has been renamed to "pixelorama_data" for all non-XDG directory paths.
- Mac builds will now have the execute permission by default, and they will be in `.dmg` form. ([#319](https://github.com/Orama-Interactive/Pixelorama/pull/319))
- Linux builds will also have the execute permission by default, and will be compressed as `tar.gz` instead of `.zip`.
- Drawing brushes with mirror also mirrors the images of the brushes themselves. ([#281](https://github.com/Orama-Interactive/Pixelorama/pull/281))
- When making a new palette or importing one and its name already exists, Pixelorama will add a number to its name. For example, "Palette_Name" would become "Palette_Name (2)", "Palette_Name (3)", etc.
- Re-organized preferences dialog.
- The "create new image" dialog now remembers the last created canvas size. The default image settings are being used only when Pixelorama first launches. ([#178](https://github.com/Orama-Interactive/Pixelorama/issues/178))
- Language and theme checkboxes are now radio buttons.
- The Blue theme has more similar margins and separations with the rest of the themes.
- Fullscreen can be toggled on and off from the View menu.
- Multi-threaded rendering has been enabled. ([#294](https://github.com/Orama-Interactive/Pixelorama/pull/294))
- Use the Dummy audio driver since Pixelorama doesn't play any sounds. ([#312](https://github.com/Orama-Interactive/Pixelorama/pull/312))

### Fixed
- Exporting large images and drawing with large image brushes is now a lot faster. (Because of Godot 3.2.2)
- Pixel perfect strokes no longer leave gaps when the mouse is moving fast. ([#281](https://github.com/Orama-Interactive/Pixelorama/pull/281))
- Fixed failed imports of gpl palettes by adding support for the newer variant of gpl files. ([#250](https://github.com/Orama-Interactive/Pixelorama/pull/250))
- Fixed alpha blending and lighting/darkening issues when drawing pixels with mirroring.
- Fixed issue where if you moved a frame to the start (move left), it was invisible.
- Fixed a rare issue with Undo/Redo not working while motion-drawing and making lines.
- Grid and guides are now longer being displayed on previews. ([#205](https://github.com/Orama-Interactive/Pixelorama/issues/205))
- Fixed a rare problem where the custom mouse cursor's image was failing to load.
- Importing corrupted image files and non-palette json files no longer crash the app.
- Drawing brushes no longer have clipping issues. ([#281](https://github.com/Orama-Interactive/Pixelorama/pull/281))
- When undoing a removal of a brush, the brush index is no longer incorrect. ([#281](https://github.com/Orama-Interactive/Pixelorama/pull/281))
- Fix out-of-bounds error when color picking outside the image. ([#291](https://github.com/Orama-Interactive/Pixelorama/pull/291))
- When a color is being selected from a palette, the outline of the color's button no longer disappears when drawing. ([#329](https://github.com/Orama-Interactive/Pixelorama/pull/329))

### Removed
- The "Import" option from the file menu has been removed, users can now import image files from "Open".
<br><br>

## [v0.7] - 2020-05-16
This update has been brought to you by the contributions of:

Martin Novák (novhack), Darshan Phaldesai (luiq54), Schweini07, Marco Galli (Gaarco), Matheus Pesegoginski (MatheusPese),
sapient-cogbag, Kinwailo, Igor Santarek (jegor377), Dávid Gábor BODOR (dragonfi), John Jerome Romero (Wishdream)

### Added
- Cels are now in the timeline. Each cel refers to a specific layer AND a frame. Frames are a collection of cels for every layer.
- Cel linking is now possible. This way, layers can be "shared" in multiple frames.
- You can now group multiple frames with tags.
- You can now export your projects to `.gif` files.
- A new rotation method has been added, "Upscale, Rotate and Downscale". It's similar to Rotsprite.
- An HSV Adjust dialog has been added in the Images menu.
- Pattern filling is now possible. The bucket tool can now use Patterns to fill areas, instead of a single color.
- An autosave feature that keeps backups of unsaved projects have been added. In the case of a software crash, the users can restore their work with this system.
- Users can now change keyboard shortcut bindings for tools, in the Preferences.
- Pixel Perfect mode has been added for pencil, eraser and lighten/darken tools.
- Importing `.pngs` as palettes is now possible.
- A confirmation message now appears when the user quits Pixelorama, if there are unsaved changes.
- The last edited project gets loaded at startup (toggleable in the Preferences), along with a new option in the File menu that also does this.
- Templates and a lock aspect ratio option have been added to the "Create new image" dialog.
- Locking layers is now possible. When a layer is locked, no changes can be made to it. Layers are unlocked by default.
- Ability to get color for palette buttons, when editing a palette, from the currently selected left and right colors.
- Esperanto, Indonesian & Czech translation.
- When the image is unsaved and the user tries to make a new one, a new warning dialog will appear to ask for confirmation.
- A new zoom tool has been added, and you can also zoom in with the `+` key, and zoom out with `-`.
- You can now move the canvas with the `Arrow keys`. `Shift + Arrows` make it move with medium speed, and `Ctrl + Shift + Arrows` makes it move with high speed.
- The left and right tool icon options (found in Preferences) are now saved and restored on startup.

### Changed
- The UI - and especially the timeline - has been revamped!
- The export dialog has also been revamped.
- An asterisk is added to the window title if there are unsaved changes.
- A VSplitContainer has been added between the canvas and the timeline.
- The texture of the transparent checker background is now no longer affected by the zoom value. The users can now also change the texture's colors and the size.
- Notification text is now black on the gold and light themes.
- Layer's LineEdit now saves the changes when it loses focus, or when the user presses ESC (or Enter).
- LineEdits lose focus when the user presses Enter.
- When cloning a frame, the clone will appear next to the original.
- Scale image and crop image now affect all frames.
- Layer visibility is taken into account when exporting the drawing as a `.png` file. This means that invisible layers will not be included in the final `.png` file.
- The Godot theme has changed and been renamed to Blue. The Gold theme has also been renamed to Caramel.
- When a dialog is opened, the UI in the background gets darker.
- Visual change, added border outlines to all window dialogs.
- Animation now loops by default.
- Onion skinning settings have been moved to a popup window, and 2 new buttons were added. One that toggles onion skinning, and one that opens the settings window.
- The default window size is now 1280x720, and the minimum window size is 1024x576.
- `.pxo` files now use ZSTD compression to result in smaller file sizes.
- Palettes/Brushes get loaded/saved in appropriate locations as specified by the XDG basedir standard, for easier usage of standard Linux/BSD packaging methods and for better per-user usability.
- The splash screen has been revamped and is no longer purple, it now gets affected by the chosen theme.
- The brush selection popup now closes when a brush is selected.
- Pixelorama's version number now appears on the window title.
- Images now get zoomed properly (fit to canvas frame) when they are first created or loaded.

### Fixed
- Chinese characters not being rendered in notifications (the labels that appear when undoing/redoing) and at the splash screen for Platinum & Gold Sponsor Placeholder labels
- Fixed issue when moving frames, the current frame was being shown but the frame next to it was actually the one being drawn on.
- Fixed issue with LineEdits not letting go of focus when the user clicked somewhere else. (Issue #167)
- When the palette, outline and rotate image dialogs are open, the user can't zoom in the canvas anymore.
- Fixed bug where the user could drag the selection and the guides when the canvas had no focus.
- The zoom label on the top bar now shows the correct zoom value when smooth zoom is enabled.
- Fixed issue with Space triggering the event of the last pressed button. This caused unwanted behavior when using Space to move the canvas around. Resolved by changing the focus mode of the buttons to None.

### Removed
- It's no longer possible for frames to have different amounts of layers. All frames have the same amount.
- The guides no longer work with undo/redo.
<br><br>

## [v0.6.2] - 2020-02-17

### Added
- Image layer rotation! Choose between 2 rotation algorithms, Rotxel and Nearest Neighbour - Thanks to azagaya!
- Crowdin integration for contributing translations!
- Spanish translation - thanks to azagaya & Lilly And!
- Chinese Simplified translation - thanks to Chenxu Wang!
- Latvian translation - thanks to Agnis Aldiņš (NeZvers)!
- Translators can now be seen in the About window.
- It is now possible to remove custom brushes with the middle mouse button.
- Added HSV mode to the color picker. (Added automatically because of the Godot 3.2 update)
- Lanczos scaling interpolation. (Added because of the Godot 3.2 update)
- You can now drag and drop (or right click and open with) image and .pxo files in Pixelorama.
- You can now hide the animation timeline - Thanks to YeldhamDev!

### Changed
- Major changes to alpha blending behavior. The alpha values now get added/blended together instead of just replacing the pixel with the new value.
- Replaced some OS alerts with a custom made error dialog.
- Made the zooming smoother, is toggleable in Preferences whether to keep the new zooming or the old one.
- The camera now zooms at the mouse's position.
- Made the "X" button on the custom brushes a little smaller.
- The color picker will now have a small white triangle on the top left of the color preview if at least one of its RGB values are above 1 in Raw mode. (Added automatically because of the Godot 3.2 update)
- You can now toggle the visibility of hidden items on and off in the file dialogs. (Added automatically because of the Godot 3.2 update)
- The language buttons in the preferences have their localized names in their hint tooltips. For example, if you hover over the "English" button while the language is Greek, the hint tooltip will be "Αγγλικά", which is the Greek word for English.
- Translation updates.
- The presets in the ColorPickers are now hidden - Thanks to YeldhamDev!
- When opening a project (.pxo file), the save path is being set to the opened project's path - Thanks to YeldhamDev!

### Fixed
- Delay the splash screen popup so it shows properly centered - Thanks to YeldhamDev!
- Possibly fixed crashes with motion drawing and undo/redoing.
- Fixed bug (which also caused crashes sometimes) when generating an outline inside the image and it was going outside the canvas' borders.
- Fixed crash when importing images that were failing to load. They still fail to load, but Pixelorama does not crash.
- Possibly fixed a rare crash where the cursor image was failing to load. It is now being loaded only once.
- Fixed ruler markings cutting off before they should - Thanks to YeldhamDev!
- Fixed bug where resizing the image on export and moving selection content were not working on Godot 3.2 - Issues #161 and #162
<br><br>

## [v0.6.1] - 2020-01-13

### Added
- Italian translation - thanks to Gaarco!
- In addition to the middle mouse button, you can now use `Space` to pan around the canvas.
- The ability to choose for which color the color picker does its job, the left or the right. (Issue #115)
- Default image settings are now in the Preferences - thanks to Gaarco!
- Added option to hide tool icons next to the cursor - thanks to haonkrub (Issue #122)

### Changed
- When saving a .pxo file, the file path (along with the file name) gets remembered by the Export PNG file dialog path. (Issue #114)
- LightenDarken tool no longer affects transparent pixels.
- More translatable strings, updates to Greek & Brazilian Portuguese (thanks to YeldhamDev) translations.
- The dark theme button is now pressed by default if the user hasn't saved a theme preference in the config file.
- Added a VSplitContainer for the tools and their options, and another one for Palettes and Layers.
- Made minor changes to the UI of tool options, including a ScrollContainer for them.
- Added a ScrollContainer for the palette buttons on the Edit Palette popup.
- Made Palette .json files more readable, and placed "comments" on top of the color data.
- The grid options are now being updated realtime when they're being changed from the preferences, and they are also being saved in the config cache file.

### Fixed
- Fixed crash that occurred when trying to delete contents of a selection, that were outside the canvas.
- Fixed .gpl palettes not being imported correctly - Issue #112
- Fixed crash that occurred when pressing the play buttons on the timeline, on Godot 3.2 - Issue #111
- Fixed bug where, if you had a random brush selected and then selected the pencil tool, "brush color from" did not appear.
- Fixed crash on Godot 3.2.beta6 when pressing the Edit Palette button.
- The canvas updates automatically when onion skinning settings change.
- Fixed a rare crash with straight lines. It was possible that the variable `is_making_line` could be true, even if the line itself has been freed from memory.
- Fixed issue where undo/redo was not working properly for straight lines that went outside the canvas.
<br><br>

## [v0.6] - 2020-01-06

### Added
- Palettes. You can choose default ones or make your own! (Thanks to greusser/CheetoHead - issue #27)
- Multiple theme support (Dark, Gray, Light, Godot, Gold) to better match your style (Thanks to Erevoid)!
- Image menu with new features (Outlines, Color invert, desaturation) for more editing power.
- Added a new splash screen window dialog  that appears when Pixelorama loads. Patrons with the rank of Visionaries and above can participate in splash screen artwork contests for every version! Click here for more info: https://www.patreon.com/OramaInteractive
- Added a better circle and filled circle brushes. They use Bresenham's circle algorithm for scaling.
- Added random brushes! Every time you draw, expect to see something different! To create random brushes, place the images you want your brush to have in the same folder, and put the symbol "%" in front of their filename. Examples, "%icon1.png", "%grass_green.png"
- Pixelorama goes worldwide with even more translations! (German, French, Polish, Brazilian Portuguese, Russian, Traditional Chinese)
- Added a layer opacity slider, that lets you change the alpha values of layers.
- Importing spritesheets is now possible.
- Exporting matrix spritesheets is now possible. You can choose how many rows OR columns your spritesheet will be.
- Straight lines now have constrained angles if you press `Ctrl`. With a step of 15 angles.
- Straight line angles are now being shown on the top bar.
- Guide color can now be changed in Preferences.
- Added sliders next to the spinboxes of brush size, brush color interpolation and LightenDarken's amount.
- Color switch has `X` as its shortcut.
- Frames can now be removed with middle click.
- Selection content can be deleted with the "Delete" button.
- Added "View Splash Screen", "Issue Tracker" and "Changelog" as Help menu options

### Changed
- Straight line improvements - it activates by pressing shift after last draw (Thanks to SbNanduri)
- Changed Preferences window's layout.
- Changed export dialog's options to be more clean and easier to understand.
- Switched from a single .csv to gettext for handling translations.
- The About dialog window got an overhaul. It now shows the names of the Development team, Contributors & Donors.
- Changed default cursor shape for the rulers so the users can see that they are interactive.
- Made the layer and timeline buttons have hover textures. (Thanks to Erevoid)
- Brush color interpolation and LightenDarknen's amount now range from 0-100, instead of 0-1.
- Redo has both `Ctrl-Y` and `Shift-Ctrl-Z` as its shortcuts. (Thanks to Schweini07)
- Removed split screen button, you can now drag the second canvas from the right.
- Changed positions of color switch & color default buttons.
- Importing brushes from the Brushes folder now looks inside its subfolders too, but not the subfolders of the subfolders.
- The Brushes folder now gets created if it doesn't exist (tested on Windows)
- Enabled switching between menus in menu bar on hover (Thanks to YeldhamDev)
- The "View" menu remains visible when toggling items (Thanks to YeldhamDev)
- The UI darkens when exiting the application (Thanks to Calinou)
- The bucket tool's "paint all pixels with the same color" now gets limited to the selection, if there is any.
- If the alpha on the color picker is at 0 and any of the other RGB values change, alpha becomes 1. (Issue #54)

### Fixed
- UndoRedo leak (issue #34) (Thanks to qarmin)
- Enabled low processor usage and reduced the amount of times "update()" gets called on Canvas and the rulers, to improve CPU usage. (Thanks to Calinou & Martin1991zab)
- Fixed alpha in custom brushes, because their alpha was being blended along with its RGB values. (Issue #51)
- Fixed "Parent node is busy setting up children, move_child() failed" when the Quit dialog popup was being called. (Issue #90, thanks to Sslaxx)
- Fixed issues with bucket tool and mirroring.
- Fixed issue with invisible layers becomes visible when a layer was added/removed/moved or changed frame.
- Switched to '2D' framebuffer allocation, which results in slightly increased performance and decreased CPU/GPU usage. (Thanks to Calinou)
