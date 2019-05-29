#requires -version 2

################################################################################
# Licensed Materials - Property of IBM                                         #
# (C) Copyright IBM Corp. 2019. All Rights Reserved.                           #
################################################################################

<#
.SYNOPSIS
  Script to collect server information
.DESCRIPTION
  This script will take any number of parameters and show the information on screen
.PARAMETER <Parameter_Name>
    switch    basicinfo
    switch    cpuinfo
    switch    memoryinfo
    switch    diskinfo
.INPUTS
  None.
.OUTPUTS
  Value from the requested metric.
.NOTES
  Version:        1.0.1
  Author:         Rodolfo de Carvalho
  Creation Date:  05/14/2019
  Purpose/Change: Bug Fix (based on issues raised)
  
.EXAMPLE
  .\Get-ServerInfo -diskinfo -memoryinfo -cpuinfo -basicinfo -verbose
  .\Get-ServerInfo -basicinfo
  .\Get-ServerInfo -basicinfo -cpuinfo
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#parameters declaration
[CmdletBinding()]
Param (
    [parameter(Mandatory=$false)]
    [switch]$memoryinfo,
    [parameter(Mandatory=$false)]
    [switch]$diskinfo,
    [parameter(Mandatory=$false)]
    [switch]$basicinfo,
    [parameter(Mandatory=$false)]
    [switch]$cpuinfo
)

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.0.1"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

#Function to get basic server information
Function Get-BasicInfo {
    begin {
        Write-Verbose "Getting basic server information"
    }
    process {
        try {
            $info = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop | Select-Object -Property Domain,Manufacturer,Model
            Write-Host "`nBasic Server Information:"
                        "---------------------------------" +
                        "`nServer Name: $env:COMPUTERNAME" +
                        "`nDomain: " + $info.Domain +
                        "`nManufacturer: " + $info.Manufacturer +
                        "`nModel: " + $info.Model +
                        "`n---------------------------------"
        } catch {
            Write-Warning $_.Exception.Message
        }
    }
    end {
        Write-Verbose "End of basic information check"
    }
}

#Function to get the information about memory on server
Function Get-MemoryInfo{
    begin{
        Write-Verbose "Getting Memory Information"
    }
    process{
        try {
            $meminfo = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop
            $totalMemory = [math]::round((($meminfo.TotalPhysicalMemory)/1MB), 2)
            $memused = [math]::round((($meminfo.TotalPhysicalMemory)/1MB - (Get-WmiObject -Class Win32_PerfRawData_PerfOS_Memory -ErrorAction Stop | Select-Object -ExpandProperty AvailableMBytes)), 2)
            $percentMemUsed = [math]::round(($memUsed*100/$totalMemory), 2)
            Write-Host "`nMemory Information:"
                        "---------------------------------" + 
                        "`nTotal Memory: $totalMemory MB" + 
                        "`nUsed Memory: $memused MB" +
                        "`nPercent Used: $percentMemUsed %" +
                        "`n---------------------------------"            
            
        } catch {
            Write-Warning $_.Exception.Message
        }
    }
    end{
        Write-Verbose "End of Memory Information check"
    }
}

#Function to get the information about cpu on server
Function Get-CPUInfo {
    begin {
        Write-Verbose "Getting CPU Information"
    }
    process{
        try {
            $procInfo = Get-WmiObject -Class win32_Processor -ErrorAction Stop
            $Procs = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop
            Write-Host "`nCPU Information:"
                        "---------------------------------" + 
                        "`nManufacturer: " + $procInfo.Manufacturer +
                        "`nCaption: "+ $procInfo.Caption +
                        "`nNumber of Processors: " + $Procs.NumberOfProcessors +
                        "`nNumber of Logical Processors: " + $Procs.Numberoflogicalprocessors +
                        "`nCPU Usage: " + $procInfo.LoadPercentage + "%" 
                        "`n---------------------------------"
        } catch {
            Write-Warning $_.Exception.Message
        }
    }
    end{
        Write-Verbose "End of CPU info check"
    }
}

#Function to get the information about the disks on the server
Function Get-DiskInfo {
    begin{
        Write-Verbose "Getting Disk information"
    }
    process{
        try {
            $diskList = Get-WmiObject -Class Win32_LogicalDisk -ErrorAction Stop | Where-Object {$_.DriveType -eq "3"} | Select-Object -ExpandProperty DeviceID
            Write-Host "`nDisk Information:"
            "---------------------------------"
            ForEach($disk in $diskList) {
                Write-Host ">>> DISK $disk"
                $diskinformation = Get-WmiObject -Class Win32_logicalDisk -ErrorAction Stop | Where-Object {$_.DeviceID -eq $disk}
                $disksize = [math]::round((($diskinformation.Size)/1GB), 2)
                Write-Host "Disk Size: $disksize GB"
                $diskfree = [math]::round((($diskinformation.FreeSpace)/1GB), 2)
                Write-Host "Free Space: $diskfree GB"
                $percentfree = [math]::Round(($diskfree*100/$disksize), 2)
                Write-Host "Percent Free: $percentfree %"
            }
            Write-Host "---------------------------------"
        } catch {
            Write-Warning $_.Exception.Message
        }
    }
    end{
        Write-Verbose "End of disk information check"
    }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Check on parameters list and execute as selected
Switch ($PSBoundParameters.GetEnumerator().
      Where({$_.Value -eq $true}).Key)
     {
       'memoryinfo'  { Get-MemoryInfo }
       'diskinfo'    { Get-DiskInfo }
       'cpuinfo'     { Get-CPUInfo }
       'basicinfo'   { Get-BasicInfo }
       'verbose'     { If ($PSBoundParameters.Count -eq 1){ Get-BasicInfo; Get-CPUInfo; Get-MemoryInfo; Get-DiskInfo }}
       default       { Write-Host "one"; Get-BasicInfo; Get-CPUInfo; Get-MemoryInfo; Get-DiskInfo }
     }