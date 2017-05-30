# Maintaining Project Documentation
Keeping documentation updated for your project comes in two forms with the module code scaffolding that this project creates.

1. You keep your comment based help for public functions updated. PlatyPS will use this to generate function documentation.
2. ReadTheDocs manifest creation and updating for ReadTheDocs.org integration.

## Function CBH
The build process uses PlatyPS to generate the relevant help files and will fail if "{{ blah blah blah }}" is found to have been created in the output files (as these are meant to be replaced manually for any information PlatyPS is unable to locate).

Once PlatyPS does its thing the CBH for each function gets replaced with the generated module documentation link. I base this replacement code on '.SYNOPSIS' existing in the comment based help. This is done in the following task:
```
task UpdateCBH -Before CreateModulePSM1 {
    $CBHPattern = "(?ms)(\<#.*\.SYNOPSIS.*?#>)"
    Get-ChildItem -Path "$($ScratchPath)\$($PublicFunctionSource)\*.ps1" -File | ForEach {
            $FormattedOutFile = $_.FullName
            Write-Output "      Replacing CBH in file: $($FormattedOutFile)"
            $UpdatedFile = (get-content  $FormattedOutFile -raw) -replace $CBHPattern, $ExternalHelp
            $UpdatedFile | Out-File -FilePath $FormattedOutFile -force -Encoding:utf8
     }
}
```

As you might expect this will remove the entire CBH block which may or may not be what you want in your final release (Update: I've included code to also include the external link based on the version release directory and module website).

Also, we recreate the documentation markdown files every time the documentation gets generated. This includes the module landing page. PlatyPS doesn't seem to automatically pull in function description information (or I'm missing something in the usage of this module) so I do so within another task behind the scenes.

## ReadTheDocs.net Integration
If you have enabled readthedocs.net integration in the PSModuleBuild configuration then a mkdocs.yml file will get updated automatically at the root of your project directory. It is up to you to setup the integration between your github.com account and readthedocs.net.

The ReadTheDocs manifest file gets generated from the folder structure in docs\ReadTheDocs. Each subfolder becomes a category with each markdown document within becoming a specific page within it.

Beware that the order of the pages in this manifest file can be rather random. You will want to update the file to suit your needs (and then possibly disable readthedocs integration within your psmodulebuild config file so it doesn't revert the next build you run).