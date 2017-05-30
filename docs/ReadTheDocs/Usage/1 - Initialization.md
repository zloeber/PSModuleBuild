# Step 1 - Initialization
Simply download this project and run the Initialize.ps1 script. You will be prompted for a destination folder and the rest of the project settings. The destination folder will be the home of your future project but is completely portable. This is simply a wrapper for a custom version of Plaster that calls a template file I created for the project. It is fairly simple to deconstruct and use plaster directly via invoke-plaster and pass all the parameters via command line if desired.

`.\Initialize.ps1`

Once this has been kicked off and all answers have been entered the initialization of your new project directory will start. Several template files are copied out to appropriate locations. Additionally, the default module manifest file gets created.