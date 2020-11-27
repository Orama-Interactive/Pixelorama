<p align="center">
    <h1 align = "center">Pixelorama - your free and open-source sprite editor!</h1>
</p>
<p align="center">
    Made by Orama Interactive with the Godot Engine, written in GDScript!
</p>
<p align="center">
    <a href="https://github.com/Orama-Interactive/Pixelorama/actions">
        <img src="https://github.com/Orama-Interactive/Pixelorama/workflows/dev-desktop-builds/badge.svg" alt="Build Passing" />
    </a>
    <a href="https://orama-interactive.github.io/Pixelorama/early_access/">
        <img src="https://github.com/Orama-Interactive/Pixelorama/workflows/dev-web/badge.svg" alt="Build Passing" />
    </a>
    <a href="https://github.com/Orama-Interactive/Pixelorama">
        <img src="https://img.shields.io/github/languages/code-size/Orama-Interactive/Pixelorama.svg" alt="Code Size" />
    </a>
    <a href="https://github.com/Orama-Interactive/Pixelorama">
        <img src="https://img.shields.io/github/repo-size/Orama-Interactive/Pixelorama.svg" alt="Repository size" />
    </a>
    <a href="https://github.com/Orama-Interactive/Pixelorama/blob/master/LICENSE">
        <img src="https://img.shields.io/github/license/Orama-Interactive/Pixelorama.svg" alt="License" />
    </a>
</p>
<p align="center">
    <a href="https://github.com/Orama-Interactive/Pixelorama/releases">
        <img src="https://img.shields.io/github/downloads/Orama-Interactive/Pixelorama/total?color=lightgreen" alt="Downloads" />
    </a>
    <a href="https://discord.gg/GTMtr8s">
        <img src="https://discord.com/api/guilds/645793202393186339/embed.png" alt="Discord Chat" />
    </a>
    <a href="https://crowdin.com/project/pixelorama">
        <img src="https://badges.crowdin.net/pixelorama/localized.svg" alt="Crowdin Localized %" />
    </a>
    <a href="https://github.com/godotengine/awesome-godot">
        <img src="https://awesome.re/mentioned-badge.svg" alt="Mentioned in Awesome Godot" />
    </a>
</p>
 
[![Pixelorama's UI](https://static.wixstatic.com/media/673cdd_061f5f9602ea4c35b6d4f3c50713d36a~mv2.png)](https://www.youtube.com/watch?v=NLb0TNxZ27E&list=PLVEP1Zz6BUpBiQC0CB6eNBhhLF4tEwBB-&index=10)
Art by Wishdream - winner of the first Pixelorama splash screen art contest!

Make sure to visit our website for more information! https://www.orama-interactive.com

Join our Discord community server​ where we can discuss about Pixelorama and all our other projects! https://discord.gg/GTMtr8s

If you like, consider helping us by sponsoring this project! It would enable us to focus more on Pixelorama, and make more projects in the future!

Toss A Coin For A New Feature: [![Become a Patron!](https://c5.patreon.com/external/logo/become_a_patron_button.png)](https://patreon.com/OramaInteractive)

## Download
Stable versions:
- [Itch.io (Windows, Linux, Mac & Web)](https://orama-interactive.itch.io/pixelorama)
- [GitHub Releases (Windows, Linux & Mac)](https://github.com/Orama-Interactive/Pixelorama/releases)
- [GitHub Pages (Web)](https://orama-interactive.github.io/Pixelorama/)
- [Flathub (Linux)](https://flathub.org/apps/details/com.orama_interactive.Pixelorama)
- [Snap Store (Linux)](https://snapcraft.io/pixelorama)

You can also find early access builds in the [GitHub Actions page](https://github.com/Orama-Interactive/Pixelorama/actions). There's also a [Web version available](https://orama-interactive.github.io/Pixelorama/early_access/).
Keep in mind that these versions will have bugs and are unstable. Unless you're interested in testing the main branch of Pixelorama, it's recommended that you stick to a stable version.

## Documentation
You can find Online Documentation for Pixelorama here: https://orama-interactive.github.io/Pixelorama-Docs

It's still work in progress so there are some pages missing. If you want to contribute, you can do so in [Pixelorama-Docs' GitHub Repository](https://github.com/Orama-Interactive/Pixelorama-Docs).

## Cloning Instructions
Pixelorama uses Godot 3.2, so you will need to have it in order to run the project.
As of right now, most of the code is written using GDScript, so the mono version of Godot is not required, but Pixelorama should also work with it.

## Current features as of version v0.8:

- Choosing between 7 tools – pencil, eraser, fill bucket, lighten/darken, color picker, rectangle select and zoom– and mapping them to both of your left and right mouse buttons.
- Are you an animator? Pixelorama has its own animation timeline just for you! You can work at an individual cel level, where each cel refers to a unique layer and frame. Supports onion skinning, cel linking, motion drawing and frame grouping with tags.
- Different tool options for each of the mouse buttons.
- Custom brushes! Load your brushes from files or select them in your project with the selection tool, and they will get stored in `.pxo` files!
- Random custom brushes! Every time you draw, expect to see a different random result!
- Create or import custom palettes!
- Multiple project support, using tabs!
- Pattern filling! Use the bucket tool to fill out an area with a pattern of your choosing.
- Import images and edit them inside Pixelorama. If you import multiple files, they will be added as individual animation frames. Importing spritesheets is also supported.
- Export your gorgeous art as `PNG` or `GIF` files. Exporting your projects as spritesheets is also possible.
- Pixel perfect mode for perfect lines, for the pencil, eraser & lighten/darken tools.
- Save and open your projects as Pixelorama's custom file format, `.pxo`
- Undo/Redo support!
- Autosave support, with data recovery in case of a software crash.
- Multiple theme support! Choose a theme from Dark, Gray, Blue, Caramel and Light!
- Horizontal & vertical mirrored drawing!
- Tile Mode for pattern creation!
- Split screen mode to see your masterpiece twice! And a mini canvas preview area to see it thrice!
- Create straight lines for pencil, eraser and the lighten/darken tool by pressing `Shift`. If you also press `Control`, you can constrain angles with a step of 15.
- Generate outlines for your images!
- Υou can zoom in and out with the mouse scroll wheel or the `+` and `-` keys respectively, and pan by clicking the middle mouse button, by holding `Space` or with the arrow keys!
- Keyboard shortcuts, and the ability to change their bindings.
- Rulers and guides!
- Rectangular & isometric grid types.
- Scale, crop, rotate, flip, color invert, HSV-adjust, desaturate and generate gradients in your images!
- Multi-language localization support! See our [Crowdin page](https://crowdin.com/project/pixelorama) for more details.


## Special thanks to
- All [Godot](https://github.com/godotengine/godot) contributors! Without Godot, Pixelorama would not exist.
- https://github.com/jegor377/godot-gdgifexporter - the gif exporter Pixelorama uses.
- https://github.com/Pukkah/HTML5-File-Exchange-for-Godot - responsible for file exchange in Pixelorama's HTML5 (Web) version.
- https://github.com/aBARICHELLO/godot-ci - for creating a Godot Docker image that lets us export Pixelorama automatically using GitHub Actions.
- The entire Pixelorama community! Contributors, donors, translators, users, you all have a special place in our hearts! <3
