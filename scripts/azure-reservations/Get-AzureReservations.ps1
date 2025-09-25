#Requires -Modules Az.Reservations, Az.Accounts
<#
.SYNOPSIS
    Gets all Azure reservations for the current subscription or specified subscription.

.DESCRIPTION
    This script retrieves all Azure reservations including their details such as:
    - Reservation name and ID
    - Product type and SKU
    - Quantity and utilization
    - Status and expiration date
    - Applied scope

.PARAMETER SubscriptionId
    Optional. The subscription ID to query. If not provided, uses the current subscription context.

.PARAMETER OutputPath
    Optional. Path to export reservation details to JSON file.

.PARAMETER IncludeUtilization
    Optional. Include utilization data for each reservation.

.EXAMPLE
    .\Get-AzureReservations.ps1
    Gets all reservations in the current subscription.

.EXAMPLE
    .\Get-AzureReservations.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -OutputPath "reservations.json"
    Gets all reservations for a specific subscription and exports to JSON.

.NOTES
    Author: Generated for meinbus project
    Date: $(Get-Date -Format "yyyy-MM-dd")
    Requires: Az.Reservations and Az.Accounts PowerShell modules
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeUtilization
)

# Error handling
$ErrorActionPreference = "Stop"

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

    # Get all reservation orders
    Write-Host "Retrieving reservation orders..." -ForegroundColor Yellow
    $reservationOrders = Get-AzReservationOrder

    if (-not $reservationOrders) {
        Write-Warning "No reservation orders found in the current subscription."
        return
    }

    Write-Host "Found $($reservationOrders.Count) reservation order(s)" -ForegroundColor Green

    # Initialize array to store all reservation details
    $allReservations = @()

    foreach ($order in $reservationOrders) {
        Write-Host "Processing reservation order: $($order.Name)" -ForegroundColor Cyan
        
        # Get reservations for this order
        $reservations = Get-AzReservation -ReservationOrderId $order.Name
        
        foreach ($reservation in $reservations) {
            $reservationDetails = [PSCustomObject]@{
                OrderId = $order.Name
                ReservationId = $reservation.Name
                DisplayName = $reservation.DisplayName
                ProductType = $reservation.ReservedResourceType
                SKU = $reservation.SkuName
                Quantity = $reservation.Quantity
                Status = $reservation.Properties.ProvisioningState
                ExpirationDate = $reservation.Properties.ExpiryDate
                PurchaseDate = $reservation.Properties.PurchaseDate
                Term = $reservation.Properties.Term
                AppliedScopeType = $reservation.Properties.AppliedScopeType
                AppliedScopes = $reservation.Properties.AppliedScopes
                InstanceFlexibility = $reservation.Properties.InstanceFlexibility
                BillingFrequency = $reservation.Properties.BillingFrequency
                Location = $reservation.Location
                ExtendedStatusInfo = $reservation.Properties.ExtendedStatusInfo
            }

            # Add utilization data if requested
            if ($IncludeUtilization) {
                try {
                    Write-Host "  Getting utilization data for reservation: $($reservation.DisplayName)" -ForegroundColor Gray
                    $utilizationData = Get-AzReservationSummary -ReservationOrderId $order.Name -ReservationId $reservation.Name -Grain "daily"
                    $reservationDetails | Add-Member -MemberType NoteProperty -Name "UtilizationData" -Value $utilizationData
                } catch {
                    Write-Warning "Could not retrieve utilization data for reservation $($reservation.DisplayName): $($_.Exception.Message)"
                    $reservationDetails | Add-Member -MemberType NoteProperty -Name "UtilizationData" -Value $null
                }
            }

            $allReservations += $reservationDetails
        }
    }

    # Display summary
    Write-Host "`nSummary:" -ForegroundColor Yellow
    Write-Host "Total Reservations: $($allReservations.Count)" -ForegroundColor Green
    
    # Group by product type
    $groupedByProduct = $allReservations | Group-Object ProductType
    foreach ($group in $groupedByProduct) {
        Write-Host "  $($group.Name): $($group.Count) reservation(s)" -ForegroundColor Cyan
    }

    # Group by status
    $groupedByStatus = $allReservations | Group-Object Status
    foreach ($group in $groupedByStatus) {
        Write-Host "  Status $($group.Name): $($group.Count) reservation(s)" -ForegroundColor Cyan
    }

    # Export to JSON if path specified
    if ($OutputPath) {
        Write-Host "`nExporting reservation details to: $OutputPath" -ForegroundColor Yellow
        $allReservations | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "Export completed successfully!" -ForegroundColor Green
    }

    # Display detailed information
    Write-Host "`nDetailed Reservation Information:" -ForegroundColor Yellow
    $allReservations | Format-Table -Property DisplayName, ProductType, SKU, Quantity, Status, ExpirationDate -AutoSize

    return $allReservations

} catch {
    Write-Error "An error occurred while retrieving Azure reservations: $($_.Exception.Message)"
    exit 1
}