#Requires -Version 5
param (
    [switch]$CreatePSGalleryProfile,
    [switch]$UpdateRelease,
    [switch]$UploadPSGallery,
    [switch]$GitCheckin,
    [switch]$GitPush,
    [string]$ReleaseNotes
)
<#
	Build script using Invoke-Build (https://github.com/nightroman/Invoke-Build)
#>

# Install InvokeBuild module if it doesn't already exist
if ((get-module InvokeBuild -ListAvailable) -eq $null) {
    Write-Host -NoNewLine "      Installing InvokeBuild module"
    $null = Install-Module InvokeBuild
    Write-Host -ForegroundColor Green '...Installed!'
}
if (get-module InvokeBuild -ListAvailable) {
    Write-Host -NoNewLine "      Importing InvokeBuild module"
    Import-Module InvokeBuild -Force
    Write-Host -ForegroundColor Green '...Loaded!'
}
else {
    throw 'How did you even get here?'
}

if ($CreatePSGalleryProfile) {
    try {
        Invoke-Build NewPSGalleryProfile
    }
    catch {
        throw 'Unable to create the .psgallery profile file!'
    }
}

if ($UpdateRelease) {

}

if ($UploadPSGallery) {
    if ([string]::IsNullOrEmpty($ReleaseNotes)) {
        throw '$ReleaseNotes needs to be specified to run this operation!'
    }
    try {
        Invoke-Build PublishPSGallery -ReleaseNotes $ReleaseNotes
    }
    catch {
        throw 'Unable to upload projec to the PowerShell Gallery!'
    }
}

if ($GitCheckin) {

}

if ($GitPush) {

}

# If no parameters were specified then kick off a standard build
if ($psboundparameters.count -eq 0) {
    try {
        Invoke-Build
    }
    catch {
        # If it fails then show the error and try to clean up the environment
        Write-Host -ForegroundColor Red 'Build Failed with the following error:'
        Write-Output $_
    }
}

Write-Host ''
Write-Host 'Attempting to clean up the session (loaded modules and such)...'
Invoke-Build BuildSessionCleanup
Remove-Module InvokeBuild
