# Azure Reservations Management Scripts

This directory contains PowerShell scripts for managing Azure reservations, allowing you to get all reservations and recreate them as needed.

## Prerequisites

### Required PowerShell Modules
```powershell
Install-Module -Name Az.Accounts -Scope CurrentUser -Force
Install-Module -Name Az.Reservations -Scope CurrentUser -Force
```

### Authentication
Before running any scripts, authenticate to Azure:
```powershell
Connect-AzAccount
```

Set the subscription context if needed:
```powershell
Set-AzContext -SubscriptionId "your-subscription-id"
```

## Scripts Overview

### 1. Get-AzureReservations.ps1
**Purpose**: Retrieves all Azure reservations from a subscription and exports them to JSON.

**Features**:
- Lists all reservation orders and individual reservations
- Includes detailed information (SKU, quantity, status, expiration, etc.)
- Optional utilization data retrieval
- Export to JSON for backup/recreation purposes
- Summary reporting by product type and status

**Usage Examples**:
```powershell
# Get all reservations in current subscription
.\Get-AzureReservations.ps1

# Get reservations for specific subscription and export to JSON
.\Get-AzureReservations.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -OutputPath "reservations.json"

# Include utilization data
.\Get-AzureReservations.ps1 -IncludeUtilization -OutputPath "reservations-with-usage.json"
```

### 2. Recreate-AzureReservations.ps1
**Purpose**: Recreates Azure reservations based on exported configuration or manual parameters.

**Features**:
- Create reservations from exported JSON configuration
- Create individual reservations with manual parameters
- Validation of reservation parameters before creation
- WhatIf mode to preview changes
- Detailed progress reporting

**Usage Examples**:
```powershell
# Recreate from exported configuration (preview mode)
.\Recreate-AzureReservations.ps1 -ConfigPath "reservations.json" -WhatIf

# Recreate from configuration file
.\Recreate-AzureReservations.ps1 -ConfigPath "reservations.json" -Force

# Create a single reservation manually
.\Recreate-AzureReservations.ps1 -ReservationName "VM-Reservation" -ProductType "VirtualMachines" -SKU "Standard_D2s_v3" -Quantity 2 -Term "P1Y"
```

### 3. Manage-AzureReservations.ps1
**Purpose**: Unified management interface for all reservation operations.

**Features**:
- List, export, import, and recreate reservations
- Generate HTML reports
- Backup operations
- Interactive menu system

**Usage Examples**:
```powershell
# List all reservations
.\Manage-AzureReservations.ps1 -Action List

# Export reservations to backup file
.\Manage-AzureReservations.ps1 -Action Export -OutputPath "backup.json"

# Generate HTML report
.\Manage-AzureReservations.ps1 -Action Report -OutputPath "report.html"

# Recreate from backup (preview)
.\Manage-AzureReservations.ps1 -Action Recreate -ConfigPath "backup.json" -WhatIf
```

### 4. Common-Functions.ps1
**Purpose**: Shared utility functions used by other scripts.

**Functions**:
- `Test-AzureModules`: Check if required modules are installed
- `Test-AzureAuthentication`: Verify Azure authentication
- `Set-AzureSubscriptionContext`: Set subscription context
- `Test-ReservationConfigFile`: Validate configuration files
- `New-ReservationSummaryReport`: Generate HTML reports
- And more utility functions...

### 5. config.json
**Purpose**: Configuration template with common reservation settings.

**Contains**:
- Default settings for terms, billing frequency, scope
- Subscription definitions for different environments
- Common reservation templates
- Environment-specific configurations

## Configuration File Format

The JSON configuration file should contain an array of reservation objects:

```json
[
  {
    "DisplayName": "VM-Standard-D2s-v3-Reservation",
    "ProductType": "VirtualMachines",
    "SKU": "Standard_D2s_v3",
    "Quantity": 2,
    "Term": "P1Y",
    "BillingFrequency": "Monthly",
    "AppliedScopeType": "Shared",
    "Location": "West Europe"
  }
]
```

## Common Parameters

### Reservation Terms
- `P1Y`: 1 Year reservation
- `P3Y`: 3 Year reservation

### Billing Frequency
- `Monthly`: Monthly billing
- `Upfront`: Upfront payment

### Applied Scope Types
- `Single`: Single subscription scope
- `Shared`: Shared across subscriptions in enrollment
- `ManagementGroup`: Management group scope

### Common Product Types
- `VirtualMachines`: Azure Virtual Machines
- `SqlDatabase`: Azure SQL Database
- `AppService`: Azure App Service Plans
- `Storage`: Azure Storage
- `CosmosDB`: Azure Cosmos DB

## Workflow Examples

### Complete Backup and Restore Process

1. **Create a backup of existing reservations**:
```powershell
.\Get-AzureReservations.ps1 -OutputPath "reservation-backup.json"
```

2. **Review the backup file**:
```powershell
Get-Content "reservation-backup.json" | ConvertFrom-Json | Format-Table
```

3. **Test recreation (WhatIf mode)**:
```powershell
.\Recreate-AzureReservations.ps1 -ConfigPath "reservation-backup.json" -WhatIf
```

4. **Recreate reservations**:
```powershell
.\Recreate-AzureReservations.ps1 -ConfigPath "reservation-backup.json" -Force
```

### Cross-Subscription Migration

1. **Export from source subscription**:
```powershell
.\Get-AzureReservations.ps1 -SubscriptionId "source-sub-id" -OutputPath "source-reservations.json"
```

2. **Recreate in target subscription**:
```powershell
.\Recreate-AzureReservations.ps1 -ConfigPath "source-reservations.json" -SubscriptionId "target-sub-id" -WhatIf
```

### Reporting and Analysis

1. **Generate comprehensive report**:
```powershell
.\Manage-AzureReservations.ps1 -Action Report -OutputPath "reservation-analysis.html"
```

2. **List reservations with filtering**:
```powershell
.\Get-AzureReservations.ps1 -IncludeUtilization | Where-Object { $_.ProductType -eq "VirtualMachines" }
```

## Error Handling

All scripts include comprehensive error handling:
- Validation of prerequisites (modules, authentication)
- Parameter validation
- Graceful handling of API errors
- Detailed error messages with troubleshooting guidance

## Security Considerations

- Scripts require appropriate Azure RBAC permissions
- No credentials are stored in configuration files
- All operations are logged for audit purposes
- WhatIf mode available for safe testing

## Troubleshooting

### Common Issues

1. **Module not found errors**:
   ```powershell
   Install-Module -Name Az.Reservations -Scope CurrentUser -Force
   ```

2. **Authentication errors**:
   ```powershell
   Connect-AzAccount
   Set-AzContext -SubscriptionId "your-subscription-id"
   ```

3. **Permission errors**:
   - Ensure your account has Reservation Administrator or higher permissions
   - Check RBAC assignments in the Azure portal

4. **API rate limiting**:
   - Scripts include retry logic for transient failures
   - Consider adding delays between operations for large numbers of reservations

### Support

- Check Azure PowerShell documentation: https://docs.microsoft.com/en-us/powershell/azure/
- Review Azure Reservations API documentation
- Enable verbose logging with `-Verbose` parameter

## Version History

- v1.0: Initial implementation with basic get/recreate functionality
- Features: Comprehensive reservation management, reporting, and backup capabilities