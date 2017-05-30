$BuildFile = ".\build\<%=$PLASTER_PARAM_ModuleName%>.buildenvironment.ps1"
if (Test-Path $BuildFile) {
    . $BuildFile
}
else {
    Write-Error "Without a build environment file we are at a loss as to what to do!"
}

# These are required for a full build process and will be automatically installed if they aren't available
$RequiredModules = @('PlatyPS','Pester')

# Some optional modules
if  ($Script:BuildEnv.OptionAnalyzeCode) {
    $RequiredModules += 'PSScriptAnalyzer'
}

if  ($Script:BuildEnv.OptionMKDocs) {
    $RequiredModules += 'Powershell-YAML'
}

# You really shouldn't change this for a powershell module (if you want it to publish to the psgallery correctly)
$CurrentReleaseFolder = $Script:BuildEnv.ModuleToBuild

# Put together our full paths. Generally leave these alone
$ModuleFullPath = (Get-Item "$($Script:BuildEnv.ModuleToBuild).psm1").FullName
$ModuleManifestFullPath = (Get-Item "$($Script:BuildEnv.ModuleToBuild).psd1").FullName
$ScriptRoot = Split-Path $ModuleFullPath
$BuildDocsPath = Join-Path $ScriptRoot "$($Script:BuildEnv.BuildToolFolder)\docs\"
$ScratchPath = Join-Path $ScriptRoot $Script:BuildEnv.ScratchFolder
$ReleasePath = Join-Path $ScriptRoot $Script:BuildEnv.BaseReleaseFolder
$CurrentReleasePath = Join-Path $ReleasePath $CurrentReleaseFolder
# Just before releasing the module we stage some changes in this location.
$StageReleasePath = Join-Path $ScratchPath $Script:BuildEnv.BaseReleaseFolder
$ReleaseModule = "$($StageReleasePath)\$($Script:BuildEnv.ModuleToBuild).psm1"

# Additional build scripts and tools are found here (note that any dot sourced functions must be scoped at the script level)
$BuildToolPath = Join-Path $ScriptRoot $Script:BuildEnv.BuildToolFolder

# Used later to determine if we are in a configured state or not
$IsConfigured = $False

# Used to update our function CBH to external help reference
$ExternalHelp = @"
<#
    .EXTERNALHELP $($Script:BuildEnv.ModuleToBuild)-help.xml
    .LINK
        {{LINK}}
    #>
"@

if ($Script:BuildEnv.OptionTranscriptEnabled) {
    Write-Output 'Transcript logging: TRUE'
    $TranscriptLog = Join-Path $BuildToolPath $Script:BuildEnv.OptionTranscriptLogFile
    Write-Output "TranscriptLog: $($TranscriptLog)"
    Start-Transcript -Path $TranscriptLog -Append -WarningAction:SilentlyContinue
}

#Synopsis: Validate system requirements are met
task ValidateRequirements {
    Write-Host -NoNewLine '      Running Powershell version 5?'
    assert ($PSVersionTable.PSVersion.Major.ToString() -eq '5') 'Powershell 5 is required for this build to function properly (you can comment this assert out if you are able to work around this requirement)'
    Write-Host -ForegroundColor Green '...Yup!'
}

#Synopsis: Load required modules if available. Otherwise try to install, then load it.
task LoadRequiredModules {
    $RequiredModules | Foreach-Object {
        if ((get-module $_ -ListAvailable) -eq $null) {
            Write-Host -NoNewLine "      Installing $($_) Module"
            $null = Install-Module $_
            Write-Host -ForegroundColor Green '...Installed!'
        }
        if (get-module $_ -ListAvailable) {
            Write-Host -NoNewLine "      Importing $($_) Module"
            Import-Module $_ -Force
            Write-Host -ForegroundColor Green '...Loaded!'
        }
        else {
            throw 'How did you even get here?'
        }
    }
}

#Synopsis: Load dot sourced functions into this build session
task LoadBuildTools {
    # Dot source any build script functions we need to use
    Get-ChildItem $BuildToolPath/dotSource -Recurse -Filter "*.ps1" -File | ForEach-Object {
        Write-Output "      Dot sourcing script file: $($_.Name)"
        . $_.FullName
    }
}

# Synopsis: Create new module manifest
task CreateModuleManifest -After CreateModulePSM1 {
    $PSD1OutputFile = "$($StageReleasePath)\$($Script:BuildEnv.ModuleToBuild).psd1"
    $ThisPSD1OutputFile = ".\$($Script:BuildEnv.ScratchFolder)\$($Script:BuildEnv.BaseReleaseFolder)\$($Script:BuildEnv.ModuleToBuild).psd1"
    Write-Host -NoNewLine "      Attempting to update the release module manifest file:  $ThisPSD1OutputFile"
    $null = Copy-Item -Path $ModuleManifestFullPath -Destination $PSD1OutputFile -Force
    Update-ModuleManifest -Path $PSD1OutputFile -FunctionsToExport $Script:FunctionsToExport
    Write-Host -ForegroundColor Green '...Updated!'
}

# Synopsis: Load the module project
task LoadModule {
    Write-Host -NoNewLine '      Attempting to load the project module.'
    try {
        $Script:Module = Import-Module $ModuleFullPath -Force -PassThru
        Write-Host -ForegroundColor Green '...Loaded!'
    }
    catch {
        throw "Unable to load the project module: $($ModuleFullPath)"
    }
}

# Synopsis: Import the current module manifest file for processing
task LoadModuleManifest {
    assert (test-path $ModuleManifestFullPath) "Unable to locate the module manifest file: $ModuleManifestFullPath"
    Write-Host -NoNewLine '      Loading the existing module manifest for this module'
    $Script:Manifest = Test-ModuleManifest -Path $ModuleManifestFullPath
    Write-Host -ForegroundColor Green '...Loaded!'
}

# Synopsis: Valiates there is no version mismatch.
task Version LoadModuleManifest, {
    Write-Host -NoNewLine '      Manifest version and the release version in the build configuration file are the same?'
    assert ( ($Script:Manifest).Version.ToString() -eq (($Script:BuildEnv.ModuleVersion))) "The module manifest version ( $(($Script:Manifest).Version.ToString()) ) and release version ($($Script:BuildEnv.ModuleVersion)) are mismatched. These must be the same before continuing. Consider running the UpdateVersion task to make the module manifest version the same as the release version."
    Write-Host -ForegroundColor Green '...Yup!'
}

#Synopsis: Validate script requirements are met, load required modules, load project manifest and module, and load additional build tools.
task Configure ValidateRequirements, LoadRequiredModules, LoadModuleManifest, LoadModule, Version, LoadBuildTools, {
    # If we made it this far then we are configured!
    $Script:IsConfigured = $True
    Write-Host -NoNewline '      Configure build environment'
    Write-Host -ForegroundColor Green '...configured!'
}

# Synopsis: Update current module manifest with the version defined in the build config file (if they differ)
task UpdateVersion LoadBuildTools, LoadModuleManifest, LoadModule, (job Version -Safe), {
    if (error Version) {
        do {
            $NewReleaseNotes = Read-Host -Prompt 'Enter brief release notes for this new version'
            if ([string]::IsNullOrEmpty($NewReleaseNotes)) {
                Write-Host -ForegroundColor:Red "You need to enter some kind of notes for your new release to update the manifest with!"
            }
        } while ([string]::IsNullOrEmpty($NewReleaseNotes))
        Update-ModuleManifest -Path $ModuleManifestFullPath -ModuleVersion $Script:BuildEnv.ModuleVersion -ReleaseNotes $NewReleaseNotes
    }
    else {
        Write-Error '      Module manifest version and version found in version.txt are already the same.'
    }
}

# Synopsis: Remove/regenerate scratch staging directory
task Clean {
    $null = Remove-Item $ScratchPath -Force -Recurse -ErrorAction 0
    $null = New-Item $ScratchPath -ItemType:Directory
    Write-Host -NoNewLine "      Clean up our scratch/staging directory at .\$($Script:BuildEnv.ScratchFolder)"
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Create base content tree in scratch staging area
task PrepareStage {
    # Create the directories
    $null = New-Item "$($ScratchPath)\src" -ItemType:Directory -Force
    $null = New-Item $StageReleasePath -ItemType:Directory -Force

    Copy-Item -Path "$($ScriptRoot)\*.psm1" -Destination $ScratchPath
    Copy-Item -Path "$($ScriptRoot)\*.psd1" -Destination $ScratchPath
    Copy-Item -Path "$($ScriptRoot)\$($Script:BuildEnv.PublicFunctionSource)" -Recurse -Destination "$($ScratchPath)\$($Script:BuildEnv.PublicFunctionSource)"
    Copy-Item -Path "$($ScriptRoot)\$($Script:BuildEnv.PrivateFunctionSource)" -Recurse -Destination "$($ScratchPath)\$($Script:BuildEnv.PrivateFunctionSource)"
    Copy-Item -Path "$($ScriptRoot)\$($Script:BuildEnv.OtherModuleSource)" -Recurse -Destination "$($ScratchPath)\$($Script:BuildEnv.OtherModuleSource)"
    Copy-Item -Path "$($ScriptRoot)\en-US" -Recurse -Destination $ScratchPath
    $Script:BuildEnv.AdditionalModulePaths | ForEach-Object {
        Copy-Item -Path $_ -Recurse -Destination $ScratchPath -Force
    }
}

# Synopsis: Update public functions to include a template comment based help.
task UpdateCBHtoScratch {
    $CBHPattern = "(?ms)(^\s*\<#.*\.SYNOPSIS.*?#>)"
    $CBHUpdates = 0

    # Create the directories
    $null = New-Item "$($ScratchPath)\src" -ItemType:Directory -Force
    $null = New-Item "$($ScratchPath)\$($Script:BuildEnv.PublicFunctionSource)" -ItemType:Directory -Force

    Write-Host "      Attempting to insert comment based help into functions (saving to our scratch directory only)."
    Get-ChildItem "$($ScriptRoot)\$($Script:BuildEnv.PublicFunctionSource)" -Filter *.ps1 | ForEach-Object {
        $FileName = $_.Name
        $FullFilePath = $_.FullName
        Write-Host "      Public function - $($FileName)"
        $currscript = Get-Content $FullFilePath -Raw
        $CBH = $currscript | New-CommentBasedHelp
        $currscriptblock = [scriptblock]::Create($currscript)
        . $currscriptblock
        $currfunct = get-command $CBH.FunctionName

        Write-Host -NoNewline "      ...Comment based help already exists: "
        if ($currfunct.definition -notmatch $CBHPattern) {
            $CBHUpdates++
            Write-Host -ForegroundColor Green "      FALSE!"
            Write-Host "      ...inserting template CBH and writing to : $($Script:BuildEnv.ScratchFolder)\$($Script:BuildEnv.PublicFunctionSource)\$($FileName)"
            $UpdatedFunct = 'Function ' + $currfunct.Name + ' {' + "`r`n" + $CBH.CBH + "`r`n" + $currfunct.definition + "`r`n" + '}'
            $UpdatedFunct | Out-File "$($ScratchPath)\$($Script:BuildEnv.PublicFunctionSource)\$($FileName)" -Encoding:utf8 -force
        }
        else {
            Write-Host -ForegroundColor Red "      TRUE!"
        }

        Remove-Item Function:\$($currfunct.Name)
    }
    Write-Host ''
    Write-Host -ForegroundColor Yellow '****************************************************************************************************'
    Write-Host -foregroundcolor Yellow "  Updated Functions: $CBHUpdates"
    if ($CBHUpdates -gt 0) {
        Write-Host ''
        Write-Host -foregroundcolor Yellow "  Updated Function Location: $($ScratchPath)\$($Script:BuildEnv.PublicFunctionSource)"
        Write-Host ''
        Write-Host -foregroundcolor Yellow "  NOTE: Please inspect these files closely. If they look good merge them back into your project"
    }
    Write-Host -ForegroundColor Yellow '****************************************************************************************************'
    $null = Read-Host 'Press Enter to continue...'
}

# Synopsis:  Collect a list of our public methods for later module manifest updates
task GetPublicFunctions {
    $Exported = @()
    Get-ChildItem "$($ScriptRoot)\$($Script:BuildEnv.PublicFunctionSource)" -Recurse -Filter "*.ps1" -File | Sort-Object Name | ForEach-Object {
        $Exported += ([System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Path $_.FullName -Raw), [ref]$null, [ref]$null)).FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) | ForEach-Object {$_.Name}
    }

    if ($Exported.Count -eq 0) {
        Write-Error 'There are no public functions to export!'
    }
    $Script:FunctionsToExport = $Exported
    Write-Host "      Number of exported functions found = $($Exported.Count)"
    Write-Host -NoNewLine '      Parsing for public (exported) function names'
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Assemble the module for release
task CreateModulePSM1 {
    if ($Script:BuildEnv.OptionCombineFiles) {
        $CombineFiles = ''
        $PreloadFilePath = (Join-Path $ScratchPath "$($Script:BuildEnv.OtherModuleSource)\PreLoad.ps1")
        if (Test-Path  $PreloadFilePath) {
            $CombineFiles += "## Pre-Loaded Module code ##`r`n`r`n"
            Write-Host "      Other Source Files: .\$($Script:BuildEnv.ScratchFolder)\$($Script:BuildEnv.OtherModuleSource)\PreLoad.ps1"
            Get-childitem $PreloadFilePath | ForEach-Object {
                Write-Host "             $($_.Name)"
                $CombineFiles += (Get-content $_ -Raw) + "`r`n`r`n"
            }
            Write-Host -NoNewLine "      Combining preload source"
            Write-Host -ForegroundColor Green '...Complete!'
        }

        $CombineFiles += "## PRIVATE MODULE FUNCTIONS AND DATA ##`r`n`r`n"
        Write-Host  "      Private Source Files: .\$($Script:BuildEnv.ScratchFolder)\$($Script:BuildEnv.PrivateFunctionSource)"
        Get-childitem  (Join-Path $ScratchPath "$($Script:BuildEnv.PrivateFunctionSource)\*.ps1") | ForEach-Object {
            Write-Host "             $($_.Name)"
            $CombineFiles += (Get-content $_ -Raw) + "`r`n`r`n"
        }
        Write-Host -NoNewLine "      Combining private source files"
        Write-Host -ForegroundColor Green '...Complete!'

        $CombineFiles += "## PUBLIC MODULE FUNCTIONS AND DATA ##`r`n`r`n"
        Write-Host  "      Public Source Files: $($Script:BuildEnv.PublicFunctionSource)"
        Get-childitem  (Join-Path $ScratchPath "$($Script:BuildEnv.PublicFunctionSource)\*.ps1") | ForEach-Object {
            Write-Host "             $($_.Name)"
            $CombineFiles += (Get-content $_ -Raw) + "`r`n`r`n"
        }
        Write-Host -NoNewline "      Combining public source files"
        Write-Host -ForegroundColor Green '...Complete!'
        $CombineFiles += "## Post-Load Module code ##`r`n`r`n"

        $PostLoadPath = (Join-Path $ScratchPath "$($Script:BuildEnv.OtherModuleSource)\PostLoad.ps1")
        if (Test-Path $PostLoadPath) {
            Write-Host "      Other Source Files: .\$($Script:BuildEnv.ScratchFolder)\$($Script:BuildEnv.OtherModuleSource)\PostLoad.ps1"
            Get-childitem  $PostLoadPath | ForEach-Object {
                Write-Host "             $($_.Name)"
                $CombineFiles += (Get-content $_ -Raw) + "`r`n`r`n"
            }
            Write-Host -NoNewLine "      Combining postload source"
            Write-Host -ForegroundColor Green '...Complete!'
        }

        Set-Content -Path $Script:ReleaseModule  -Value $CombineFiles -Encoding UTF8
        Write-Host -NoNewLine '      Combining module functions and data into one PSM1 file'
        Write-Host -ForegroundColor Green '...Complete!'
    }
    else {
        Copy-Item -Path (Join-Path $ScratchPath $Script:BuildEnv.OtherModuleSource) -Recurse -Destination $StageReleasePath -Force
        Copy-Item -Path (Join-Path $ScratchPath $Script:BuildEnv.PrivateFunctionSource) -Recurse -Destination $StageReleasePath -Force
        Copy-Item -Path (Join-Path $ScratchPath $Script:BuildEnv.PublicFunctionSource) -Recurse -Destination $StageReleasePath -Force
        Copy-Item -Path (Join-Path $ScratchPath $Script:BuildEnv.ModuleToBuild) -Destination $StageReleasePath -Force
        Write-Host -NoNewLine '      Copy over source and psm1 files'
        Write-Host -ForegroundColor Green '...Complete!'
    }

    $Script:BuildEnv.AdditionalModulePaths | ForEach-Object {
        Copy-Item -Path $_ -Recurse -Destination $StageReleasePath -Force
    }
}

# Synopsis: Removes script signatures before creating a combined PSM1 file
task RemoveScriptSignatures -Before CreateModulePSM1 {
    if ($Script:BuildEnv.OptionCombineFiles) {
        Write-Host -NoNewLine '      Remove script signatures from all files'
        Get-ChildItem -Path "$($ScratchPath)\$($Script:BuildEnv.BaseSourceFolder)" -Recurse -File | ForEach-Object {Remove-Signature -FilePath $_.FullName}
        Write-Host -ForegroundColor Green '...Complete!'
    }
}

# Synopsis: Warn about not empty git status if .git exists.
task GitStatus -If (Test-Path .git) {
    $status = exec { git status -s }
    if ($status) {
        Write-Warning "      Git status: $($status -join ', ')"
    }
}

# Synopsis: Generate a list of generic sensitive terms to search for when sanitizing the module code later.
task UpdateSensitiveTerms -If ($Script:BuildEnv.OptionSanitizeSensitiveTerms) {
    Write-Output "      Updating sensitive terms list with the current domain and user id"
    $Script:BuildEnv.OptionSensitiveTerms += $env:username
    $Script:BuildEnv.OptionSensitiveTerms += $env:userdomain
    $Script:BuildEnv.OptionSensitiveTerms += $env:userdnsdomain
    $Script:BuildEnv.OptionSensitiveTerms = @($Script:BuildEnv.OptionSensitiveTerms | Where-Object {-not [string]::IsNullOrEmpty($_)} | Select-Object -Unique)
}

# Synopsis: Validate that sensitive strings are not found in your code
task SanitizeCode -if {$Script:BuildEnv.OptionSanitizeSensitiveTerms} {
    ForEach ($Term in $Script:BuildEnv.OptionSensitiveTerms) {
        Write-Output "      Checking Files for sensitive string: $Term"
        $TermsFound = Get-ChildItem -Path $ScratchPath -Recurse -File | Where-Object {$_.FullName -notlike "$($StageReleasePath)*"} | Select-String -Pattern $Term
        if ($TermsFound.Count -gt 0) {
            Write-Output "        Sensitive string found in the following files:"
            $TermsFound | ForEach-Object {
                Write-Error "          $($_)"
            }
            Write-Error "Sensitive Terms found!"
        }
    }
}

# Synopsis: Replace comment based help with external help in all public functions for this project
task UpdateCBH -Before CreateModulePSM1 {
    $CBHPattern = "(?ms)(\<#.*\.SYNOPSIS.*?#>)"
    Get-ChildItem -Path "$($ScratchPath)\$($Script:BuildEnv.PublicFunctionSource)\*.ps1" -File | ForEach-Object {
        $FormattedOutFile = $_.FullName
        $FileName = $_.Name
        Write-Output "      Replacing CBH in file: $($FileName)"
        $FunctionName = $FileName -replace '.ps1',''
        $NewExternalHelp = $ExternalHelp -replace '{{LINK}}',($Script:BuildEnv.ModuleWebsite + "/tree/master/$($Script:BuildEnv.BaseReleaseFolder)/$($Script:BuildEnv.ModuleVersion)/docs/$($FunctionName).md")
        $UpdatedFile = (get-content  $FormattedOutFile -raw) -replace $CBHPattern, $NewExternalHelp
        $UpdatedFile | Out-File -FilePath $FormattedOutFile -force -Encoding:utf8
    }
}

# Synopsis: Run PSScriptAnalyzer against the assembled module
task AnalyzeScript -After CreateModulePSM1 -if {$Script:BuildEnv.OptionAnalyzeCode} {
    $Analysis = Invoke-ScriptAnalyzer -Path $StageReleasePath
    $AnalysisErrors = @($Analysis | Where-Object {@('Information','Warning') -notcontains $_.Severity})

    if ($AnalysisErrors.Count -ne 0) {
        Write-Host 'The following errors came up in the script analysis:'
        $AnalysisErrors
        Write-Host
        Write-Host "Note that this was from the script analysis run against $StageReleasePath"
        Prompt-ForBuildBreak -CustomError $AnalysisErrors
    }
}

# Synopsis: Build help files for module
task CreateHelp CreateMarkdownHelp, CreateExternalHelp, CreateUpdateableHelpCAB, {
    Write-Host -NoNewline '      Create help files'
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Add additional doc files to the final document folder (specifically the index.md and the changelog.md files)
task AddAdditionalDocFiles -After CreateHelp -if {Test-Path "$BuildDocsPath\Additional"} {
    Write-Host -NoNewLine "      Add additional doc files to the staging document folder ($StageReleasePath\docs) from $BuildDocsPath\Additional"
    Copy-Item -Filter '*.md' -Path "$BuildDocsPath\Additional" -Destination "$($StageReleasePath)\docs\" -Force
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Build ReadTheDocs yml file
task CreateReadTheDocsYML -After AddAdditionalDocFiles -if {$Script:BuildEnv.OptionGenerateReadTheDocs} {
    Write-Host -NoNewLine '      Create ReadTheDocs definition file and saving to the root project site.'
    # $DocsWebPath =  "$($Script:BuildEnv.ModuleWebsite)/$($Script:BuildEnv.BaseReleaseFolder)/$($CurrentReleaseFolder)"
    $ReadTheDocsPath = Join-Path $BuildDocsPath 'ReadTheDocs'
    $DocsReleasePath = "$($Script:BuildEnv.BaseReleaseFolder)/$($CurrentReleaseFolder)"
    $YMLFile = Join-Path $ScriptRoot 'mkdocs.yml'
    $Pages = @{}

    $RTDFolders = Get-ChildItem -Path $ReadTheDocsPath -Directory
    ForEach ($RTDFolder in $RTDFolders) {
        $NewSection = @()
        Copy-Item -Path $RTDFolder.FullName -Destination "$($StageReleasePath)\docs\" -Force -Recurse
        $RTDocs = @(Get-ChildItem -Path $RTDFolder.FullName -Filter '*.md')
        Foreach ($RTDDoc in $RTDocs) {
            $NewSection += @{$RTDDoc.Basename = "$($RTDFolder.Name)\$($RTDDoc.Name)"}
        }

        $Pages[$RTDFolder.Name] = $NewSection
    }


    # Store all the functions for its own readthedocs section
    $Functions = @()
    $Script:FunctionsToExport | ForEach-Object {
        $Functions += @{$_ = "$DocsReleasePath/docs/$_.md"}
    }
    $Pages.Functions = $Functions
    $RTD = @{
        site_name = "$($Script:BuildEnv.ModuleToBuild) Docs"
        repo_url = $Script:BuildEnv.ModuleWebsite
        site_author = $Script:BuildEnv.ModuleAuthor
        edit_uri = "edit/master/docs/"
        theme = "readthedocs"
        copyright = "$($Script:BuildEnv.ModuleToBuild) is licensed under the <a href='$($Script:BuildEnv.ModuleWebsite)/master/LICENSE.md'> license"
        Pages = $Pages
    }
    $RTD | ConvertTo-Yaml | Out-File -Encoding:utf8 -FilePath $YMLFile -Force
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Build help files for module and ignore missing section errors
task TestCreateHelp Configure, CreateMarkdownHelp, CreateExternalHelp, CreateUpdateableHelpCAB,  {
    Write-Host -NoNewLine '      Create help files'
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Build the markdown help files with PlatyPS
task CreateMarkdownHelp GetPublicFunctions, {
    # First copy over documentation
    Copy-Item -Path "$($ScratchPath)\en-US" -Recurse -Destination $StageReleasePath -Force

    $OnlineModuleLocation = "$($Script:BuildEnv.ModuleWebsite)/$($Script:BuildEnv.BaseReleaseFolder)"
    $FwLink = "$($OnlineModuleLocation)/$($CurrentReleaseFolder)/docs/$($Script:BuildEnv.ModuleToBuild).md"
    $ModulePage = "$($StageReleasePath)\docs\$($Script:BuildEnv.ModuleToBuild).md"

    # Create the .md files and the generic module page md as well
    $null = New-MarkdownHelp -module $Script:BuildEnv.ModuleToBuild -OutputFolder "$($StageReleasePath)\docs\" -Force -WithModulePage -Locale 'en-US' -FwLink $FwLink -HelpVersion $Script:BuildEnv.ModuleVersion

    # Replace each missing element we need for a proper generic module page .md file
    $ModulePageFileContent = Get-Content -raw $ModulePage
    $ModulePageFileContent = $ModulePageFileContent -replace '{{Manually Enter Description Here}}', $Script:Manifest.Description
    $Script:FunctionsToExport | Foreach-Object {
        Write-Host "      Updating definition for the following function: $($_)"
        $TextToReplace = "{{Manually Enter $($_) Description Here}}"
        $ReplacementText = (Get-Help -Detailed $_).Synopsis
        $ModulePageFileContent = $ModulePageFileContent -replace $TextToReplace, $ReplacementText
    }
    $ModulePageFileContent | Out-File $ModulePage -Force -Encoding:utf8

    $MissingDocumentation = Select-String -Path "$($StageReleasePath)\docs\*.md" -Pattern "({{.*}})"
    if ($MissingDocumentation.Count -gt 0) {
        Write-Host -ForegroundColor Yellow ''
        Write-Host -ForegroundColor Yellow '   The documentation that got generated resulted in missing sections which should be filled out.'
        Write-Host -ForegroundColor Yellow '   Please review the following sections in your comment based help, fill out missing information and rerun this build:'
        Write-Host -ForegroundColor Yellow '   (Note: This can happen if the .EXTERNALHELP CBH is defined for a function before running this build.)'
        Write-Host ''
        Write-Host -ForegroundColor Yellow "Path of files with issues: $($StageReleasePath)\docs\"
        Write-Host ''
        $MissingDocumentation | Select-Object FileName,Matches | Format-Table -auto
        Write-Host -ForegroundColor Yellow ''
        pause

        throw 'Missing documentation. Please review and rebuild.'
    }

    Write-Host -NoNewLine '      Creating markdown documentation with PlatyPS'
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Build the markdown help files with PlatyPS
task CreateExternalHelp {
    $PlatyPSVerbose = @{}
    if ($Script:BuildEnv.OptionRunPlatyPSVerbose) {
        $PlatyPSVerbose.Verbose = $true
    }
    Write-Host -NoNewLine '      Creating markdown help files'
    $null = New-ExternalHelp "$($StageReleasePath)\docs" -OutputPath "$($StageReleasePath)\en-US\" -Force @PlatyPSVerbose
    Write-Host -ForeGroundColor green '...Complete!'
}

# Synopsis: Build the help file CAB with PlatyPS
task CreateUpdateableHelpCAB {
    $PlatyPSVerbose = @{}
    if ($Script:BuildEnv.OptionRunPlatyPSVerbose) {
        $PlatyPSVerbose.Verbose = $true
    }
    Write-Host -NoNewLine "      Creating updateable help cab file"
    $LandingPage = "$($StageReleasePath)\docs\$($Script:BuildEnv.ModuleToBuild).md"
    $null = New-ExternalHelpCab -CabFilesFolder "$($StageReleasePath)\en-US\" -LandingPagePath $LandingPage -OutputFolder "$($StageReleasePath)\en-US\" @PlatyPSVerbose
    Write-Host -ForeGroundColor green '...Complete!'
}

# Synopsis: Create a new version release directory for our release and copy our contents to it
task PushVersionRelease {
    $ThisReleasePath = Join-Path $ReleasePath $Script:BuildEnv.ModuleVersion
    $ThisBuildReleasePath =  ".\$($Script:BuildEnv.BaseReleaseFolder)\$($Script:BuildEnv.ModuleVersion)"
    $null = Remove-Item $ThisReleasePath -Force -Recurse -ErrorAction 0
    $null = New-Item $ThisReleasePath -ItemType:Directory -Force
    Copy-Item -Path "$($StageReleasePath)\*" -Destination $ThisReleasePath -Recurse
    Out-Zip $StageReleasePath "$ReleasePath\$($Script:BuildEnv.ModuleToBuild)-$Version.zip" -overwrite
    Write-Host -NoNewLine "      Pushing a version release to $($ThisBuildReleasePath)"
    Write-Host -ForeGroundColor green '...Complete!'
}

# Synopsis: Create the current release directory and copy this build to it.
task PushCurrentRelease {
    $ThisBuildCurrentReleasePath =  ".\$($Script:BuildEnv.BaseReleaseFolder)\$($CurrentReleaseFolder)"
    $MostRecentRelease = (Get-ChildItem $ReleasePath -Directory | Where-Object {$_.Name -like "*.*.*"} | Select-Object Name).name | ForEach-Object {[version]$_} | Sort-Object -Descending | Select-Object -First 1
    $ProcessCurrentRelease = $true
    if ($MostRecentRelease){
        if ($MostRecentRelease -gt [version]$Script:BuildEnv.ModuleVersion) {
            $ProcessCurrentRelease = $false
        }
    }
    if ($ProcessCurrentRelease) {
        $null = Remove-Item $CurrentReleasePath -Force -Recurse -ErrorAction 0
        $null = New-Item $CurrentReleasePath -ItemType:Directory -Force
        Copy-Item -Path "$($StageReleasePath)\*" -Destination $CurrentReleasePath -Recurse -force
        Out-Zip $StageReleasePath "$ReleasePath\$($Script:BuildEnv.ModuleToBuild)-current.zip" -overwrite
        Write-Host -NoNewLine "      Pushing a version release to $($ThisBuildCurrentReleasePath)"
        Write-Host -ForeGroundColor green '...Complete!'
    }
    else {
        Write-Warning '      Unable to push this version as a current release as it is not the most recent version in the release directory!'
        Write-Host -NoNewLine "      Pushing a version release to $($CurrentReleasePath)"
        Write-Host -ForeGroundColor Yellow '...Not Done!'
    }
}

# Synopsis: Push with a version tag.
task GitPushRelease Version, {
    $changes = exec { git status --short }
    assert (-not $changes) "Please, commit changes."

    exec { git push }
    exec { git tag -a "v$($Script:BuildEnv.ModuleVersion)" -m "v$($Script:BuildEnv.ModuleVersion)" }
    exec { git push origin "v$($Script:BuildEnv.ModuleVersion)" }
}

# Synopsis: Push to github
task GithubPush Version, {
    exec { git add . }
    if ($ReleaseNotes -ne $null) {
        exec { git commit -m "$ReleaseNotes"}
    }
    else {
        exec { git commit -m "$($Script:BuildEnv.ModuleVersion)"}
    }
    exec { git push origin master }
    $changes = exec { git status --short }
    assert (-not $changes) "Please, commit changes."
}

# Synopsis: Push the project to PSScriptGallery
task PublishPSGallery LoadBuildTools, InstallModule, {
    if (Get-Module $Script:BuildEnv.ModuleToBuild) {
        # If the module is already loaded then unload it.
        Remove-Module $Script:BuildEnv.ModuleToBuild
    }

    # Try to import the module
    Import-Module -Name $Script:BuildEnv.ModuleToBuild

    Write-Host -NoNewLine "      Uploading project to PSGallery: $($Script:BuildEnv.ModuleToBuild)"
    Upload-ProjectToPSGallery -Name $Script:BuildEnv.ModuleToBuild -NuGetApiKey $Script:BuildEnv.NuGetApiKey -Verbose
    Write-Host -ForeGroundColor green '...Complete!'
}

# Synopsis: Remove session artifacts like loaded modules and variables
task BuildSessionCleanup {
    # Clean up loaded modules if they are loaded
    $RequiredModules | Foreach-Object {
        Write-Output "      Removing $($_) module (if loaded)."
        Remove-Module $_  -Erroraction Ignore
    }
    Write-Output "      Removing $($Script:BuildEnv.ModuleToBuild) module  (if loaded)."
    Remove-Module $Script:BuildEnv.ModuleToBuild -Erroraction Ignore

    # Dot source any post build cleanup scripts.
    Get-ChildItem $BuildToolPath/cleanup -Recurse -Filter "*.ps1" -File | Foreach {
        Write-Output "      Dot sourcing cleanup script file: $($_.Name)"
        . $_.FullName
    }
    if ($Script:BuildEnv.OptionTranscriptEnabled) {
        Stop-Transcript -WarningAction:Ignore
    }
}

# Synopsis: Install the current built module to the local machine
task InstallModule Version, {
    $CurrentModulePath = "$($Script:BuildEnv.BaseReleaseFolder)\$($Version)"
    Write-Host -NoNewLine "      Validating $($Script:BuildEnv.ModuleToBuild) (Version $($Version)) exists"
    assert (Test-Path $CurrentModulePath) 'The current version module has not been built yet!'
    Write-Host -ForeGroundColor green '...Found!'

    $MyModulePath = "$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules\"
    $ModuleInstallPath = "$($MyModulePath)$($Script:BuildEnv.ModuleToBuild)"
    if (Test-Path $ModuleInstallPath) {
        Write-Host -NoNewLine "      Removing installed module $($Script:BuildEnv.ModuleToBuild)"
        Remove-Item -Path $ModuleInstallPath -Confirm -Recurse
        assert (-not (Test-Path $ModuleInstallPath)) 'Module already installed and you opted not to remove it. Cancelling install operation!'
        Write-Host -ForeGroundColor green '...Done!'
    }

    Write-Host "      Installing current module:"
    Write-Host "         Source - $($CurrentModulePath)"
    Write-Host "         Destination - $($ModuleInstallPath)"
    Copy-Item -Path $CurrentModulePath -Destination $ModuleInstallPath -Recurse
}

# Synopsis: Test import the current module
task TestInstalledModule Version, {
    $InstalledModules = @(Get-Module -ListAvailable $Script:BuildEnv.ModuleToBuild)
    assert ($InstalledModules.Count -gt 0) 'Unable to find that the module is installed!'
    if ($InstalledModules.Count -gt 1) {
        Write-Warning 'There are multiple installed modules found for this project (shown below). Be aware that this may skew the test results: '
        Write-Host ''
        $InstalledModules | ForEach-Object {
            Write-Host -foregroundcolor yellow "      $($_.ModuleBase) - $($_.Version)"
        }
        Write-Host ''
    }
    Write-Host "      Test importing the current module version $($Script:BuildEnv.ModuleVersion)"
    Import-Module -Name $Script:BuildEnv.ModuleToBuild -MinimumVersion $Script:BuildEnv.ModuleVersion -Force
    Write-Host -ForeGroundColor green '...Done!'
}

task InstallAndTestModule InstallModule, TestInstalledModule

# Synopsis: The default build
task . `
        Configure,
        Clean,
        PrepareStage,
        GetPublicFunctions,
        SanitizeCode,
        CreateHelp,
        CreateModulePSM1,
        PushVersionRelease,
        PushCurrentRelease,
        BuildSessionCleanup

# Synopsis: Instert Comment Based Help where it doesn't already exist (output to scratch directory)
task  InsertMissingCBH `
        Configure,
        Clean,
        UpdateCBHtoScratch,
        BuildSessionCleanup

# Synopsis: Test the code formatting module only
task TestCodeFormatting Configure, Clean, PrepareStage, GetPublicFunctions, FormatCode

# Synopsis: Build help files for module and ignore missing section errors
task TestCreateHelp Configure, CreateMarkdownHelp, CreateExternalHelp, CreateUpdateableHelpCAB