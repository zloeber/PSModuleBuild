Import-Module Powershell-YAML

Write-Host -NoNewLine 'Create ReadTheDocs definition file and saving to the root project site.'
$ReadTheDocsPath = '.\ReadTheDocs'
$YMLFile = Join-Path '..\' 'mkdocs.yml'
$Pages = [ordered]@{}

$RTDFolders = Get-ChildItem -Path $ReadTheDocsPath -Directory | Sort-Object -Property Name
ForEach ($RTDFolder in $RTDFolders) {

    $RTDocs = @(Get-ChildItem -Path $RTDFolder.FullName -Filter '*.md' | Sort-Object Name)
    if ($RTDocs.Count -gt 1) {
        $NewSection = @()
        Foreach ($RTDDoc in $RTDocs) {
            $NewSection += @{$RTDDoc.Basename = "$($RTDFolder.Name)\$($RTDDoc.Name)"}
        }
        $Pages[$RTDFolder.Name] = $NewSection
    }
    else {
        $Pages[$RTDFolder.Name] = "$($RTDFolder.Name)\$($RTDocs.Name)"
    }
}

$RTD = @{
    site_name = "PSModuleBuild Docs"
    repo_url = 'https://github.com/zloeber/PSModuleBuild'
    site_author = 'Zachary Loeber'
    edit_uri = "edit/master/docs/ReadTheDocs"
    theme = "readthedocs"
    copyright = "PSModuleBuild is licensed under the <a href='https://github.com/zloeber/PSModuleBuild/master/LICENSE.md'> license"
    Pages = $Pages
}
$RTD | ConvertTo-Yaml | Out-File -Encoding:utf8 -FilePath $YMLFile -Force

Write-Host -ForegroundColor Green '...Complete!'
Write-Host ''
Write-Host "The mkdocs.yml file likely needs to be updated to reflect the order which you want your documentation to be listed."