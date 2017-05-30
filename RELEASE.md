# PSModuleBuild Release Notes

This is a set of build tasks for kicking off a PowerShell module project and building regular releases of the project.

##Site
[PSModuleBuild Project Site](https://www.github.com/zloeber/PSModuleBuild)

##Release Notes
**05/30/2017**
-Converted entire project into a plaster template
-Added ReadTheDocs build integration
-Updated documentation
-More stuff

**03/28/2017**
- Fixed some project initialization issues
- Converted BuildEnv to be a full psobject across all the build scripts (instead of an ugly hash)
- Fixed up the Pester module manifest check script (not being used in the build... yet!)
- Rolled the version checking directly into the buildenv settings instead of the version.txt file.
- Added ability to initialize project from existing manifest file (as long as the file isn't in the same project path)

**03/06/2017**
- Changed configuration file to json for easier manual editing
- Several output fixes
- Removed FormatCode options
- Eliminated .psagallary.xml profile settings in favor of simply using the manifest file for uploading to the gallary
- Update to initialization script
- Check for module name validity for PlatyPS compatibility
- Many other smaller changes.