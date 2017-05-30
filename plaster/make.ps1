# Make the plaster template manifest file for this project.
$PSModuleBuildPath = '.\PSModuleBuild\plasterManifest.xml'

Write-Output 'Creating the plaster manifest file for this project...'

# First ensure that our custom version of Plaster is loaded
try {
    Remove-Module Plaster -ErrorAction:SilentlyContinue
    Import-Module '.\PlasterModule\Plaster.psd1'
}
catch {
    throw 'You need the plaster module to build this plaster manifest.'
}

# Load our parameter and content
. .\PlasterParams.ps1
. .\PlasterContent.ps1

$version = (git describe --match "v[0-9]*") -replace 'v',''
if ($null -eq $version) {$version = '0.0.1'}

$params = @{
    Path = $PSModuleBuildPath
    TemplateName = 'PSModuleBuild'
    TemplateVersion = $version
    Author = 'Zachary Loeber'
    Description = 'Create a new PowerShell Module with a PSModuleBuild wrapper'
    Tags = 'Module, ModuleManifest, PSModuleBuild'
    Title = 'New PSModuleBuild Project'
    TemplateType = 'Project'
    Content = $Content | Write-PlasterManifestContent
    Parameters = $Parameters | Write-PlasterParameter
}

# Create the initial manifest
New-PlasterManifest @params

try {
    $null = Test-PlasterManifest .\PSModuleBuild\plasterManifest.xml
    Write-Output 'The new plaster manifest for PSModuleBuild has been created in .\PSModuleBuild\plasterManifest.xml'
}
catch {
    Test-PlasterManifest .\PSModuleBuild\plasterManifest.xml -verbose
}

<# Example Usage
import-module .\PlasterModule\Plaster.psd1 -force
remove-item 'C:\temp\mytestmodule' -recurse -force -erroraction:silentlycontinue
invoke-plaster .\PSModuleBuild\ -ProjectLicense:CreativeCommons -NoLogo -DestinationPath 'C:\temp\mytestmodule' -ModuleName 'MytestModule' -ModuleDescription 'My Test Module' -ModuleAuthor 'Zachary Loeber' -ModuleWebsite 'https://www.github.com/zloeber/mytestmodule' -ModuleVersion '0.0.1' -ModuleTags 'my, test, module' -OptionAnalyzeCode:True -OptionCombineFiles:True -OptionSanitizeSensitiveTerms:True
#>