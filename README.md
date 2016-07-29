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

Later you can always edit this file to change options in the build or even move paths and such but you should NEVER run the Initialize.ps1 script again. Towards this end this script deletes the .createframework.ps1 invoke-build task script. If you goofed up then simply blow things away and start from scratch.

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
1. In the release directory in a folder with the same name as the module (which is best practice btw)
2. In the release directory in a folder with the version number of the release.

**Note**: *If you run the build process again it will overwrite the version and current directory.*

At this point you should have a working release you could theoretically have someone manually install if you so desired.

**Note:** *The build will pause if you didn't have enough comment based help to create the help file. Now is a chance to look at the created markdown files it references in the temp\docs directory to see what is missing. Use this as a chance to round back on your CBH and update it to fill in the gaps and then restart the build process again. Alternately, you can update the markdown files directly then continue the build process but this is not recommended as it is a temporary solution at best.*

### Step 4 - Test a Release
You may get a build to complete without errors but that doesn't mean that the module will behave as expected. You can do a quick module install and load test if you like:

`.\Build.ps1 -InstallAndTestModule`

All this does is copy the current realease you have built (based on the current version in version.txt) and copy/replace any existing module found in:
`$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules\`

If the module path is already found the build script will attempt to confirm overwriting it. Then it tries to load that version of the module. If you have multiple versions installed in multiple locations you may not get accurate results so be cognizant of this (the location and version of the module is displayed in the output for further investigation).

You can combine the build with the install and test of the module if you so desire:

`.\Build.ps1 -BuildModule -InstallAndTestModule`


### Step 5 - Setup A PowerShell Gallery Profile (Optional)
If you have plans to upload your module to the PowerShell Gallery then this build script can help automate the process a bit. But first you will need to create a local profile file with the following command:

`.\Build.ps1 -CreatePSGalleryProfile`

The command is a bit of a misnomer as all it will do is create a local file which will be parsed when uploading to the PowerShell gallery site. You still need to create an account and attain an API key from the PowerShell Gallery [website](https://www.powershellgallery.com/).

Once you have attained your API key you will need to save a copy of it within your powershell profile (it would be silly to keep it in your project folder that may get shared with others or accidentally uploaded for public consumption). Run the following to create the correct file for pasting your key into.

`notepad (Join-Path (Split-Path $profile) 'psgalleryapi.txt')`

Now when you are ready to upload to the psgallery simply run the following:
`.\Build.ps1 -UploadPSGallery -ReleaseNotes 'First Upload'

Assuming you have a valid NugetAPI key in the psgalleryapi.txt file in your profile this build step will automatically update the the .psgallery file with any relevant tags/uris from your manifest file and upload the release directory module to the PowerShell Gallery for you.

**Note:** *I've not figured out yet how to reset versions when uploading to the gallery. You always have to upload a newer version than what is already there so be extra certain you are ready to publish the module before doing this step.*

### Step 6 - Start Your Next Release
~~When you have finally uploaded your current release to github the version number will go up by 1 in the minor version release portion (so 0.0.1 will become 0.0.2).~~ (<--Not implemented yet)

To start working on your next release (or roll back to a prior release) you will need to update the version.txt file within your project directory. But if you go to build the current module again it will poop out as the version release in this file does not match the version found in your module manifest file. This is by design. In order to confirm you are ready to start working on this release you need to run the following.

`.\Build.ps1 -UpdateRelease`

**Note:** *This will spit out an error as we are running the Version task in safe mode and looking for an error. This lets us reuse the task that we use for loading the version number. If the final build shows as succeeded you have nothing to worry about though.*

Once this has been done you can proceed to build your module again:

`.\Build.ps1`

## Examples
I started this little framework as a build script for [one of my projects](https://github.com/zloeber/FormatPowershellCode) so you can see it in action there if you like. I've since taken that code, made it a bit more generic, and added an initialization routine for new projects. As an exercise I adapted [another older project](https://github.com/zloeber/NLogModule) to use this build script as well. So this framework does work for me but you might need to do some tweaking to get it working for your own project but keep in mind that any module that exports more than functions will take additional work. (See the notes below to better understand why.)

## Notes
- I'm keep any function documentation within the comment based help for the function. The build process uses PlatyPS to generate the relevant help files and will fail if "{{ blah blah blah }}" is found to have been created in the output files (as these are meant to be replaced manually for any information PlatyPS is unable to locate). The CBH for each function gets replaced with the generated module documentation link. I base this replacement code on '.SYNOPSIS' existing in the comment based help. This is done in the following task:
```
task UpdateCBH -Before CreateModulePSM1 {
    $CBHPattern = "(?ms)(\<#.*\.SYNOPSIS.*?#>)"
    Get-ChildItem -Path "$($ScratchPath)\$($PublicFunctionSource)\*.ps1" -File | ForEach {
            $FormattedOutFile = $_.FullName
            Write-Output "      Replacing CBH in file: $($FormattedOutFile)"
            $UpdatedFile = (get-content  $FormattedOutFile -raw) -replace $CBHPattern, $ExternalHelp
            $UpdatedFile | Out-File -FilePath $FormattedOutFile -force -Encoding:utf8
     }
}
```

As you might expect this will remove the entire CBH block which may or may not be what you want in your final release (Update: I've included code to also include the external link based on the version release directory and module website).
- I recreate the documentation markdown files every time I run the build. This includes the module landing page. PlatyPS doesn't seem to automatically pull in function description information (or I'm missing something in the usage of this module) so I do so within another task behind the scenes.
- I use PowerShellGet for module installation in the configuration task. This necessitates PowerShell 5 as far as I know.
- The root module files are my development files which are hosted in github. The release files are hosted in github as well. So someone can still simply pull the whole directory structure and install the module that way I suppose.
- There are two special files in the src\other directory:

 1. PreLoad.ps1 is dot sourced at the beginning of the module (and in the build it is the first file to populate the final combined psm1 file).
 2. PostLoad.ps1 is dot sourced at the end of the module (and is the last file to populate the final combined psm1 file).

 This is meant to help a little with some difference scenarios and could easily be expanded upon (perhaps a different file for exported variables and aliases that are AST parsed and converted into the correct replacements in the final psd1 file?)
- If you are exporting more than just functions (variables, aliases, et cetera) go ahead and put them in your PostLoad.ps1 file with your Export-ModuleMember command. Just remember that the moment you use Export-ModuleMember it will become the dominant preference for exporting functions as well! So ensure you also specify the functions to export when using this command. In this regard maybe think of your manifest file as a filter whenever you use the export-modulemember command but as the actual definition for what gets exported when no export-modulemember command is found ~~(and note that this behavior is ONLY for functions, what a nonsensical design decision...)~~ <-- this does not appear to be the case on my machine, anything that gets exported with the export-modulemember command seems to get exported regardless of what is in the manifest!
- A default skeleton for the module about help txt file is created in a default en-US directory. This file should be updated with a real life example of how to use the module.
- I include a set of scripts in the build\dotsource directory that get used in various build tasks. If you want to add another script and task just beware that the scope of the functions are manually defined at the script level so that they remain available to other tasks after the task that dot sources them is completed. It's weird but, hey... at least I'm not using global scoping anywhere right?
- I found out a bit after the fact that Publish-Module will pretty much fully use the data found in the psd1 file for information published to the gallery. I'm pretty certain that anything within this file will overwrite anything that gets sent as a parameter. That said, it will bomb out if any of your tags in the psd1 file have spaces in them....joy.

##Some Missing Stuff
- I need to get pester testing and git pushing finished up. The tasks are there for the git stuff but nothing has been done for Pester yet (shame on me).
- I need to add a verbosity setting for instances where a build fails due to PlatyPS for easier isolation of CBH conversion issues.
- I need to implement a better logging to file mechanism.
- Probably should strip out full paths from the various on screen output to be more 'build-like' (or at least set an option to do so)
- I need to probably figure out a way to update the build script on an already deployed module.
- I really should deploy the current version of invoke-build with this script instead of depending on PowerShellGet (in case a newer version breaks things). I should actually do that for all the modules used in this project...


##Credits
[Invoke-Build](https://github.com/nightroman/Invoke-Build) - A kick ass build automation tool written in PowerShell. It is the primary engine behind this little project.

[Haroopad](http://pad.haroopress.com/) - Sweet Markdown Editor.

[PowerShell Practice and Style](https://github.com/PoshCode/PowerShellPracticeAndStyle) - Great site to read over to learn everything you are needing to do to up your game in PowerShell.




