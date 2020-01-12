# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [v0.6.1] - Unreleased

### Added
- Italian translation - thanks to Gaarco!
- In addition to the middle mouse button, you can now use `Space` to pan around the canvas.
- The ability to choose for which color the color picker does its job, the left or the right. (Issue #115)
- Default image settings are now in the Preferences - thanks to Gaarco!

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
