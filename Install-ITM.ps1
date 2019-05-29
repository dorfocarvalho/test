<#  
.SYNOPSIS  
	Installs the IBM Tivoli Monitoring agent
.NOTES  
	File Name	: Install-ITM.ps1
	Author		: Rodolfo de Carvalho - carvalhr@br.ibm.com
	Reviewer	: Maxx Fonseca - mmaxx@br.ibm.com
	Requires	: PowerShell V5
#>

# ----------------------------------------------------------------------------
# COMMAND LINE PARAMETERS
# ----------------------------------------------------------------------------
# @string	ITMCode		Mandatory. Account code for the installation (-aact)
# @string   RTEMS1      Mandatory. IP from RTEMS1 (-ptem)
# @string   RTEMS2      Optional. IP from RTEMS2 (-stem)
# @string   Source      Mandatory. Drive where software will be installed (-drive)
# ----------------------------------------------------------------------------

[CmdletBinding()]
Param (
    [parameter(Mandatory=$true)]
    [string]$ITMCode,
    [parameter(Mandatory=$true)]
    [ValidateScript({$_ -match [IPAddress]$_ })]
    [string]$RTEMS1,
    [parameter(Mandatory=$false)]
    [ValidateScript({$_ -match [IPAddress]$_ })]
    [string]$RTEMS2
)

$drive = "C"
$installzip = $PSScriptRoot + "\NT_063006000_WINDOWS_V2.zip"

Expand-Archive -Path $installzip -DestinationPath $PSScriptRoot
$path = Get-ChildItem -Path $PSScriptRoot -Directory -Filter "NT_*"
$path = "$PSScriptRoot\" + $path.Name

Set-Location -Path "$path"

If ($RTEMS2 -ne ""){
    cmd /c "itmInstall.bat -acct $ITMCode -ptem $RTEMS1 -stem $RTEMS2 -drive $drive"
} Else {
    cmd /c "itmInstall.bat -acct $ITMCode -ptem $RTEMS1 -drive $drive"
}
Start-Sleep -Seconds 15
try {
    Get-Service -Name kntcma_primary -ErrorAction Stop
} catch {
    Write-Host -ForegroundColor Red "Error: $_"
}
Set-Location -Path $PSScriptRoot
Remove-Item -Path $path -Recurse -Force