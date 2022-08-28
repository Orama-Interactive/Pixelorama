<p align="center">
    <h1 align = "center">Pixelorama - pixelate your dreams!</h1>
</p>
<p align="center">
    Pixelorama is a free and open source pixel art editor, proudly created with the Godot Engine, by Orama Interactive. Whether you want to make animated pixel art, game graphics, tiles and any kind of pixel art you want, Pixelorama has you covered with its variety of tools and features. Free to use for everyone, forever!
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
 
[![Pixelorama's UI](https://img.itch.zone/aW1hZ2UvNDcwMzY3LzcwMTE1NzUucG5n/original/7Ykr%2Fj.png)](https://youtu.be/sM1v5uaBSrM)

Join our Discord community server where we can discuss about Pixelorama and all our other projects! https://discord.gg/GTMtr8s

If you like, consider helping us by sponsoring this project! It would enable us to focus more on Pixelorama, and make more projects in the future!

[![Become a Patron!](https://c5.patreon.com/external/logo/become_a_patron_button.png)](https://patreon.com/OramaInteractive)

## Download
Stable versions:
- [Itch.io (Windows, Linux, Mac & Web)](https://orama-interactive.itch.io/pixelorama)
- [GitHub Releases (Windows, Linux & Mac)](https://github.com/Orama-Interactive/Pixelorama/releases)
- [GitHub Pages (Web)](https://orama-interactive.github.io/Pixelorama/)
- [Flathub (Linux)](https://flathub.org/apps/details/com.orama_interactive.Pixelorama)
- [Snap Store (Linux)](https://snapcraft.io/pixelorama)
- [OpenStore (Ubuntu Touch)](https://open-store.io/app/pixelorama.orama-interactive)

You can also find early access builds in the [GitHub Actions page](https://github.com/Orama-Interactive/Pixelorama/actions). There's also a [Web version available](https://orama-interactive.github.io/Pixelorama/early_access/).
Keep in mind that these versions will have bugs and are unstable. Unless you're interested in testing the main branch of Pixelorama, it's recommended that you stick to a stable version.

## Documentation
You can find Online Documentation for Pixelorama here: https://orama-interactive.github.io/Pixelorama-Docs

It's still work in progress so there are some pages missing. If you want to contribute, you can do so in [Pixelorama-Docs' GitHub Repository](https://github.com/Orama-Interactive/Pixelorama-Docs).

## Cloning Instructions
Pixelorama uses Godot 3.5, so you will need to have it in order to run the project. Older versions may not work.
As of right now, most of the code is written using GDScript, so the mono version of Godot is not required, but Pixelorama should also work with it.

## Current features:

- A variety of different tools to help you draw, with the ability to map a different tool in each left and right mouse buttons.
- Are you an animator? Pixelorama has its own animation timeline just for you! You can work at an individual cel level, where each cel refers to a unique layer and frame. Supports onion skinning, cel linking, motion drawing and frame grouping with tags.
- Custom brushes, including random brushes.
- Create or import custom palettes.
- Import images and edit them inside Pixelorama. If you import multiple files, they will be added as individual animation frames. Importing spritesheets is also supported.
- Export your gorgeous art as `PNG`, as a single file, a spritesheet or multiple files, or `GIF` file.
- Pixel perfect mode for perfect lines, for the pencil, eraser & lighten/darken tools.
- Autosave support, with data recovery in case of a software crash.
- Horizontal & vertical mirrored drawing.
- Tile Mode for pattern creation.
- Rectangular & isometric grid types.
- Scale, rotate and apply multiple image effects to your drawings.
- Multi-language localization support! See our [Crowdin page](https://crowdin.com/project/pixelorama) for more details.


## Special thanks to
- All [Godot](https://github.com/godotengine/godot) contributors! Without Godot, Pixelorama would not exist.
- https://github.com/gilzoide/godot-dockable-container - the plugin Pixelorama's UI system uses for dockable containers.
- https://github.com/Orama-Interactive/Keychain - the plugin Pixelorama's shortcut system uses for extensive customizability.
- https://github.com/jegor377/godot-gdgifexporter - the gif exporter Pixelorama uses.
- https://github.com/Pukkah/HTML5-File-Exchange-for-Godot - responsible for file exchange in Pixelorama's HTML5 (Web) version.
- https://github.com/aBARICHELLO/godot-ci - for creating a Godot Docker image that lets us export Pixelorama automatically using GitHub Actions, as well as https://github.com/huskeee/godot-headless-mac for automated macOS exporting and https://github.com/hiulit/Unofficial-Godot-Engine-Raspberry-Pi for automated Raspberry Pi 4 exporting.
- The entire Pixelorama community! Contributors, donors, translators, users, you all have a special place in our hearts! <3
