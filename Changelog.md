# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [v0.7] - Unreleased
This update has been brought to you by the contributions of:

Martin Novák (novhack), luiq54, Schweini07, Marco Galli (Gaarco), Matheus Pesegoginski (MatheusPese), sapient-cogbag, Kinwailo

### Added
- Cels are now in the timeline. Each cel refers to a specific layer AND a frame. Frames are a collection of cels for every layer.
- Cel linking is now possible. This way, layers can be "shared" in multiple frames.
- You can now group multiple frames with tags.
- You can now export your projects to .gif files.
- A new rotation method has been added, "Upscale, Rotate and Downscale". It's similar to Rotsprite.
- An HSV Adjust dialog has been added in the Images menu.
- Pattern filling is now possible. If the user chooses a brush that is not the pixel or a circle brush and uses the bucket tool, the brush image is used as a pattern that fills the area.
- Users can now change keyboard shortcut bindings for tools, in the Preferences.
- Importing .pngs as palettes is now possible.
- A confirmation message now appears when the user quits Pixelorama, if there are unsaved changes.
- Templates and a lock aspect ratio option have been added to the "Create new image" dialog.
- Locking layers is now possible. When a layer is locked, no changes can be made to it. Layers are unlocked by default.
- Ability to get color for palette buttons, when editing a palette, from the currently selected left and right colors.
- Esperanto translation.
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
- Layer visibility is taken into account when exporting the drawing as a .png file. This means that invisible layers will not be included in the final .png file.
- The Godot theme has changed.
- Visual change, added border outlines to all window dialogs.
- Animation now loops by default.
- Onion skinning settings have been moved to a popup window, and 2 new buttons were added. One that toggles onion skinning, and one that opens the settings window.
- The default window size is now 1280x720, and the minimum window size is 1024x576.
- .pxo files now use ZSTD compression to result in smaller file sizes.
- Palettes/Brushes get loaded/saved in appropriate locations as specified by the XDG basedir standard, for easier usage of standard linux/bsd packaging methods and for better per-user usability.
- The splash screen is no longer purple, it now gets affected by the chosen theme.
- The brush selection popup now closes when a brush is selected.

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

## [v0.6.2] - 17-02-2020

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

## [v0.6.1] - 13-01-2020

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

## [v0.6] - 06-01-2020

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
