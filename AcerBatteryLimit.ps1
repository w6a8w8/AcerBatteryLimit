<#
.SYNOPSIS
    Enables or disables Acer Battery Health Mode.

.DESCRIPTION
    On  - Enables Acer's firmware-managed charge limit, normally about 80%.
    Off - Disables the limit and permits charging to 100%.

    Requires Windows PowerShell 5.1 and a compatible Acer laptop.

.EXAMPLE
    .\AcerBatteryLimit.ps1 -Action On

.EXAMPLE
    .\AcerBatteryLimit.ps1 -Action Off
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet("On", "Off")]
    [string] $Action
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsAdministrator {
    # Check whether Windows PowerShell is running with administrator rights.
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Restart-AsAdministrator {
    # The elevated PowerShell process needs the path of the saved script.
    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
    throw "Save the script as a .ps1 file before running it."
    }

    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow

    # Quote the script path so that paths containing spaces work correctly.
    $arguments = (
        '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Action "{1}"' -f
        $PSCommandPath,
        $Action
    )

    $process = Start-Process `
        -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList $arguments `
        -Verb RunAs `
        -Wait `
        -PassThru

    # Return the exit code from the elevated PowerShell process.
    exit $process.ExitCode
}

try {
    # Access to Acer's WMI battery interface requires administrator rights.
    if (-not (Test-IsAdministrator)) {
        Restart-AsAdministrator
    }

    # Obtain Acer's firmware-facing battery control interface.
    $controller = Get-WmiObject `
        -Namespace "root\WMI" `
        -Class "BatteryControl" `
        -ErrorAction Stop |
        Select-Object -First 1

    if ($null -eq $controller) {
        throw (
            "The root\WMI:BatteryControl interface was not found. " +
            "This Acer model or its installed drivers may not support it."
        )
    }

    # Acer's interface uses 1 to enable the limit and 0 to disable it.
    [byte] $requestedState = if ($Action -eq "On") { 1 } else { 0 }

    $result = $controller.SetBatteryHealthControl(
        1,
        1,
        $requestedState,
        [byte[]]@(0, 0, 0, 0, 0)
    )

    if ($null -eq $result) {
        throw "The Acer WMI interface did not return a result."
    }

    if ($Action -eq "On") {
        Write-Host "The 80% charge limit was requested." `
            -ForegroundColor Green
    }
    else {
        Write-Host "The 100% charge limit was requested." `
            -ForegroundColor Green
    }

	# Keep the window open briefly so the confirmation can be read.
	Start-Sleep -Seconds 2

    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red

    # Keep the window open briefly so the error can be read.
    Start-Sleep -Seconds 10
    
    exit 1
}