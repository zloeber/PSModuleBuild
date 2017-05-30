param (
    [Parameter(HelpMessage = 'If you are initializing this file or want to force overwrite the persistent export data use this flag.')]
    [switch]$ForcePersist
)
<#
 Update $Script:BuildEnv to suit your PowerShell module build. These variables get dot sourced into
 the build at every run and are exported to an external xml file for persisting through possible build
 engine upgrades.
#>

# If the variable is already defined then essentially do nothing.
# Otherwise we create a baseline variable first in case this is a first time run, then
# check for an exported .xml file with persistent settings for any run thereafter
if ((Get-Variable 'BuildEnv' -ErrorAction:SilentlyContinue) -eq $null) {
    $Script:BuildEnv = New-Object -TypeName PSObject -Property @{
        FirstRun = $True
        Encoding = 'utf8'
        ModuleToBuild = '<%=$PLASTER_PARAM_ModuleName%>'
        ModuleVersion = '<%=$PLASTER_PARAM_ModuleVersion%>'
        ModuleWebsite = '<%=$PLASTER_PARAM_ModuleWebsite%>'
        ModuleCopyright = "(c) $((get-date).Year.ToString()) <%=$PLASTER_PARAM_ModuleAuthor%>. All rights reserved."
        ModuleLicenseURI = '<%=$PLASTER_PARAM_ModuleWebsite%>/LICENSE.md'
        ModuleTags = '<%=$PLASTER_PARAM_ModuleTags%>' -split ','
        ModuleAuthor = '<%=$PLASTER_PARAM_ModuleAuthor%>'
        ModuleDescription = '<%=$PLASTER_PARAM_ModuleDescription%>'

        # Options - These affect how your eventual build will be run.
        OptionAnalyzeCode = $<%=$PLASTER_PARAM_OptionAnalyzeCode%>
        OptionCombineFiles = $<%=$PLASTER_PARAM_OptionCombineFiles%>
        OptionTranscriptEnabled = $false
        OptionTranscriptLogFile = 'BuildTranscript.Log'

        # PlatyPS has been the cause of most of my build failures. This can help you isolate which function's CBH is causing you grief.
        OptionRunPlatyPSVerbose = $false

        # If you want to prescan and fail a build upon finding any proprietary strings
        # enable this option and define some strings.
        OptionSanitizeSensitiveTerms = $<%=$PLASTER_PARAM_OptionSanitizeSensitiveTerms%>
        OptionSensitiveTerms = @()
        OptionSensitiveTermsInitialized = $false

        # Additional paths in the source module which should be copied over to the final build release
<%
if ($PLASTER_PARAM_AdditionalModulePaths -ne ' ') {
        @"
        AdditionalModulePaths = '<%=$PLASTER_PARAM_AdditionalModulePaths%>' -split ','
"@
}
else {
    @"
        AdditionalModulePaths = @()
"@
}
%>
        # Generate a yml file in the root folder of this project for readthedocs.org integration
        OptionGenerateReadTheDocs = $<%=$PLASTER_PARAM_OptionGenerateReadTheDocs%>
        # Most of the following options you probably don't need to change
        BaseSourceFolder = 'src'        # Base source path
        PublicFunctionSource = "src\<%=$PLASTER_PARAM_PublicFunctionSource%>"         # Public functions (to be exported by file name as the function name)
        PrivateFunctionSource = "src\<%=$PLASTER_PARAM_PrivateFunctionSource%>"        # Private function source
        OtherModuleSource = "src\<%=$PLASTER_PARAM_OtherModuleSource%>"        # Other module source
        BaseReleaseFolder = '<%=$PLASTER_PARAM_BaseReleaseFolder%>'        # Releases directory.
        BuildToolFolder = 'build'        # Build tool path (these scripts are dot sourced)
        ScratchFolder = '<%=$PLASTER_PARAM_ScratchFolder%>'        # Scratch path - this is where all our scratch work occurs. It will be cleared out at every run.

        # If you will be publishing to the PowerShell Gallery you will need a Nuget API key (can get from the website)
        # You should not actually enter this key here but should manually enter it in the <%=$PLASTER_PARAM_ModuleName%>.buildenvironment.json file

        NugetAPIKey  = $null
    }

    ########################################
    # !! Please leave anything below this line alone !!
    ########################################
    $PersistentBuildFile = join-path $PSScriptRoot "<%=$PLASTER_PARAM_ModuleName%>.buildenvironment.json"

    # Load any persistent data (overrides anything in BuildEnv if the hash element exists)
    if ((Test-Path $PersistentBuildFile)) {
        try {
            $LoadedBuildEnv = Get-Content $PersistentBuildFile | ConvertFrom-Json
        }
        catch {
            throw "Unable to load $PersistentBuildFile"
        }
        $BaseSettings = ($Script:BuildEnv | Get-Member -Type 'NoteProperty').Name
        $BuildSettings = ($LoadedBuildEnv | Get-Member -Type 'NoteProperty').Name
        ForEach ($Key in $BuildSettings) {
            if ($BaseSettings -contains $Key) {
                Write-Verbose "Updating profile setting '$key' from $PersistentBuildFile"
                ($Script:BuildEnv).$Key = $LoadedBuildEnv.$Key
            }
            else {
                Write-Verbose "Adding profile setting '$key' from $PersistentBuildFile"
                Add-Member -InputObject $Script:BuildEnv -TypeName 'NoteProperty' -Name $Key -Value $LoadedBuildEnv.$Key
            }
        }
    }
    else {
        # No persistent file was found so we are going to create one
        $BuildExport = $True
    }

    # If we don't have a persistent file, we are forcing a persist, or properties were not the same between
    # the loaded json and our defined BuildEnv file then push a new persistent file export.
    if ((-not (Test-path $PersistentBuildFile)) -or $BuildExport -or $ForcePersist -or ($Script:BuildEnv.FirstRun)) {
        Write-Output "Exporting the BuildEnv data!"
        $Script:BuildEnv | ConvertTo-Json | Out-File -FilePath $PersistentBuildFile -Encoding:$Script:BuildEnv.Encoding -Force
    }

    # If you will be attempting to autogenerate comment based help this is the base template that will be used
    # You need to leave the %%<string>%% tags to automatically be populated.
    $CBHTemplate = @'
    <#
    .SYNOPSIS
        TBD
    .DESCRIPTION
        TBD
    %%PARAMETER%%
    .EXAMPLE
        TBD
    .NOTES
        Author: %%AUTHOR%%
    .LINK
        %%LINK%%
    #>
'@ -replace '%%LINK%%',$BuildEnv.ModuleWebsite -replace '%%AUTHOR%%',$BuildEnv.ModuleAuthor
}