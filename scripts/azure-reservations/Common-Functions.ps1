#Requires -Modules Az.Accounts
<#
.SYNOPSIS
    Common utility functions for Azure reservation management scripts.

.DESCRIPTION
    This module contains shared functions used by the Azure reservation scripts:
    - Authentication and context management
    - Configuration validation
    - Utility functions for reservation operations

.EXAMPLE
    # Import the module functions
    . .\Common-Functions.ps1
    
    # Test if required Azure modules are installed
    Test-AzureModules

.EXAMPLE
    # Check Azure authentication status
    Test-AzureAuthentication

.NOTES
    Author: Generated for meinbus project
    Date: $(Get-Date -Format "yyyy-MM-dd")
    Requires: Az.Accounts PowerShell module
#>

# Function to ensure Azure PowerShell modules are installed
function Test-AzureModules {
    [CmdletBinding()]
    param(
        [string[]]$RequiredModules = @('Az.Accounts', 'Az.Reservations')
    )
    
    Write-Host "Checking required Azure PowerShell modules..." -ForegroundColor Yellow
    
    $missingModules = @()
    foreach ($module in $RequiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            $missingModules += $module
        } else {
            Write-Host "✓ $module is installed" -ForegroundColor Green
        }
    }
    
    if ($missingModules.Count -gt 0) {
        Write-Warning "Missing required modules: $($missingModules -join ', ')"
        Write-Host "To install missing modules, run:" -ForegroundColor Yellow
        Write-Host "Install-Module -Name $($missingModules -join ', ') -Scope CurrentUser -Force" -ForegroundColor Cyan
        return $false
    }
    
    return $true
}

# Function to ensure user is authenticated to Azure
function Test-AzureAuthentication {
    [CmdletBinding()]
    param()
    
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Warning "No Azure context found. Please authenticate to Azure."
            Write-Host "Run: Connect-AzAccount" -ForegroundColor Cyan
            return $false
        }
        
        Write-Host "✓ Authenticated as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "✓ Current subscription: $($context.Subscription.Name)" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Error "Error checking Azure authentication: $($_.Exception.Message)"
        return $false
    }
}

# Function to set Azure subscription context
function Set-AzureSubscriptionContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId
    )
    
    try {
        Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Yellow
        $context = Set-AzContext -SubscriptionId $SubscriptionId
        
        if ($context) {
            Write-Host "✓ Successfully set context to: $($context.Subscription.Name)" -ForegroundColor Green
            return $true
        } else {
            Write-Error "Failed to set subscription context"
            return $false
        }
        
    } catch {
        Write-Error "Error setting subscription context: $($_.Exception.Message)"
        return $false
    }
}

# Function to validate JSON configuration file
function Test-ReservationConfigFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found: $ConfigPath"
        return $false
    }
    
    try {
        $content = Get-Content $ConfigPath -Raw
        $config = $content | ConvertFrom-Json
        
        if (-not $config) {
            Write-Error "Configuration file is empty or invalid JSON"
            return $false
        }
        
        # Validate that it's an array or has reservation properties
        if ($config -is [array]) {
            Write-Host "✓ Configuration contains $($config.Count) reservation(s)" -ForegroundColor Green
        } elseif ($config.PSObject.Properties.Name -contains 'ProductType') {
            Write-Host "✓ Configuration contains a single reservation" -ForegroundColor Green
        } else {
            Write-Error "Configuration file does not contain valid reservation data"
            return $false
        }
        
        return $true
        
    } catch {
        Write-Error "Error parsing configuration file: $($_.Exception.Message)"
        return $false
    }
}

# Function to get available Azure locations for a resource type
function Get-AzureLocationsForResource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceType
    )
    
    try {
        $locations = Get-AzLocation | Where-Object { $_.Providers -contains "Microsoft.Compute" } | Sort-Object DisplayName
        return $locations
    } catch {
        Write-Warning "Could not retrieve Azure locations: $($_.Exception.Message)"
        return @()
    }
}

# Function to format reservation term for display
function Format-ReservationTerm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Term
    )
    
    switch ($Term) {
        "P1Y" { return "1 Year" }
        "P3Y" { return "3 Years" }
        default { return $Term }
    }
}

# Function to calculate reservation expiration date
function Get-ReservationExpirationDate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$PurchaseDate,
        
        [Parameter(Mandatory = $true)]
        [string]$Term
    )
    
    switch ($Term) {
        "P1Y" { return $PurchaseDate.AddYears(1) }
        "P3Y" { return $PurchaseDate.AddYears(3) }
        default { 
            Write-Warning "Unknown term: $Term"
            return $PurchaseDate
        }
    }
}

# Function to create a backup of reservation configuration
function Backup-ReservationConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject[]]$Reservations,
        
        [Parameter(Mandatory = $false)]
        [string]$BackupPath = ".\reservation-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    )
    
    try {
        $Reservations | ConvertTo-Json -Depth 5 | Out-File -FilePath $BackupPath -Encoding UTF8
        Write-Host "✓ Backup created: $BackupPath" -ForegroundColor Green
        return $BackupPath
    } catch {
        Write-Error "Failed to create backup: $($_.Exception.Message)"
        return $null
    }
}

# Function to generate a summary report
function New-ReservationSummaryReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject[]]$Reservations,
        
        [Parameter(Mandatory = $false)]
        [string]$ReportPath = ".\reservation-summary-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    )
    
    try {
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Azure Reservations Summary</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .summary { background-color: #e7f3ff; padding: 10px; margin-bottom: 20px; }
        .active { color: green; }
        .expired { color: red; }
    </style>
</head>
<body>
    <h1>Azure Reservations Summary</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Reservations: $($Reservations.Count)</p>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    </div>
    
    <table>
        <tr>
            <th>Display Name</th>
            <th>Product Type</th>
            <th>SKU</th>
            <th>Quantity</th>
            <th>Status</th>
            <th>Term</th>
            <th>Expiration Date</th>
            <th>Location</th>
        </tr>
"@

        foreach ($reservation in $Reservations) {
            $statusClass = if ($reservation.Status -eq "Active") { "active" } else { "expired" }
            $html += @"
        <tr>
            <td>$($reservation.DisplayName)</td>
            <td>$($reservation.ProductType)</td>
            <td>$($reservation.SKU)</td>
            <td>$($reservation.Quantity)</td>
            <td class="$statusClass">$($reservation.Status)</td>
            <td>$(Format-ReservationTerm -Term $reservation.Term)</td>
            <td>$($reservation.ExpirationDate)</td>
            <td>$($reservation.Location)</td>
        </tr>
"@
        }

        $html += @"
    </table>
</body>
</html>
"@

        $html | Out-File -FilePath $ReportPath -Encoding UTF8
        Write-Host "✓ Summary report created: $ReportPath" -ForegroundColor Green
        return $ReportPath
        
    } catch {
        Write-Error "Failed to create summary report: $($_.Exception.Message)"
        return $null
    }
}

# Export functions for use in other scripts
Export-ModuleMember -Function @(
    'Test-AzureModules',
    'Test-AzureAuthentication', 
    'Set-AzureSubscriptionContext',
    'Test-ReservationConfigFile',
    'Get-AzureLocationsForResource',
    'Format-ReservationTerm',
    'Get-ReservationExpirationDate',
    'Backup-ReservationConfig',
    'New-ReservationSummaryReport'
)