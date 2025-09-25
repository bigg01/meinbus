#Requires -Modules Az.Reservations, Az.Accounts
<#
.SYNOPSIS
    Main management script for Azure reservations with comprehensive operations.

.DESCRIPTION
    This script provides a unified interface for managing Azure reservations:
    - List all reservations with filtering options
    - Export reservation configurations
    - Import and recreate reservations
    - Generate reports and summaries
    - Backup and restore operations

.PARAMETER Action
    The action to perform: List, Export, Import, Recreate, Report, Backup

.PARAMETER SubscriptionId
    Target subscription ID

.PARAMETER ConfigPath
    Path to configuration file

.PARAMETER OutputPath  
    Path for output files

.PARAMETER Environment
    Environment filter (production, staging, etc.)

.PARAMETER WhatIf
    Show what would be done without making changes

.EXAMPLE
    .\Manage-AzureReservations.ps1 -Action List
    Lists all reservations in the current subscription.

.EXAMPLE
    .\Manage-AzureReservations.ps1 -Action Export -OutputPath "backup.json"
    Exports all reservations to a JSON file.

.EXAMPLE
    .\Manage-AzureReservations.ps1 -Action Recreate -ConfigPath "backup.json" -WhatIf
    Shows what reservations would be recreated from backup.

.NOTES
    Author: Generated for meinbus project
    Date: $(Get-Date -Format "yyyy-MM-dd")
    Requires: Az.Reservations and Az.Accounts PowerShell modules
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("List", "Export", "Import", "Recreate", "Report", "Backup")]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = ".\config.json",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [string]$Environment,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Import common functions
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonFunctionsPath = Join-Path $scriptPath "Common-Functions.ps1"

if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-Warning "Common-Functions.ps1 not found. Some functionality may be limited."
}

# Error handling
$ErrorActionPreference = "Stop"

function Show-Menu {
    Write-Host ""
    Write-Host "=== Azure Reservation Management ===" -ForegroundColor Cyan
    Write-Host "1. List all reservations" -ForegroundColor White
    Write-Host "2. Export reservations to JSON" -ForegroundColor White
    Write-Host "3. Import reservations from JSON" -ForegroundColor White
    Write-Host "4. Recreate reservations" -ForegroundColor White
    Write-Host "5. Generate HTML report" -ForegroundColor White
    Write-Host "6. Backup current reservations" -ForegroundColor White
    Write-Host "7. Exit" -ForegroundColor White
    Write-Host ""
}

function Invoke-ListReservations {
    Write-Host "Listing Azure reservations..." -ForegroundColor Yellow
    
    $scriptArgs = @()
    if ($SubscriptionId) { $scriptArgs += "-SubscriptionId", $SubscriptionId }
    if ($OutputPath) { $scriptArgs += "-OutputPath", $OutputPath }
    
    $getScript = Join-Path $scriptPath "Get-AzureReservations.ps1"
    if (Test-Path $getScript) {
        & $getScript @scriptArgs
    } else {
        Write-Error "Get-AzureReservations.ps1 not found"
    }
}

function Invoke-ExportReservations {
    Write-Host "Exporting Azure reservations..." -ForegroundColor Yellow
    
    if (-not $OutputPath) {
        $OutputPath = "reservations-export-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    }
    
    $scriptArgs = @("-OutputPath", $OutputPath)
    if ($SubscriptionId) { $scriptArgs += "-SubscriptionId", $SubscriptionId }
    
    $getScript = Join-Path $scriptPath "Get-AzureReservations.ps1"
    if (Test-Path $getScript) {
        & $getScript @scriptArgs
        Write-Host "Export completed: $OutputPath" -ForegroundColor Green
    } else {
        Write-Error "Get-AzureReservations.ps1 not found"
    }
}

function Invoke-RecreateReservations {
    Write-Host "Recreating Azure reservations..." -ForegroundColor Yellow
    
    if (-not $ConfigPath) {
        Write-Error "ConfigPath is required for recreate operation"
        return
    }
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found: $ConfigPath"
        return
    }
    
    $scriptArgs = @("-ConfigPath", $ConfigPath)
    if ($SubscriptionId) { $scriptArgs += "-SubscriptionId", $SubscriptionId }
    if ($WhatIf) { $scriptArgs += "-WhatIf" }
    if ($Force) { $scriptArgs += "-Force" }
    
    $recreateScript = Join-Path $scriptPath "Recreate-AzureReservations.ps1"
    if (Test-Path $recreateScript) {
        & $recreateScript @scriptArgs
    } else {
        Write-Error "Recreate-AzureReservations.ps1 not found"
    }
}

function Invoke-GenerateReport {
    Write-Host "Generating reservation report..." -ForegroundColor Yellow
    
    # First get the reservations
    $tempFile = [System.IO.Path]::GetTempFileName() + ".json"
    $scriptArgs = @("-OutputPath", $tempFile)
    if ($SubscriptionId) { $scriptArgs += "-SubscriptionId", $SubscriptionId }
    
    $getScript = Join-Path $scriptPath "Get-AzureReservations.ps1"
    if (Test-Path $getScript) {
        & $getScript @scriptArgs | Out-Null
        
        if (Test-Path $tempFile) {
            $reservations = Get-Content $tempFile -Raw | ConvertFrom-Json
            
            if (-not $OutputPath) {
                $OutputPath = "reservation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
            }
            
            # Generate HTML report using common function
            if (Get-Command New-ReservationSummaryReport -ErrorAction SilentlyContinue) {
                New-ReservationSummaryReport -Reservations $reservations -ReportPath $OutputPath
            } else {
                Write-Warning "New-ReservationSummaryReport function not available. Creating basic report."
                $reservations | ConvertTo-Html | Out-File $OutputPath
                Write-Host "Basic HTML report created: $OutputPath" -ForegroundColor Green
            }
            
            # Clean up temp file
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Error "Get-AzureReservations.ps1 not found"
    }
}

function Invoke-BackupReservations {
    Write-Host "Creating backup of current reservations..." -ForegroundColor Yellow
    
    if (-not $OutputPath) {
        $OutputPath = "reservation-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    }
    
    Invoke-ExportReservations
    Write-Host "Backup completed: $OutputPath" -ForegroundColor Green
}

# Main execution
try {
    Write-Host "Azure Reservation Management Tool" -ForegroundColor Cyan
    Write-Host "Action: $Action" -ForegroundColor Yellow
    
    # Check prerequisites
    if (Get-Command Test-AzureModules -ErrorAction SilentlyContinue) {
        if (-not (Test-AzureModules)) {
            exit 1
        }
        
        if (-not (Test-AzureAuthentication)) {
            exit 1
        }
    }
    
    # Set subscription context if provided
    if ($SubscriptionId) {
        if (Get-Command Set-AzureSubscriptionContext -ErrorAction SilentlyContinue) {
            if (-not (Set-AzureSubscriptionContext -SubscriptionId $SubscriptionId)) {
                exit 1
            }
        }
    }
    
    # Execute the requested action
    switch ($Action) {
        "List" {
            Invoke-ListReservations
        }
        "Export" {
            Invoke-ExportReservations
        }
        "Import" {
            Write-Host "Import functionality - use Recreate action with ConfigPath parameter" -ForegroundColor Yellow
            Invoke-RecreateReservations
        }
        "Recreate" {
            Invoke-RecreateReservations
        }
        "Report" {
            Invoke-GenerateReport
        }
        "Backup" {
            Invoke-BackupReservations
        }
        default {
            Write-Error "Unknown action: $Action"
        }
    }
    
    Write-Host "`nOperation completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}