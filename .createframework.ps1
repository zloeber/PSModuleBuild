param(
    [string]$GithubRepo
)

task UpdateBuildEnvironment {
    Write-Host -ForegroundColor Yellow 'Please update this environmental variable to reflect your module needs before moving forward!'
    notepad .\build\.buildenvironment.ps1
    Write-Host -ForegroundColor Yellow  'After you have made your changes and saved them please continue on...'
    pause
}

task CreateModuleFramework {
    # Dot source our environment variables
    if (Test-Path '.\build\.buildenvironment.ps1') {
        . '.\build\.buildenvironment.ps1'
    }
    else {
        Write-Error "Without a build environment file we are at a loss as to what to do!"
    }
    
    Write-Host -NoNewLine "      Moving over the static files to start creating the module framework"
    $null = Copy-Item .\build\templates\version.txt .\
    $null = Copy-Item .\build\templates\Build.ps1 .\
    $null = Copy-Item .\build\templates\ModuleName.psm1 ".\$($ModuleToBuild).psm1"
    $null = Copy-Item .\build\templates\.build.ps1 .\
    Write-Host -ForegroundColor Green '...Done!'
}

task CreateInstallScript {
     # Dot source our environment variables
    if (Test-Path '.\build\.buildenvironment.ps1') {
        . '.\build\.buildenvironment.ps1'
    }
    else {
        Write-Error "Without a build environment file we are at a loss as to what to do!"
    }

    Write-Host -NoNewLine "      Creating install script for the project"
    (Get-Content -Raw .\build\templates\Install.ps1) `
        -replace '{{ModuleName}}',$ModuleToBuild `
        -replace '{{ModuleWebsite}}',$ModuleWebsite | Out-File ".\Install.ps1" -Force -Encoding:utf8
    Write-Host -ForegroundColor Green '...Done!' 
}

task CreateModuleManifest {
    # Dot source our environment variables
    if (Test-Path '.\build\.buildenvironment.ps1') {
        . '.\build\.buildenvironment.ps1'
    }
    else {
        Write-Error "Without a build environment file we are at a loss as to what to do!"
    }

    Write-Host -NoNewLine "      Creating an initial module manifest for the project"
    . .\build\dotsource\Convert-ArrayToString.ps1

    (Get-Content -Raw .\build\templates\ModuleName.psd1) `
        -replace '{{ModuleName}}',$ModuleToBuild `
        -replace '{{ModuleTags}}',(Convert-ArrayToString $ModuleTags) `
        -replace '{{ModuleWebsite}}',$ModuleWebsite `
        -replace '{{ModuleDescription}}', $ModuleDescription `
        -replace '{{ModuleAuthor}}', $ModuleAuthor `
        -replace '{{Date}}',(get-date).ToString() `
        -replace '{{RandomGUID}}',([guid]::NewGuid()).Guid | Out-File ".\$($ModuleToBuild).psd1" -Force -Encoding:utf8
    Write-Host -ForegroundColor Green '...Done!' 
}

task CreateModuleAboutHelp {
    # Dot source our environment variables
    if (Test-Path '.\build\.buildenvironment.ps1') {
        . '.\build\.buildenvironment.ps1'
    }
    else {
        Write-Error "Without a build environment file we are at a loss as to what to do!"
    }
    
    Write-Host -NoNewLine '      Creating base about help txt file and directory'
    $null = New-Item -Type:Directory -Name 'en-US' -Path .\ -Force
    (Get-Content -Raw .\build\templates\about_ModuleName.help.txt) `
        -replace '{{ModuleName}}',$ModuleToBuild `
        -replace '{{ModuleDescription}}', $ModuleDescription `
        -replace '{{Tags}}',($ModuleTags -join ',') `
        -replace '{{HelpLink}}',$ModuleWebsite | Out-File ".\en-US\about_$($ModuleToBuild).help.txt" -Force -Encoding:utf8
    Write-Host -ForegroundColor Green '...Done!' 
}

task CreateReadme {
    Write-Host -NoNewLine '      Creating initial readme.md'
    (Get-Content -Raw .\build\templates\readme.md) `
        -replace '{{ModuleName}}', $ModuleToBuild `
        -replace '{{ModuleDescription}}', $ModuleDescription `
        -replace '{{ModuleAuthor}}', $ModuleAuthor `
        -replace '{{ModuleWebsite}}', $ModuleWebsite | Out-File ".\readme.md"
    Write-Host -ForegroundColor Green '...Done!' 
}

task CreateGitRepo {
    # Dot source our environment variables
    if (Test-Path '.\build\.buildenvironment.ps1') {
        . '.\build\.buildenvironment.ps1'
    }
    else {
        Write-Error "Without a build environment file we are at a loss as to what to do!"
    }
    
    # Validate git.exe requirement is met
    try {
        $null = Get-Command -Name 'git.exe' -ErrorAction:Stop
    }
    catch {
        throw 'Git.exe not found in path!'
    }

    exec { git init }
    exec { git add . }
    exec { git commit -m 'First Commit' }
}

task UploadToGithub -if (-not [string]::IsNullOrEmpty($GithubRepo)) {
    exec { git remote add origin $GithubRepo }
    exec { git remote -v }
    exec { git push origin master }
}

task . UpdateBuildEnvironment, CreateModuleFramework, CreateInstallScript, CreateReadme, CreateModuleManifest, CreateModuleAboutHelp, CreateGitRepo, UploadToGithub