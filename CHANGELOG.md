# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). All the dates are in YYYY-MM-DD format.
<br><br>

## [v0.8.1] - Unreleased
### Added
- A new purple theme.

### Changed
- Guides now move with a step of 0.5 pixels. That makes it possible to have guides (and symmetry guides) to be in the middle of pixels.
- Changed how Dark, Gray, Caramel and Light themes look. All theme elements now have the same spacing and margins.

### Fixed
- Fixed crash where Pixelorama could not load a cached sub-resource - [Issue #339](https://github.com/Orama-Interactive/Pixelorama/issues/339)
- When moving tabs, the projects now move along with their respective tabs.
- Fixed crash where the animation was playing in the mini canvas preview and then the user switched to a project with less frames.
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
- The Blue theme has more similar margins and seperations with the rest of the themes.
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
- Fixed crash that occured when trying to delete contents of a selection, that were outside the canvas.
- Fixed .gpl palettes not being imported correctly - Issue #112
- Fixed crash that occured when pressing the play buttons on the timeline, on Godot 3.2 - Issue #111
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
