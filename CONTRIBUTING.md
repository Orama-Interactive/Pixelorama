# How to contribute efficiently

## Table of contents:

* [Reporting bugs or proposing features](#reporting-bugs-or-proposing-features)
* [Contributing pull requests](#contributing-pull-requests)
* [Contributing with translations](#contributing-with-translation)
* [Communicating with developers](#communicating-with-developers)

**Please read the first section before reporting a bug!**

## Reporting bugs or proposing features
Please, open just one issue for each bug you'd like to report, or a feature you'd like to request. Don't open many issues for the same bug or feature request, and don't use the same issue to report more than one bugs, or to request more than one feature. It's best to open different issues for each bug/feature request.

Also, make sure to search the [issue tracker](https://github.com/Orama-Interactive/Pixelorama/issues) before opening a new issue, in case an issue like that exists. If you're unsure, feel free to open an issue. If it's a duplicate, we'll handle it.

When reporting a bug, make sure to provide enough details, such as information about your Operating System (OS), Pixelorama version, Godot version (if you're using the source project) and clear steps to reproduce the issue. Feel free to include screenshots that might help, too.


## Contributing pull requests
If you want to add new features or fix bugs, please make sure that:
- The code you are submitting follows the recommended [GDScript style guide](https://docs.godotengine.org/en/latest/getting_started/scripting/gdscript/gdscript_styleguide.html) (note that not all of the code is following this format, and it will be fixed in the future).
  [Static typing](https://docs.godotengine.org/en/latest/getting_started/scripting/gdscript/static_typing.html) is used in the code, so please make sure the code in your PRs also use it.
- Avoid including unneeded files in your commits. This is true mostly for Main.tscn and other scenes, as Godot likes to change them by itself. If you haven't made changes to scenes, please **do NOT** include them in your commits.
- Please have **Trim Trailing Whitespace On Save** enabled. This makes for cleaner VCS diffs. It's usually considered good practice to avoid trailing whitespace in files, and to make sure all files end with a single blank line.
  You can enable **Text Editor > Files > Trim Trailing Whitespace On Save** in the Editor Settings to do this automatically in the script editor
- Make sure your branch is up to date with the master branch. If it's not, please rebase it, if it's possible.
- If your PR is closing an issue, make sure to let us know.
- If you are adding new UI elements with text, please include the new strings in the `Translations.pot` file. Do not include them in the other `*.po` files.
- If you are making changes to popup (and as an extension, dialog) nodes as different scenes, please don't forget to turn off their visibility.
- When you're creating a new script, Godot will place some comments and methods for you. If you're not using them, please remove them. They're taking unnecessary space.
- Avoid using the "pass" keyword. It has no actual usage, besides being used as a placeholder for temporarily empty methods and empty cases. Make sure you don't include empty methods and cases in the code of your PR.
- If you are adding new interactive UI elements such as buttons, don't forget to change their mouse default cursor shape to pointing arrow. Hint tooltips that explain the element's usage to the user are welcome too, just make sure to also include them in `Translations.pot`.

Please create different pull requests for each feature you'd like to implement, or each bug you'd like to fix. Make sure your pull request only handles one specific topic, and not multiple. If you want to make multiple changes, make a pull request for each of them. For this reason, it's recommended you create new branches in your forked repository, instead of using your fork's master branch.
This [Git style guide](https://github.com/agis-/git-style-guide) has some good practices to have in mind.

Keep in mind, however, that not all PRs will be merged. Some may need discussion, or others may be downright closed.


## Contributing with translations
Pixelorama uses [Crowdin](https://crowdin.com/project/pixelorama) to host the translations. In order to contribute, you need to login with your Crowdin account, select the language(s) you'd like to provide translations for, select `Translations.pot` and start translating!
If you need help with the context of some strings, or want to translate in a language that is not available, feel free to contact me (Overloaded). All languages are welcome to be translated!


## Communicating with developers
To communicate with developers (e.g. to discuss a feature you want to implement or a bug you want to fix), the following channels can be used:

- [GitHub issues](https://github.com/Orama-Interactive/Pixelorama/issues): If there is an
  existing issue about a topic you want to discuss, just add a comment to it -
  all developers watch the repository and will get an email notification. You
  can also create a new issue - please keep in mind to create issues only to
  discuss quite specific points about the development, and not general user
  feedback or support requests.
- [Our Discord Server](https://discord.gg/GTMtr8s): All developers and most contributors are there, so it's the best way for direct chat
  about Pixelorama. You can use the channel #pixelorama-dev to stay up to date with Pixelorama's developments real-time,
  or talk about the developments and request new features. If you seek support, please use the #pixelorama-help channel instead.
