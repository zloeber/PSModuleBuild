# PSModuleBuild

PSModulebuild is a scaffolding framework which can be used to kickstart a generic PowerShell module project. It includes the base files and scripts required to perform regular build releases, uploading to the powershell gallery, and other such fun. All the hard work is done with the excellent invoke-build project engine, a rather large set of build tasks for it, and a custom Plaster template.

## Site
[PSModuleBuild Project Site](https://www.github.com/zloeber/PSModuleBuild)

## Examples
I started this little framework as a build script for [one of my projects](https://github.com/zloeber/FormatPowershellCode) so you can see it in action there if you like. I've since taken that code, made it a bit more generic, and added an initialization routine for new projects. As an exercise I adapted [another older project](https://github.com/zloeber/NLogModule) to use this build script as well. So this framework does work for me but you might need to do some tweaking to get it working for your own project but keep in mind that any module that exports more than functions will take additional work. (See the notes below to better understand why.)

## Credits
[Invoke-Build](https://github.com/nightroman/Invoke-Build) - A kick ass build automation tool written in PowerShell. It is the primary engine behind this little project.

[Plaster](https://github.com/PowerShell/Plaster) - Used for the code scaffolding portion of this project.

[Haroopad](http://pad.haroopress.com/) - Sweet Markdown Editor.

[Hitchhikers Guide to the PowerShell Pipeline](https://xainey.github.io/2017/powershell-module-pipeline/)

[Write the Faq'n Manual](https://get-powershellblog.blogspot.com/2017/03/write-faq-n-manual-part1.html)

[PowerShell Practice and Style](https://github.com/PoshCode/PowerShellPracticeAndStyle) - Great site to read over to learn everything you are needing to do to up your game in PowerShell.