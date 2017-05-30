$CustomPlasterModulePath = '.\plaster\PlasterModule\Plaster.psd1'
$PSModuleBuildPlasterManifest = '.\plaster\PSModuleBuild\'

if (get-module Plaster) {
    Write-Output 'Removing already loaded version of Plaster as we need to use our custom version instead..'
    Remove-Module Plaster -Force
    $PlasterWasLoaded = $true
}

try {
    Import-Module $CustomPlasterModulePath
}
catch {
    throw 'You need the custom plaster module to build this plaster manifest.'
}

$PlasterResults = invoke-plaster $PSModuleBuildPlasterManifest -NoLogo -PassThru

if ($PlasterWasLoaded) {
    Write-Output 'Attempting to reimport the Plaster module that we unloaded earlier..'
    Import-Module Plaster -ErrorAction:SilentlyContinue
}

Write-Output ''

Write-Output "Your new PowerShell project scaffolding has been created in $($PlasterResults.DestinationPath)"
Write-Output "You should populate your src\public folder with all the exportable functions for your module then run the Build.ps1 wrapper to test things out."