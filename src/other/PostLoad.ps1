
<#
 Created on:   6/25/2015 10:01 AM
 Created by:   Zachary Loeber
 Module Name:  NLogModule
 Requires: http://nlog-project.org/
#>

Export-ModuleMember -Variable NLogConfig
#endregion Methods

$Logger = $null
$NLogConfig = Get-NewLogConfig

#region Module Cleanup
$ExecutionContext.SessionState.Module.OnRemove = {
    if ( Get-NLogDllLoadState ) {
        try {
            get-module | where {($_.Name -eq 'nlog') -or ($_.Name -eq 'Nlog45')} | foreach {
                Remove-Module $_
            }
        }
        catch { 
            Write-Warning "Unable to uninitialize module."
        }
    }    
}
#endregion Module Cleanup