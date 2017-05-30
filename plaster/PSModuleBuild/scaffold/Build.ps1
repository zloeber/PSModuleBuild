#Requires -Version 5
[CmdletBinding(DefaultParameterSetName='Build')]
param (
    [parameter(Position=0, ParameterSetName='Build')]
    [switch]$BuildModule,
    [parameter(Position=1, ParameterSetName='Build')]
    [switch]$UpdateRelease,
    [parameter(Position=2, ParameterSetName='Build')]
    [switch]$UploadPSGallery,
    [parameter(Position=3, ParameterSetName='Build')]
    [switch]$GitCheckin,
    [parameter(Position=4, ParameterSetName='Build')]
    [switch]$GitPush,
    [parameter(Position=5, ParameterSetName='Build')]
    [switch]$InstallAndTestModule,
    [parameter(Position=6, ParameterSetName='Build')]
    [version]$NewVersion,
    [parameter(Position=7, ParameterSetName='CBH')]
    [switch]$InsertCBH
)

$BuildFile = ".\build\<%=$PLASTER_PARAM_ModuleName%>.buildenvironment.ps1"

function PrerequisitesLoaded {
    # Install InvokeBuild module if it doesn't already exist
    try {
        if ((get-module InvokeBuild -ListAvailable) -eq $null) {
            Write-Host "Attempting to install the InvokeBuild module..."
            $null = Install-Module InvokeBuild -Scope:CurrentUser
        }
        if (get-module InvokeBuild -ListAvailable) {
            Write-Host -NoNewLine "Importing InvokeBuild module"
            Import-Module InvokeBuild -Force
            Write-Host -ForegroundColor Green '...Loaded!'
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}

function CleanUp {
    try {
        Write-Output ''
        Write-Output 'Attempting to clean up the session (loaded modules and such)...'
        Invoke-Build -File $BuildFile -Task BuildSessionCleanup
        Remove-Module InvokeBuild
    }
    catch {}
}

if (-not (PrerequisitesLoaded)) {
    throw 'Unable to load InvokeBuild!'
}

switch ($psCmdlet.ParameterSetName) {
    'CBH' {
        if ($InsertCBH) {
            try {
                Invoke-Build -File $BuildFile -Task InsertMissingCBH
            }
            catch {
                throw
            }
        }

        CleanUp
    }
    'Build' {
        # Update your release version?
        if ($UpdateRelease) {
            if ($NewVersion -ne $null) {
                $NewVersion.ToString() | Out-File -FilePath .\version.txt -Force
            }

            try {
                Invoke-Build -File $BuildFile -Task UpdateVersion
            }
            catch {
                throw
            }
        }

        # If no parameters were specified or the build action was manually specified then kick off a standard build
        if (($psboundparameters.count -eq 0) -or ($BuildModule))  {
            try {
                Invoke-Build
            }
            catch {
                Write-Output 'Build Failed with the following error:'
                Write-Output $_
            }
        }

        # Install and test the module?
        if ($InstallAndTestModule) {
            try {
                Invoke-Build -File $BuildFile -Task InstallAndTestModule
            }
            catch {
                Write-Output 'Install and test of module failed:'
                Write-Output $_
            }
        }

        # Upload to gallery?
        if ($UploadPSGallery) {
            try {
                Invoke-Build -File $BuildFile -Task PublishPSGallery
            }
            catch {
                throw 'Unable to upload project to the PowerShell Gallery!'
            }
        }

        # Not implemented yet
        if ($GitCheckin) {
            # Finish me
        }

        # Not implemented yet
        if ($GitPush) {
            # Finish me
        }

        CleanUp
    }
}
