
<#
 Created on:   6/25/2015 10:01 AM
 Created by:   Zachary Loeber
 Module Name:  NLogModule
 Requires: http://nlog-project.org/
#>

try {
    $DotNetInstalled = (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse | 
        Get-ItemProperty -name Version -ea 0 | 
        Where { $_.PSChildName -match '^(?!S)\p{L}'} | 
        Select @{n='version';e={[decimal](($_.Version).Substring(0,3))}} -Unique |
        Sort-Object -Descending | select -First 1).Version
}
catch {
    $DotNetInstalled = 3.5
}

if ($DotNetInstalled -ge 4.5) {
    #$__dllPath = Join-Path -Path $MyInvocation.MyCommand.ScriptBlock.Module.ModuleBase -ChildPath './lib/Nlog45.dll'
    $__dllPath = '.\lib\Nlog45.dll'
}
else {
    #$__dllPath = Join-Path -Path $MyInvocation.MyCommand.ScriptBlock.Module.ModuleBase -ChildPath '../../lib/Nlog.dll'
    $__dllPath = '.\lib\Nlog.dll'
}

try {
    Write-Host "Attempting to import $($__dllPath)..."
    Import-Module -Name $__dllPath -ErrorAction Stop
}
catch {
    throw
}