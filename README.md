# PSModuleBuild

This is a set of build tasks for kicking off a PowerShell module project and building regular releases of the project.

##Usage
This is more of a scaffolding framework which can be used to kickstart a generic PowerShell module project. It includes the starting files and scripts needed to perform regular build releases, uploading to the powershell gallery, and other such fun. All the hard stuff is based around the excellent invoke-build project.

There are a few premises which should be known about this project.
- I use serveral PowerShell 5 features but this doesn't mean that the underlying modules being created need to require PowerShell 5 (the default manifest file that gets created sets the required version to 3).
- All documentation for the module gets automatically created as part of the build process. This documentation is created from the comment based help associated with every function. I personally find this to be the easiest way to keep my documentation up to date. All the code and tasks are open to be changed though. The beauty of a task based engine like invoke-build is that you can very easily use the existing tasks and create your own customizations.
- Parts of this scaffolding were written specifically around the premise that the project is hosted in github.
- The general idea of the base module is that you will develop and test it out without having to worry about keeping your manifest file up to date with your public functions. When you build the module the functions are explicitly injected into the manifest file and the source files are all (optionally) combined into one psm1 for distribution.
- I've included two build options which are easy to turn on and off. One will format the code, the other will run the psscriptanalyzer.
- I've included a handful of other tasks that can be run directly with invoke-build. This includes testing out the documentation generation and code formatting. They are not included in the wrapper script at this time as it felt a bit like recreating a wheel (as invoke-build is so easy to use as it is).

### Step 1 - Initialization
The content of this project should be placed in an empty directory with no other code whatsoever. Then kick off the initialize.ps1 script without parameters if you have no github project repository setup (less preferred).

`.\Initialize.ps1`

Or with the 'GithubRepo' parameter if you have already created a Github project repository (preferred).

`.\Initialize.ps1 -GithubRepo https://github.com/yourgithubaccount/yourgithubrepo.git'`

This will start with opening up the .environment.ps1 file in notepad for editing. You need to populate your module name, its project website, tags, author, and description associated with the project. This file is dot sourced in several other initialization tasks and in the build process later on. Once saved you can go ahead and continue the initialization process. Several template files are copied out to appropriate locations. Additionally, the default module manifest file gets created.

**Note**: *The starting module manifest file should be updated to suit your needs. The only items which ever get automatically updated in this file later on will be the version number and the exported functions. If you have exported aliases or other customizations the build process will do nothing to detect these things.*

Later you can always edit this file to change options in the build or even move paths and such but you should NEVER run the Initialize.ps1 script again. Towards this end this script deletes the .initialize.ps1 invoke-build task script. If you goofed up then simply blow things away and start from scratch.

You should go ahead and delete the initialize.ps1 script from your project root directory at this time as it is no longer usable.

### Step 2 - Flesh Out Your Module
After the initialization has completed this directory should be all setup and 'buildable' without much more work needed other than adding your ps1 files to the right directories. Any function code for your module should be dropped into the src/public if it will be exported, src/private if it will not be exported, or src/other if it is code you want to run at the top of your module but isn't explicitly functions to be exported (small example ps1 included for your reference).

**Note:** *If you import the module without any public code at all (right after initializing for example) then the only private function I include with this template always gets exported for whatever reason (get-callerpreference). Because of this I purposefully error out of the build process if no public functions are defined.*

Anyways, load up your module for testing by importing the .psm1 file if you like:
`Import-Module .\ModuleName.psm1`

It will work as you would expect where any defined functions in the public folder will be exported and everything else will remain private to the module.

***Note**: The install.ps1 script that gets generated automatically creates github appropriate links for downloading your project. You may have to modify the install.ps1 if your project is located elsewhere.*

You should also probably update the default readme.md file that gets created as it is rather bland.

### Step 3 - Build a Release

The default version for a brand new module is set at 0.0.1. To build this module for a release simply run the Build.ps1 file

`.\Build.ps1`

This will go throught he process of combining the source files, populating the exportable functions, creating online help files, formatting the code, analyzing the script, and more. If everything builds without errors you will see the results populated in the release directory in two areas:
1. In the release directory in a folder with the same name as the module
2. In the release directory in a folder with the version number of the release.

**Note**: *If you run the build process again it will overwrite the version and current directory.*

At this point you should have a working release you could theoretically have someone manually install if you so desired.

The build will have failed if you didn't have enough comment based help to create the help file.

### Step 4 - Setup A PowerShell Gallery Profile (Optional)
If you have plans to upload your module to the PowerShell Gallery then this build script can help automate the process a bit. But first you will need to create a local profile file with the following command:

`.\Build.ps1 -CreatePSGalleryProfile`

The command is a bit of a misnomer as all it will do is create a local file which will be parsed when uploading to the PowerShell gallery site. You still need to create an account and attain an API key from the PowerShell Gallery ![website](https://www.powershellgallery.com/).

Once you have attained your API key you will need to save a copy of it within your powershell profile (it would be silly to keep it in your project folder that may get shared with others or accidentally uploaded for public consumption). Run the following to create the correct file for pasting your key into.

`notepad (Join-Path (Split-Path $profile) 'psgalleryapi.txt')`

Now when you are ready to upload to the psgallery simply run the following:
`.\Build.ps1 -UploadPSGallery -ReleaseNotes 'First Upload'

Assuming you have a valid NugetAPI key in the psgalleryapi.txt file in your profile this build step will automatically update the the .psgallery file with any relevant tags/uris from your manifest file and upload the release directory module to the PowerShell Gallery for you.

**Note:** *I've not figured out yet how to reset versions when uploading to the gallery. You always have to upload a newer version than what is already there so be extra certain you are ready to publish the module before doing this step.*

### Step 4 - Start Your Next Release
When you have finally uploaded your current release to github the version number will go up by 1 in the minor version release portion (so 0.0.1 will become 0.0.2). This is done in the version.txt file within your project directory. If you go to build the current module again it will poop out as the version release in this file does not match the version found in your module manifest file. This is by design. In order to confirm you are ready to start working on this release you need to run the following:

`.\Build.ps1 -UpdateRelease`

Once this has been done you can proceed to build your module again:

`.\Build.ps1`

##Some Missing Stuff
I need to get pester testing and git pushing finished up. The tasks are there for the git stuff but nothing has been done for Pester yet (shame on me).


##Credits
[Haroopad](http://pad.haroopress.com/) - Sweet Markdown Editor

[PowerShell Practice and Style](https://github.com/PoshCode/PowerShellPracticeAndStyle)

[Invoke-Build](https://github.com/nightroman/Invoke-Build) - A kick ass build automation tool written in PowerShell



