#Requires -Version 5
param(
    [string]$GithubRepo
)

$GitHubRepoParam = @{}

if (-not [string]::IsNullOrEmpty($GithubRepo)) {
        $GitHubRepoParam.GithubRepo = $GithubRepo
}
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

# Kick off the new module scaffolding creation process build
try {
    Invoke-Build -File .createframework.ps1 @GitHubRepoParam

    # Ensure we cannot run this initialization process again
	Remove-item .\.createframework.ps1 -Force

    Write-Host ''
    Write-Host -ForegroundColor:DarkYellow 'The new module framework has been created. You still need to populate your private and public functions to have anything meaningful.'
    Write-Host -ForegroundColor:DarkYellow 'Once you are ready to build a release simply run the build.ps1 file in this directory. For more tasks (like publishing to the powershell gallery) please view the readme for this project at https://github.com/zloeber/PSModuleBuild'
    Write-Host ''
    Write-Host -ForegroundColor:Cyan 'Note: To prevent accidents you can only ever run this initial process once. The original .createframework.ps1 build file has been deleted. Go ahead and delete Initialize.ps1 now to clean up your project directory and complete this process.'
}
catch {
    # If it fails then show the error
    Write-Host -ForegroundColor Red 'Build Failed with the following error:'
    Write-Output $_
}
finally {
    #  Try to clean up the environment
    Write-Host ''
    Write-Host 'Attempting to clean up the session (loaded modules and such)...'
    Remove-Module InvokeBuild
}