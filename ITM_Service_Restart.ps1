#requires -version 2

################################################################################
# Licensed Materials - Property of IBM                                         #
# (C) Copyright IBM Corp. 2019. All Rights Reserved.                           #
################################################################################
#
#             __/\\\\\_____/\\\__/\\\_______/\\\__/\\\\\\\\\\\\\\\_
#              _\/\\\\\\___\/\\\_\///\\\___/\\\/__\///////\\\/////__
#               _\/\\\/\\\__\/\\\___\///\\\\\\/__________\/\\\_______
#                _\/\\\//\\\_\/\\\_____\//\\\\____________\/\\\_______
#                 _\/\\\\//\\\\/\\\______\/\\\\____________\/\\\_______
#                  _\/\\\_\//\\\/\\\______/\\\\\\___________\/\\\_______
#                   _\/\\\__\//\\\\\\____/\\\////\\\_________\/\\\_______
#                    _\/\\\___\//\\\\\__/\\\/___\///\\\_______\/\\\_______
#                     _\///_____\/////__\///_______\///________\///________
#
################################################################################

<#
.SYNOPSIS
  ITM Service Restart
.DESCRIPTION
  Script will check status and try to restablish ITM Agent, if down.
  The script will check the service status and try to restart. If the service is successfully restarted, 
  it will try to collect information from the logs confirming the connection with CMS.
  The REMEDIATION will occurr in case the services are started and connection to CMS is established. Any
  other case will end as DIAGNOSIS.
.PARAMETER
    [string]itm_agent
        ITM Agent product to be started (default - "nt")
    [string]agent_name
        Name of the ITM primary service, in case provided on the ticket.
    [string]agent_watchdog
        Name of the ITM watchdog service, in case provided on the ticket.
.INPUTS
    .none
.OUTPUTS
    JSON-formated string with information about success or failure
.NOTES
  Version:        1.0.0
  Author:         Rodolfo de Carvalho
  Creation Date:  May-24-2019
  Purpose/Change: Initial script development

.EXAMPLE
  .\ITM_Service_Restart -itm_agent NT
  .\ITM_Service_Restart
#>

[CmdletBinding()]
Param (
    [parameter(Mandatory=$false)]
    [string]$itm_agent = "nt",
    [parameter(MAndatory=$false)]
    [string]$agent_name = "",
    [parameter(MAndatory=$false)]
    [string]$agent_watchdog = ""
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

#Dot Source required Function Libraries
. "C:\Scripts\Functions\Logging_Functions.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$script = $MyInvocation.MyCommand.Name

#Set Initial purpose to DIAGNOSIS
$purpose = "DIAGNOSIS"

#Service Status Object
$svcStatus = New-Object -TypeName PSObject
Add-Member -InputObject $svcStatus -MemberType NoteProperty -Name PrimaryName -Value ""
Add-Member -InputObject $svcStatus -MemberType NoteProperty -Name WatchdogName -Value ""
Add-Member -InputObject $svcStatus -MemberType NoteProperty -Name PrimaryStatus -Value ""
Add-Member -InputObject $svcStatus -MemberType NoteProperty -Name WatchdogStatus -Value ""

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Get-ITMPath{
    Begin{
        $key = 'HKLM:\SYSTEM\CurrentControlSet\Services\KNTCMA_Primary'
    }

    Process{
        $path = (Get-ItemProperty -Path $key -Name ImagePath).imagepath
        $path = $path -replace "(.*)\\(.*)",'$1'
    }
    End{
        return $path
    }
}

Function Set-AgentInfo {
    Param (
        [parameter(Mandatory=$true)]
        [string]$itm,
        [parameter(Mandatory=$true)]
        $primary,
        [parameter(Mandatory=$true)]
        $watchdog
    )
    begin {
    }
    process {
        if($primary -eq ""){
            $svcStatus.PrimaryName = "k" + $itm + "cma_primary"
        } else {
            $svcStatus.PrimaryName = $primary
        }
        if($watchdog -eq ""){
            $svcStatus.WatchdogName = "k" + $itm + "cma_watchdog"
        } else {
            $svcStatus.WatchdogName = $watchdog
        }
    }
    end {
    }
}

function Get-ITMService {
    param(
        [parameter(Mandatory=$true)]
        $primary,
        [parameter(Mandatory=$true)]
        $watchdog
    )
    $svcStatus.primaryStatus = Get-Service -Name $primary | Select-Object -ExpandProperty Status
	$svcStatus.watchdogStatus =  Get-Service -Name $watchdog | Select-Object -ExpandProperty Status
}

function Stop-ITMService {
    param(
        [parameter(Mandatory=$true)]
        $primary,
        [parameter(Mandatory=$true)]
        $watchdog,
        [parameter(Mandatory=$false)]
        [switch]$force
    )
    if($force){
        Get-WmiObject -query "SELECT * FROM Win32_Process WHERE Name like '%kntcma%' or Name like '%kcawd%'" | ForEach-Object { $_.Terminate() | Out-Null }
        Start-Sleep -s 10
        Get-ITMService -primary $primary -watchdog $watchdog
    } else {
        get-service -name $primary | stop-service -force
        get-service -name $watchdog | stop-service -force
        Start-Sleep -Seconds 5
        Get-ITMService -primary $primary -watchdog $watchdog
    }
}

function Start-ITMService {
    param(
        [parameter(Mandatory=$true)]
        $primary,
        [parameter(Mandatory=$true)]
        $watchdog
    )
    get-service -name $primary | start-service
    get-service -name $watchdog | start-service
    Get-ITMService -primary $primary -watchdog $watchdog
}

Function Get-Evidence {
    param(
        [parameter(Mandatory=$true)]
        $primary,
        [parameter(Mandatory=$true)]
        $watchdog
    )
    $out = "`nEvidence of running service:`n------------------------------"
    $out += Get-Service -Name $primary, $watchdog | Select-Object -Property Name, DisplayName, Status | Format-List | Out-String
    $out += "------------------------------"
    $out
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Set path to ITM Installation
$ITMPath = Get-ITMPath

#Set agent information in case not provided as parameter
Set-AgentInfo -itm $itm_agent -primary $agent_name -watchdog $agent_watchdog

#Get initial service status
Get-ITMService -primary $svcStatus.PrimaryName -watchdog $svcStatus.WatchdogName

#Stop ITM services
Stop-ITMService -primary $svcStatus.PrimaryName -watchdog $svcStatus.WatchdogName

#Check if any primary or watchdog is is running. If running, force stop
If(($svcStatus.PrimaryStatus -eq "Running") -or ($svcStatus.WatchdogStatus -eq "Running")){
    Stop-ITMService -primary $svcStatus.PrimaryName -watchdog $svcStatus.WatchdogName -force
}

#Start ITM Services
Start-ITMService -primary $svcStatus.PrimaryName -watchdog $svcStatus.WatchdogName

#Sleep to ensure that services are stable
Start-Sleep -Seconds 30

#Get service status after 30 seconds
Get-ITMService -primary $svcStatus.PrimaryName -watchdog $svcStatus.WatchdogName

#formats ITM log name
$itmlog = "*_" + $itm_agent + "_k" + $itm_agent + "cma_*-01.log"

If(($svcStatus.PrimaryStatus -eq "Running") -and ($svcStatus.WatchdogStatus -eq "Running")){
    $evidence = Get-Evidence $svcStatus.PrimaryName -watchdog $svcStatus.WatchdogName
    $totaltime = 0
    $waittime = 60
    While ($totaltime -lt $waittime){
        Start-Sleep -Seconds 3
        $totaltime += 30
	    If(Get-ChildItem $ITMPath\logs\*.* -include $itmlog | Sort-Object lastwritetime -descending | Select-Object -first 1 | get-content | select-string -pattern "Successfully connected to CMS" | format-table) { #Unable to find running CMS
            $purpose = "REMEDIATION"
            $OUTPUT = "The ITM Services have been restarted and they are now and agent is connected to CMS.`n" + $evidence
        } else {
            $logfile = ""
            $logfile = Get-ChildItem $ITMPath\logs\*.* -include $itmlog | Sort-Object lastwritetime -descending | Select-Object -first 1 | get-content | Select-Object -last 20 | Format-Table | Out-String #ForEach { $logfile += $_ }
            $purpose = "DIAGNOSIS"
            $OUTPUT = "The ITM Services have been restarted and they are now Running, but we could not confirm that the agent is connected to CMS.`n"
            $OUTPUT += "Please find bellow the log information for troubleshooting`n"
            $OUTPUT += "========================================`nLOG INFORMATION`n========================================`n" + $logfile + "`n========================================`n" + $evidence
        }
    }
} else {
    $logfile = ""
    $logfile = Get-ChildItem $ITMPath\logs\*.* -include $itmlog | Sort-Object lastwritetime -descending | Select-Object -first 1 | get-content | Select-Object -last 20 | Format-Table | Out-String #ForEach { $logfile += $_ }
	Get-ITMService -primary $svcStatus.PrimaryName -watchdog $svcStatus.WatchdogName
	$purpose = "DIAGNOSIS"
    $OUTPUT = "We tried to restart the ITM Services, but the operation was not successful.`n"
    $OUTPUT += "Please find bellow the log information for troubleshooting`n"
    $OUTPUT += "========================================`nLOG INFORMATION`n========================================`n" + $logfile + "`n========================================`n"
}

$objOutput = @{ Script = $script; Purpose = $purpose; Output = $output }

$objOutput | ConvertTo-Json -Compress