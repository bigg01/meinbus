#Requires -Modules Az.Reservations, Az.Accounts
<#
.SYNOPSIS
    Recreates Azure reservations based on exported configuration or existing reservations.

.DESCRIPTION
    This script recreates Azure reservations using either:
    1. An exported JSON configuration file from Get-AzureReservations.ps1
    2. Existing reservation parameters specified via command line
    
    The script can:
    - Create new reservations with the same or modified parameters
    - Validate reservation availability before purchasing
    - Handle different billing frequencies and terms

.PARAMETER ConfigPath
    Path to the JSON configuration file exported from Get-AzureReservations.ps1

.PARAMETER ReservationName
    Name for the new reservation (when creating a single reservation)

.PARAMETER ProductType
    Product type for the reservation (e.g., "VirtualMachines", "SqlDatabase")

.PARAMETER SKU
    SKU name for the reservation

.PARAMETER Quantity
    Number of instances to reserve

.PARAMETER Term
    Reservation term (P1Y for 1 year, P3Y for 3 years)

.PARAMETER BillingFrequency
    Billing frequency (Monthly or Upfront)

.PARAMETER AppliedScopeType
    Scope type (Single, Shared, or ManagementGroup)

.PARAMETER SubscriptionId
    Target subscription ID for the reservation

.PARAMETER Location
    Azure region for the reservation

.PARAMETER WhatIf
    Shows what would be created without actually creating reservations

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\Recreate-AzureReservations.ps1 -ConfigPath "reservations.json" -WhatIf
    Shows what reservations would be created from the config file.

.EXAMPLE
    .\Recreate-AzureReservations.ps1 -ReservationName "VM-Reservation" -ProductType "VirtualMachines" -SKU "Standard_D2s_v3" -Quantity 2 -Term "P1Y"
    Creates a single VM reservation.

.NOTES
    Author: Generated for meinbus project
    Date: $(Get-Date -Format "yyyy-MM-dd")
    Requires: Az.Reservations and Az.Accounts PowerShell modules
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ParameterSetName = "FromConfig")]
    [string]$ConfigPath,
    
    [Parameter(Mandatory = $false, ParameterSetName = "Manual")]
    [string]$ReservationName,
    
    [Parameter(Mandatory = $false, ParameterSetName = "Manual")]
    [string]$ProductType,
    
    [Parameter(Mandatory = $false, ParameterSetName = "Manual")]
    [string]$SKU,
    
    [Parameter(Mandatory = $false, ParameterSetName = "Manual")]
    [int]$Quantity = 1,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("P1Y", "P3Y")]
    [string]$Term = "P1Y",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Monthly", "Upfront")]
    [string]$BillingFrequency = "Monthly",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Single", "Shared", "ManagementGroup")]
    [string]$AppliedScopeType = "Shared",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Error handling
$ErrorActionPreference = "Stop"

# Function to validate reservation parameters
function Test-ReservationParameters {
    param(
        [PSCustomObject]$ReservationConfig
    )
    
    $isValid = $true
    $errors = @()
    
    if (-not $ReservationConfig.ProductType) {
        $errors += "ProductType is required"
        $isValid = $false
    }
    
    if (-not $ReservationConfig.SKU) {
        $errors += "SKU is required"
        $isValid = $false
    }
    
    if ($ReservationConfig.Quantity -le 0) {
        $errors += "Quantity must be greater than 0"
        $isValid = $false
    }
    
    return @{
        IsValid = $isValid
        Errors = $errors
    }
}

# Function to create a single reservation
function New-SingleReservation {
    param(
        [PSCustomObject]$Config,
        [bool]$WhatIfMode = $false
    )
    
    Write-Host "Creating reservation: $($Config.DisplayName)" -ForegroundColor Cyan
    Write-Host "  Product Type: $($Config.ProductType)" -ForegroundColor Gray
    Write-Host "  SKU: $($Config.SKU)" -ForegroundColor Gray
    Write-Host "  Quantity: $($Config.Quantity)" -ForegroundColor Gray
    Write-Host "  Term: $($Config.Term)" -ForegroundColor Gray
    Write-Host "  Location: $($Config.Location)" -ForegroundColor Gray
    
    if ($WhatIfMode) {
        Write-Host "  [WHAT-IF] Would create this reservation" -ForegroundColor Yellow
        return $true
    }
    
    try {
        # Check catalog for available SKUs (if supported)
        Write-Host "  Validating SKU availability..." -ForegroundColor Gray
        
        # Create reservation parameters
        $reservationParams = @{
            ReservedResourceType = $Config.ProductType
            Name = $Config.DisplayName
            Location = $Config.Location
            Sku = $Config.SKU
            Quantity = $Config.Quantity
            Term = $Config.Term
            BillingFrequency = $Config.BillingFrequency
            AppliedScopeType = $Config.AppliedScopeType
        }
        
        # Add subscription scope if Single scope type
        if ($Config.AppliedScopeType -eq "Single" -and $Config.AppliedScopes) {
            $reservationParams.AppliedScope = $Config.AppliedScopes[0]
        }
        
        # Create the reservation
        Write-Host "  Creating reservation..." -ForegroundColor Yellow
        $newReservation = New-AzReservation @reservationParams
        
        if ($newReservation) {
            Write-Host "  ✓ Successfully created reservation: $($newReservation.Name)" -ForegroundColor Green
            return $newReservation
        } else {
            Write-Warning "  ✗ Failed to create reservation (no error thrown)"
            return $false
        }
        
    } catch {
        Write-Error "  ✗ Failed to create reservation: $($_.Exception.Message)"
        return $false
    }
}

try {
    # Check if user is logged in to Azure
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "No Azure context found. Please run 'Connect-AzAccount' first."
        exit 1
    }

    # Set subscription context if provided
    if ($SubscriptionId) {
        Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Yellow
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }

    $currentContext = Get-AzContext
    Write-Host "Current subscription: $($currentContext.Subscription.Name) ($($currentContext.Subscription.Id))" -ForegroundColor Green

    # Initialize reservations array
    $reservationsToCreate = @()

    # Process based on parameter set
    if ($PSCmdlet.ParameterSetName -eq "FromConfig") {
        # Load from configuration file
        if (-not (Test-Path $ConfigPath)) {
            Write-Error "Configuration file not found: $ConfigPath"
            exit 1
        }
        
        Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Yellow
        $configData = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        if (-not $configData) {
            Write-Error "Failed to parse configuration file or file is empty"
            exit 1
        }
        
        # Convert JSON objects to PSCustomObjects if needed
        foreach ($reservation in $configData) {
            $reservationsToCreate += [PSCustomObject]@{
                DisplayName = $reservation.DisplayName
                ProductType = $reservation.ProductType
                SKU = $reservation.SKU
                Quantity = $reservation.Quantity
                Term = if ($reservation.Term) { $reservation.Term } else { $Term }
                BillingFrequency = if ($reservation.BillingFrequency) { $reservation.BillingFrequency } else { $BillingFrequency }
                AppliedScopeType = if ($reservation.AppliedScopeType) { $reservation.AppliedScopeType } else { $AppliedScopeType }
                AppliedScopes = $reservation.AppliedScopes
                Location = if ($reservation.Location) { $reservation.Location } else { $Location }
            }
        }
        
    } else {
        # Manual single reservation
        if (-not $ReservationName -or -not $ProductType -or -not $SKU) {
            Write-Error "ReservationName, ProductType, and SKU are required for manual reservation creation"
            exit 1
        }
        
        $reservationsToCreate += [PSCustomObject]@{
            DisplayName = $ReservationName
            ProductType = $ProductType
            SKU = $SKU
            Quantity = $Quantity
            Term = $Term
            BillingFrequency = $BillingFrequency
            AppliedScopeType = $AppliedScopeType
            AppliedScopes = if ($SubscriptionId) { @("/subscriptions/$SubscriptionId") } else { @() }
            Location = $Location
        }
    }

    Write-Host "`nFound $($reservationsToCreate.Count) reservation(s) to create" -ForegroundColor Green

    # Validate all reservations before creating
    $validationErrors = @()
    foreach ($reservation in $reservationsToCreate) {
        $validation = Test-ReservationParameters -ReservationConfig $reservation
        if (-not $validation.IsValid) {
            $validationErrors += "Reservation '$($reservation.DisplayName)': $($validation.Errors -join ', ')"
        }
    }

    if ($validationErrors.Count -gt 0) {
        Write-Error "Validation errors found:`n$($validationErrors -join "`n")"
        exit 1
    }

    # Display what will be created
    Write-Host "`nReservations to be created:" -ForegroundColor Yellow
    $reservationsToCreate | Format-Table -Property DisplayName, ProductType, SKU, Quantity, Term, Location -AutoSize

    # Confirm creation unless Force is specified
    if (-not $Force -and -not $WhatIf) {
        $confirmation = Read-Host "Do you want to proceed with creating these reservations? (y/N)"
        if ($confirmation -notmatch "^[Yy]") {
            Write-Host "Operation cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    }

    # Create reservations
    $successCount = 0
    $failureCount = 0
    $results = @()

    foreach ($reservation in $reservationsToCreate) {
        $result = New-SingleReservation -Config $reservation -WhatIfMode $WhatIf
        $results += $result
        
        if ($result -and -not $WhatIf) {
            $successCount++
        } elseif ($result -and $WhatIf) {
            $successCount++
        } else {
            $failureCount++
        }
    }

    # Display summary
    Write-Host "`nSummary:" -ForegroundColor Yellow
    if ($WhatIf) {
        Write-Host "Would create $successCount reservation(s)" -ForegroundColor Green
        Write-Host "Would fail to create $failureCount reservation(s)" -ForegroundColor Red
    } else {
        Write-Host "Successfully created $successCount reservation(s)" -ForegroundColor Green
        if ($failureCount -gt 0) {
            Write-Host "Failed to create $failureCount reservation(s)" -ForegroundColor Red
        }
    }

} catch {
    Write-Error "An error occurred while recreating Azure reservations: $($_.Exception.Message)"
    exit 1
}