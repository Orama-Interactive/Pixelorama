<p align="center">
    <h1 align = "center">Pixelorama - pixelate your dreams!</h1>
</p>
<p align="center">
    Unleash your creativity with Pixelorama, a powerful and accessible open-source pixel art multitool. Whether you want to create sprites, tiles, animations, or just express yourself in the language of pixel art, this software will realize your pixel-perfect dreams with a vast toolbox of features.
</p>
<p align="center">
    <a href="https://github.com/Orama-Interactive/Pixelorama/actions">
        <img src="https://github.com/Orama-Interactive/Pixelorama/workflows/dev-desktop-builds/badge.svg" alt="Build Passing" /></a>
    <a href="https://orama-interactive.github.io/Pixelorama/early_access/">
        <img src="https://github.com/Orama-Interactive/Pixelorama/workflows/dev-web/badge.svg" alt="Build Passing" /></a>
    <a href="https://github.com/Orama-Interactive/Pixelorama">
        <img src="https://img.shields.io/github/languages/code-size/Orama-Interactive/Pixelorama.svg" alt="Code Size" /></a>
    <a href="https://github.com/Orama-Interactive/Pixelorama">
        <img src="https://img.shields.io/github/repo-size/Orama-Interactive/Pixelorama.svg" alt="Repository size" /></a>
    <a href="https://github.com/Orama-Interactive/Pixelorama/blob/master/LICENSE">
        <img src="https://img.shields.io/github/license/Orama-Interactive/Pixelorama.svg" alt="License" /></a>
</p>
<p align="center">
    <a href="https://github.com/Orama-Interactive/Pixelorama/releases">
        <img src="https://img.shields.io/github/downloads/Orama-Interactive/Pixelorama/total?color=lightgreen" alt="Downloads" /></a>
    <a href="https://discord.gg/GTMtr8s">
        <img src="https://discord.com/api/guilds/645793202393186339/embed.png" alt="Discord Chat" /></a>
    <a href="https://crowdin.com/project/pixelorama">
        <img src="https://badges.crowdin.net/pixelorama/localized.svg" alt="Crowdin Localized %" /></a>
    <a href="https://github.com/godotengine/awesome-godot">
        <img src="https://awesome.re/mentioned-badge.svg" alt="Mentioned in Awesome Godot" /></a>
</p>
 
[![Pixelorama's UI](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2779170/ss_54395040c25b243cb82a3bd68778e19e04b43ade.1920x1080.jpg?t=1719424898)](https://youtu.be/--ZcztkvWUQ)

Join our Discord community server where we can discuss about Pixelorama and all our other projects! https://discord.gg/GTMtr8s

If you like, consider helping us by sponsoring this project! It would enable us to focus more on Pixelorama, and make more projects in the future!

[![Become a Patron!](https://c5.patreon.com/external/logo/become_a_patron_button.png)](https://patreon.com/OramaInteractive)

## Download
Stable versions:
- [Steam (Windows & Linux)](https://store.steampowered.com/app/2779170?utm_source=github)
- [Itch.io (Windows, Linux, Mac & Web)](https://orama-interactive.itch.io/pixelorama)
- [GitHub Releases (Windows, Linux & Mac)](https://github.com/Orama-Interactive/Pixelorama/releases)
- [GitHub Pages (Web)](https://orama-interactive.github.io/Pixelorama/)
- [Flathub (Linux)](https://flathub.org/apps/details/com.orama_interactive.Pixelorama)
- [Snap Store (Linux)](https://snapcraft.io/pixelorama)
- WinGet (Windows) - `winget install pixelorama`

You can also find early access builds in the [GitHub Actions page](https://github.com/Orama-Interactive/Pixelorama/actions). There's also a [Web version available](https://orama-interactive.github.io/Pixelorama/early_access/).
Keep in mind that these versions will have bugs and are unstable. Unless you're interested in testing the main branch of Pixelorama, it's recommended that you stick to a stable version.

## Documentation
You can find online Documentation for Pixelorama here: https://orama-interactive.github.io/Pixelorama-Docs

It's still work in progress so there are some pages missing. If you want to contribute, you can do so in [Pixelorama-Docs' GitHub Repository](https://github.com/Orama-Interactive/Pixelorama-Docs).

## Cloning Instructions
Pixelorama uses Godot 4.3, so you will need to have it in order to run the project. Older versions will not work.
As of right now, most of the code is written using GDScript, so the mono version of Godot is not required, but Pixelorama should also work with it.

## Features:
- A variety of different tools to help you create, with the ability to dynamically map each one on the left and the right mouse buttons with a single click.
- Animation support with a timeline composed of layers and frames, with onion skinning, frame tags and the ability to draw while the animation is playing.
- Pixel perfect mode for perfect pixel lines.
- Clipping masks.
- Pre-made palettes as well as many palette importing options.
- Multiple image manipulation effects.
- Non-destructive and fully customizable layer effects, such as outline, gradient map, drop shadow and palettize.
- A powerful drawing canvas with guides, a rectangular and an isometric grid, and tile mode for easier seamless pattern creation.
- Autosave support, with data recovery in case of a software crash.
- Comprehensive user interface with many customizability options.
- Export to PNG and other image and video formats, as well as spritesheets, GIFs, animated PNGs etc.
- Import spritesheets, multiple images as separate frames, as well as GIFs and videos.
- Various rotation and scaling algorithms tailored for pixel art, such as [cleanEdge](http://torcado.com/cleanEdge/), OmniScale and rotxel.
- 3D layers that allow you to bring 3D shapes and models into your 2D canvas.
- A command line interface for automated file exporting.
- Custom user data for projects, layers, frames, frame tags and cels, allowing you to attach metadata for game development.
- Various free community-made extensions, such as tools that automatically convert your 2D pixels into 3D voxels.
- Fully open source with free updates, forever!
- Multi-language localization support! See our [Crowdin page](https://crowdin.com/project/pixelorama) for more details.


## Special thanks to
- All [Godot](https://github.com/godotengine/godot) contributors! Without Godot, Pixelorama would not exist.
- https://github.com/gilzoide/godot-dockable-container - the plugin Pixelorama's UI system uses for dockable containers.
- https://github.com/Orama-Interactive/Keychain - the plugin Pixelorama's shortcut system uses for extensive customizability.
- https://github.com/jegor377/godot-gdgifexporter - the gif exporter Pixelorama uses.
- https://github.com/Pukkah/HTML5-File-Exchange-for-Godot - responsible for file exchange in Pixelorama's HTML5 (Web) version.
- https://github.com/aBARICHELLO/godot-ci - for creating a Godot Docker image that lets us export Pixelorama automatically using GitHub Actions.
- The entire Pixelorama community! Contributors, donors, translators, users, you all have a special place in our hearts! <3
