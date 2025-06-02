# How to contribute efficiently

## Table of contents:

* [Reporting bugs or proposing features](#reporting-bugs-or-proposing-features)
* [Contributing pull requests](#contributing-pull-requests)
* [Contributing translations](#contributing-translations)
* [Communicating with developers](#communicating-with-developers)

**Please read the first section before reporting a bug!**
<br><br>

## Reporting bugs or proposing features
Please, open just one issue for each bug you'd like to report, or a feature you'd like to request. Don't open many issues for the same bug or feature request, and don't use the same issue to report more than one bugs, or to request more than one feature. It's best to open different issues for each bug/feature request.

Also, make sure to search the [issue tracker](https://github.com/Orama-Interactive/Pixelorama/issues) before opening a new issue, in case an issue like that exists. If you're unsure, feel free to open an issue. If it's a duplicate, we'll handle it.

When reporting a bug, make sure to provide enough details, such as information about your Operating System (OS), Pixelorama version, Godot version (if you're using the source project) and clear steps to reproduce the issue. Feel free to include screenshots that might help, too.
<br><br>

## Contributing pull requests
If you are new to contributing to open source projects, make sure to read [this guide](https://opensource.guide/how-to-contribute/) before contributing. If you are new to git, [this guide](https://akrabat.com/the-beginners-guide-to-contributing-to-a-github-project/) will help you.

Please create different pull requests for each feature you'd like to implement, or each bug you'd like to fix. Make sure your pull request only handles one specific topic, and not multiple. If you want to make multiple changes, make a pull request for each of them. For this reason, it's recommended you create new branches in your forked repository, instead of using your fork's master branch.
This [Git style guide](https://github.com/agis-/git-style-guide) has some good practices to have in mind.

Keep in mind that not all PRs will be merged. Some may need discussion, or others may be downright closed. To avoid that, it's best to create an [issue](https://github.com/Orama-Interactive/Pixelorama/issues) in the form of a proposal about the PR you are thinking to open, before actually opening it. That way, people can discuss and share their opinions and thoughts about the matter. This is especially necessary when the PR is meant to change how an already existing feature works, as some people may disagree with the change, or want to offer alternative ideas.

If you want to add new features or fix bugs, please check the following guidelines:

### Git
- Make sure your branch is up to date with the master branch. If it's not, please rebase it, if it's possible.
- Do **NOT** use the `l10n_master`, `release` or `gh-pages` branches for development. Do not base your work from them, and do not open Pull Requests targeted at them.
- Avoid including unneeded files in your commits. This is true mostly for `Main.tscn` and other scenes, as Godot likes to change them by itself. If you haven't made changes to scenes, please **do NOT** include them in your commits.
- Please take a look at the differences of your changes and the main branch, and ensure you're not accidentally reverting something. This can often happen when your work is based on an older commit of the main repository's master branch.
- If your PR is closing an issue, make sure to let us know by referencing the issue's numerical ID.
- If you're making visual changes, it's a good idea to include screenshots in your PR. It's an easy way to let others know of the changes you made.

### Code
- Ensure that your code follows the recommended [GDScript style guide](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/gdscript_styleguide.html). Before pushing your commits, we recommend downloading [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit), navigating to the `src` folder, then running `gdformat .` to automatically format your code and `gdlint .` to give you tips on how to improve the code's style.
- [Static typing](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/static_typing.html) is used in the code, so please make sure the code in your PRs also uses it.
- Please enable **Editor Settings > Text Editor > Behavior > Trim Trailing Whitespace On Save** (visible with Advanced Settings). It's usually considered good practice to avoid trailing whitespace in files, and to make sure all files end with a single blank line. This makes for cleaner VCS diffs.
- When you're creating a new script, if you have "Template" checked, Godot will place some comments and methods for you. If you're not using them, please remove them.

### Organization
- New scripts and/or scenes should go under the `src/` directory and use `PascalCase` for file and folder names. [Read this guide for more information](https://www.gdquest.com/docs/guidelines/best-practices/godot-gdscript/).
- New images or other assets should go under the `assets/` directory and use `snake_case` for file and folder names.
- If you're adding new UI elements with text, please include the new strings in the `Translations.pot` file. Do not include them in the other `*.po` files. Please make sure to group similar elements together (like element names and their tooltips) by placing them close to each other.
- If you're making changes to UI elements that are `PackedScene`s, please directly edit them in their own scene files (open their scenes in the editor) instead of in `Main.tscn` or any parent scenes.
- If you're making changes to popup (and as an extension, dialog) nodes as different scenes, please don't forget to turn off their visibility.
- If you're adding new interactive UI elements such as buttons, don't forget to change their mouse default cursor shape to pointing arrow. Hint tooltips that explain the element's usage to the user are welcome too, just make sure to also include them in `Translations.pot`.
- If you want to add an error dialog, use the existing `ErrorDialog`, change its text and pop it up, instead of making a new one.
<br><br>

## Contributing translations
Pixelorama uses [Crowdin](https://crowdin.com/project/pixelorama) to host the translations. In order to contribute, you need to login with your Crowdin account, select the language(s) you'd like to provide translations for, select `Translations.pot`, and start translating!
If you need help with the context of some strings, or want to translate in a language that is not available, feel free to contact me (Overloaded). All languages are welcome to be translated!
<br><br>

## Communicating with developers
To communicate with developers (e.g. to discuss a feature you want to implement or a bug you want to fix), the following channels can be used:

- [GitHub Issues](https://github.com/Orama-Interactive/Pixelorama/issues) or [GitHub Discussions](https://github.com/Orama-Interactive/Pixelorama/discussions): If there is an
  existing issue or discussion about a topic you want to discuss, just add a comment to it -
  all developers watch the repository and will get an email notification. You
  can also create a new issue/discussion.
- [Our Discord Server](https://discord.gg/GTMtr8s): All developers and most contributors are there, so it's the best way for direct chat
  about Pixelorama. You can use the channel `#pixelorama-dev` to stay up to date with Pixelorama's developments real-time,
  or talk about the developments and request new features. If you seek support, please use the `#pixelorama-help` channel instead. Please avoid DMing developers and contributors, unless they tell you otherwise.
