<#
.NAME
Update Policy and Reboot GCPS

.SYNOPSIS

Connects to a remote machine, forces a group policy update, then reboots the machine.

.DESCRIPTION

The software for the GCP's is kept upto date through Group Policy, however that can lead to a period of time where different GCPs have different versions.  
This script kills the GCP software, then forces a group policy update which will copy the new software over.  The GCP is then rebooted which starts the new software.

The script takes in a listing of all the GCP's to be updated.  If a GCP is to be skipped, the line needs to have a # in the beginning of the line.

.PARAMETER

.EXAMPLE

Update Policy and Reboot GCPS.ps1

.EXAMPLE
Update Policy and Reboot GCPS.ps1 -UpdateList
#>
[CmdletBinding()]

Param (
    [string]$UpdateList

    )

#Modules to be imported
#Import-Module ActiveDirectory


    
#Set flags for debug mode.    
If($psBoundParameters['debug'])
    {
    $DebugPreference = "Continue"
    }
Else
    {
    $DebugPreference = "SilentlyContinue"
    }


#Check to see if a list has been given.  If is, set the $gcps variable.  If not, grab all the computers from AD and set to the $gcps variable.
If($psBoundParameters['UpdateList'])
    {
    $gcps = Get-Content $UpdateList
    }
Else
    {
    $gcps = dsquery computer "ou=GCP Computers,DC=Security,DC=Local"

    For ($i = 0; $i -lt $gcps.Count; $i++)
        {
        $gcps[$i] = $gcps[$i].Substring(4,$gcps[$i].IndexOf(",")-4)
        }
    }


$jobs = @()

$ScriptBlock =
{
	Param ([string]$computername)

	Invoke-Command -computername $computername	{ Stop-Process -Force -processname "GatePad" }
    Invoke-Command -computername $computername	{ gpupdate /force}
    Write-Debug -Message "Working on machine $ComputerName"
    Write-Host "Updating on $ComputerName."
    Start-Sleep 5
    #Invoke-Command -Computername $Computername { shutdown /r /t 0 }
   
}

Write-Host "Starting the updates on the Gate Control Panels.  Once all have been updated they will be rebooted." -ForegroundColor Green
Write-Debug -Message "After starting the gpudate there is a 5 second pause betwen starting updates."
Foreach($gcp in $gcps)
{
	if ($gcp.StartsWith("#"))
	{
		Write-Debug -Message "$gcp skipped..."
	}
	else
	{
		Write-Debug -Message "Updating $gcp"
		$jobs += Start-Job -ScriptBlock $ScriptBlock -ArgumentList $gcp
	}
}

Write-Host "Waiting for jobs to finish"
Write-Debug -Message "There are still jobs running.  When there are 0 jobs this will move on."
Wait-Job $jobs.id
Remove-Job -State Completed
Write-Host "Rebooting units"

Foreach($gcp in $gcps)
{
	if ($gcp.StartsWith("#"))
	{
		Write-Debug "$gcp skipped..."
	}
	else
	{
		Write-host "Rebooting $gcp"
		Invoke-Command -computername $gcp -scriptblock { shutdown /r /t 0}
	}
}


Read-Host -Prompt "Update Complete - Press enter to close"