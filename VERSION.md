**version 0.1.5**  
*added*  
+ Light code clean  
+ Some Bugfix  
+ Plugin output for debug of some of the operations  
+ Automatic Filling of sign in fields  
+ Multiple files commit and changes commit  
+ Every text and image file format supported   
+ Filtering in committing  
+ Autoload branches content  

*removed*  
+ Single file commit  
+ Only text file commit  

----------------------

**version 0.2.5**  
*added*  
+ Code clean  
+ Chose branch to commit  
+ Delete resource selected in repository  
+ Filters: Exceptions, Only, Start from  

----------------------

**version 0.2.7**  
*added*  
+ Code clean  
+ Fix some little animations
+ New commit method: tree created from blobs, creates a single commit with more files

*removed*
+ Old commit method

----------------------

**version 0.2.9**  
*added*  
+ Code clean  
+ Bugfix with commits
+ A marker next to "Sign-in" buttons appears if a logfile is found

----------------------

**version 0.3.1**  
*added*  
+ Several bugfixes 

--------------------

**version 0.3.2**  
*added*
+ New folder organization (whole plugin in *addon* folder)
+ New install method (AssetLib from GodotEngine Editor)

--------------------

**version 0.6.0**  
*removed*   
- old position: 
  - the plugin doesn't appear in docs anymore. Instead, it will load a new tool in the top toolbar
- old layout: 
  - RepositoryList and GistList now show more informations about their contents
- old repository's content system:
  - Repositories contents are now listed in a tree way
- old "commit to repository" system and FILTERS:
  - The old system was based on a Filtering system: I introduced filters to help people choose which file to exclude from your commit, which files should negate an exclusion, and eventually from which path to start. This system was based on the conception that the whole commit started from the `res://` path. Now, you can select in a more interactive way all files and folders you want to commit, and exclude them with a .gitignore system.

*added*  
+ Informations about repositories:
  + Repositories now have their own icons: *lock* for private, *fork* for forked repositories, *gray repo* for own public repositories
  + Repositories show their forked times and stars
+ License templates: new repositories can now be created with a license template from all availables github supported licenses
+ Repository contents system:
  + files are now displayed in a compact, more readable tree system. Files and folders are differentiated, and folders can be folded and unfolded to show their contents
  + you can now delete multiple files just CTRL/SHIFT selecting them. **remember:** folders cannot be deleted by github integrity rules. Delete all folder's contents to delete the folder itself
  + you can now create a new branch from all selectable branches in your repository
+ **!Repository committing system**:  
  + [filtering]  
    + Since FILTERS are not supported anymore, the usage of `.gitignore` is now implemented.
    + a `.gitignore` file is loaded from the repository you want to commit to. If this repository doesn't have a gitignore, an empty and new gitignore can be created and committed.
    + the "gitignore editor" is shown next to the "committing tree" so you can procedurally select files and folders, and exclude/include them with the gitignore. *if you don't know how to use a gitignore, I recommend you to click on the `?` button in the bottom-right of the gitignore editor*
    + the "edit .gitignore" button will prevent any unwanted modifications to be applied by any chance (miss-typing, or you just don't need to edit the gitignore since it was loaded from the repository)  
  + [file choosing]
    + Since FILTERS are not supported anymore, the commit process won't start from the project folder.
    + Now you can select multiple files and directories you want to commit through a file dialog showing your whole project folder.
    + Files and directories can always be removed before committing  
**Please, note that the gitignore filtering method is custom made. To fully support the same gitignore method applied by GitHub some tests are needed**
+ **Gists** can now be opened, edited, and pushed with a cusotm GitEditor. Gists which contain more than one file are supported, and you can edit more files at the same time.

--------------------

**version 0.6.2**  
*fixed*  
- new method to show contents of repositories: faster code and works better. Empty repositories won't be loaded
- now each loading has a loading screen covering the whole scene: no more missclicks during a repository loading or a commit
- new icons in repositories to visually show what's the content type ( adapted to Godot Engine's file types)

--------------------

**version 0.7.0**  
*added*  
- **pull / clone button** : you can now pull from any branch of a selected repository. A local copy of your repository with files relative to the selected branch  will be created in a .zip file inside your 'res://' folder. In this way you will be able to manage your repository's files in the way you prefer. Pulling/Cloning works on public, private and forked repositories.

--------------------

**version 0.7.2**  
*added*  
- **debug messages checkbox** : a new checkbox will appear on the top-left corner of the GUI. With this checkbox you can decide if you want to get debug messages from this plugin or not. You can enable/disable it in any plugin tab  

*fidex*  
- **deleting repository's resources** : with the previous version a bug occured and it wasn't possible to delete resources within a repository. 
  
  --------------------

**version 0.7.4**  
*added*  
- **auto extraction** : the plugin is now able to auto-extract downloaded archives automatically. _your OS needs python_ to run the extraction script since it is not currently built in Godot Engine. It is still a beta script, so it is highly recommended to use it inside empty projects and have some tests. You can always report issues and contact me for any bug.  
- **sing up link** : if you don't have an account, or want to create a new one, you can click on the *'Don't have a GitHub account yet?'* button in  the main tab of the plugin
  
    --------------------

**version 0.7.5**  
*fixed*  
- **minor bugs**  
 
--------------------

**version 0.7.8**  
*fixed*  
- *[!] icon for log file* appeared even though there weren't log files already stored  
- increased the number of repositories that will be listed. Default GitHub repository listing provides only 30 repositories at time. Now the limit is increased to 100.

*added*  
- user's datas are now stored in an **encrypted file**, and datas are shared on an upper level folder. Now you won't need to save the same datas for each 'github integration' plugin you install in your new projects, but all the projects you have and in which you use this plugin will always use the same log file. This log file will be stored at `<path_to_user>/AppData/Roaming/Godot/github_integration/`  
- the plugin now supports two different unzipping methods, one with a *Python script* and one with a *GDScript*. The second one is offered by an external plugin, which is the [gdunzip](https://github.com/jellehermsen/gdunzip) plugin developed by [jellehermsen](https://github.com/jellehermsen) (please, check it out!!).   **NOTE:** If you've got Python installed on your PC, it is recommended using the Python one, since the GDScript one is not developed by me and may not work. In that case, please make an issue with specific informations about the problem you've encountered, and I'll make sure to discuss about it with the developer.

--------------------

**version 0.8.2**  
*fixed*  
- autoload errors with 3.2 beta versions (and so on) 
- some interface bugs  
- minor bugfixes
  
*added*
- **new authentication method** : it is now possible to log into your GitHub profile with an *Access Token*. Since GitHub will deprecate the basic authentication method (which consists of `your e-mail : your password`) this plugin will **only work** with your personal access token.  
Please, visit [this site](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) to understand what a Personal Access Token is, and how to use it. You will also find this link as a button in the plugin.  

--------------------

**version 0.8.4**  
*fixed*  
- plugin ui
- extraction methods
  
*added*
- introduced a java extraction method for zip files. 



-----------------
> This text file was created via [TextEditor Integration](https://github.com/fenix-hub/godot-engine.text-editor) inside Godot Engine's Editor.




