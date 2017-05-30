# PSModuleBuild Configuration
Each project has a psmodulebuild configuration file that will get dot sourced into the build engine. This file will, in turn, pull in settings from a json file in the same directory.

**build\<modulename>.buildenvironment.ps1** - The initial dot sourced configuration script for your project
**build\<modulename>.buildenvironment.json** - This gets automatically updated after a first run of the build and will forever after be the single source of truth moving forward for your build settings (unless you run the prior buildenvironment.ps1 script with the -ForcePersist option or update the 'FirstRun' option to be $true).
