#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets up prerequisites for Azure Reservation management scripts.

.DESCRIPTION
    This script installs and configures the required components for managing Azure reservations:
    - Azure PowerShell modules (Az.Accounts, Az.Reservations)
    - Verifies PowerShell execution policy
    - Tests Azure connectivity
    - Provides initial configuration guidance

.PARAMETER Force
    Force installation/update of modules even if they already exist

.PARAMETER Scope
    Installation scope for PowerShell modules (CurrentUser or AllUsers)

.EXAMPLE
    .\Setup-Prerequisites.ps1
    Sets up prerequisites with default settings.

.EXAMPLE
    .\Setup-Prerequisites.ps1 -Force -Scope AllUsers
    Forces reinstallation of modules for all users.

.NOTES
    Author: Generated for meinbus project
    Date: $(Get-Date -Format "yyyy-MM-dd")
    Requires: PowerShell 5.1 or later
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("CurrentUser", "AllUsers")]
    [string]$Scope = "CurrentUser"
)

# Color functions for better output
function Write-Success { param([string]$Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Info { param([string]$Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }
function Write-Warning-Custom { param([string]$Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Error-Custom { param([string]$Message) Write-Host "✗ $Message" -ForegroundColor Red }

Write-Host ""
Write-Host "=== Azure Reservations Management Setup ===" -ForegroundColor Cyan
Write-Host "Setting up prerequisites for Azure reservation scripts..." -ForegroundColor White
Write-Host ""

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-Info "PowerShell Version: $($psVersion.Major).$($psVersion.Minor)"

if ($psVersion.Major -lt 5) {
    Write-Error-Custom "PowerShell 5.1 or later is required. Current version: $psVersion"
    exit 1
}

Write-Success "PowerShell version check passed"

# Check execution policy
$executionPolicy = Get-ExecutionPolicy
Write-Info "Current Execution Policy: $executionPolicy"

if ($executionPolicy -eq "Restricted") {
    Write-Warning-Custom "Execution policy is set to Restricted. This may prevent script execution."
    Write-Host "To change execution policy, run as Administrator:" -ForegroundColor Yellow
    Write-Host "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Cyan
    
    $changePolicy = Read-Host "Would you like to change the execution policy now? (y/N)"
    if ($changePolicy -match "^[Yy]") {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Success "Execution policy updated to RemoteSigned"
        } catch {
            Write-Error-Custom "Failed to update execution policy: $($_.Exception.Message)"
        }
    }
}

# Required modules
$requiredModules = @(
    @{ Name = "Az.Accounts"; MinVersion = "2.0.0" },
    @{ Name = "Az.Reservations"; MinVersion = "1.0.0" }
)

Write-Host ""
Write-Host "Checking Azure PowerShell modules..." -ForegroundColor Yellow

foreach ($moduleInfo in $requiredModules) {
    $moduleName = $moduleInfo.Name
    $minVersion = $moduleInfo.MinVersion
    
    Write-Info "Checking $moduleName (minimum version: $minVersion)..."
    
    $installedModule = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
    
    if ($installedModule -and (-not $Force)) {
        if ($installedModule.Version -ge [Version]$minVersion) {
            Write-Success "$moduleName version $($installedModule.Version) is already installed"
            continue
        } else {
            Write-Warning-Custom "$moduleName version $($installedModule.Version) is below minimum required version $minVersion"
        }
    }
    
    Write-Info "Installing/updating $moduleName..."
    try {
        Install-Module -Name $moduleName -Scope $Scope -Force -AllowClobber
        $newModule = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
        Write-Success "$moduleName version $($newModule.Version) installed successfully"
    } catch {
        Write-Error-Custom "Failed to install $moduleName: $($_.Exception.Message)"
        exit 1
    }
}

# Test module import
Write-Host ""
Write-Host "Testing module imports..." -ForegroundColor Yellow

foreach ($moduleInfo in $requiredModules) {
    $moduleName = $moduleInfo.Name
    try {
        Import-Module $moduleName -Force
        Write-Success "Successfully imported $moduleName"
    } catch {
        Write-Error-Custom "Failed to import $moduleName: $($_.Exception.Message)"
        exit 1
    }
}

# Test Azure connectivity (if already authenticated)
Write-Host ""
Write-Host "Testing Azure connectivity..." -ForegroundColor Yellow

try {
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if ($context) {
        Write-Success "Already authenticated to Azure as: $($context.Account.Id)"
        Write-Success "Current subscription: $($context.Subscription.Name)"
        
        # Test API call
        try {
            $subscriptions = Get-AzSubscription -ErrorAction Stop
            Write-Success "Successfully retrieved $($subscriptions.Count) subscription(s)"
        } catch {
            Write-Warning-Custom "Authentication exists but API calls are failing: $($_.Exception.Message)"
        }
    } else {
        Write-Info "Not currently authenticated to Azure"
        Write-Host "To authenticate, run: Connect-AzAccount" -ForegroundColor Cyan
        
        $authenticate = Read-Host "Would you like to authenticate now? (y/N)"
        if ($authenticate -match "^[Yy]") {
            try {
                Connect-AzAccount
                $newContext = Get-AzContext
                Write-Success "Successfully authenticated as: $($newContext.Account.Id)"
            } catch {
                Write-Warning-Custom "Authentication failed: $($_.Exception.Message)"
            }
        }
    }
} catch {
    Write-Warning-Custom "Could not check Azure connectivity: $($_.Exception.Message)"
}

# Create sample configuration if it doesn't exist
$configPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "config.json"
if (-not (Test-Path $configPath)) {
    Write-Info "Creating sample configuration file..."
    # Note: The config.json file should already exist, but this is a backup
    $sampleConfig = @{
        defaultSettings = @{
            term = "P1Y"
            billingFrequency = "Monthly"
            appliedScopeType = "Shared"
            location = "West Europe"
        }
    }
    $sampleConfig | ConvertTo-Json -Depth 3 | Out-File -FilePath $configPath -Encoding UTF8
    Write-Success "Sample configuration created: $configPath"
}

# Display next steps
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Authenticate to Azure (if not done already):"
Write-Host "   Connect-AzAccount" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Set your subscription context:"
Write-Host "   Set-AzContext -SubscriptionId 'your-subscription-id'" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. List your current reservations:"
Write-Host "   .\Get-AzureReservations.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Export reservations for backup:"
Write-Host "   .\Get-AzureReservations.ps1 -OutputPath 'backup.json'" -ForegroundColor Cyan
Write-Host ""
Write-Host "5. Use the management script for unified operations:"
Write-Host "   .\Manage-AzureReservations.ps1 -Action List" -ForegroundColor Cyan
Write-Host ""

# Display available scripts
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = Get-ChildItem -Path $scriptPath -Filter "*.ps1" | Where-Object { $_.Name -ne "Setup-Prerequisites.ps1" }

if ($scripts) {
    Write-Host "Available scripts in this directory:" -ForegroundColor Yellow
    foreach ($script in $scripts) {
        Write-Host "  • $($script.Name)" -ForegroundColor White
    }
    Write-Host ""
}

Write-Host "For detailed documentation, see README.md" -ForegroundColor Cyan
Write-Success "Setup completed successfully!"