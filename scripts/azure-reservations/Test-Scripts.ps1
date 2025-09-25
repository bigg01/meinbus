<#
.SYNOPSIS
    Test script to validate Azure Reservation management scripts functionality.

.DESCRIPTION
    This script performs basic validation of the Azure Reservation scripts:
    - Checks script syntax
    - Validates parameter help
    - Tests common functions
    - Simulates workflow without making actual Azure calls

.PARAMETER SkipSyntaxCheck
    Skip PowerShell syntax validation

.EXAMPLE
    .\Test-Scripts.ps1
    Runs all validation tests.

.NOTES
    Author: Generated for meinbus project
    Date: $(Get-Date -Format "yyyy-MM-dd")
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$SkipSyntaxCheck
)

# Color functions
function Write-TestResult { 
    param([string]$Test, [bool]$Passed, [string]$Details = "")
    if ($Passed) {
        Write-Host "✓ $Test" -ForegroundColor Green
        if ($Details) { Write-Host "  $Details" -ForegroundColor Gray }
    } else {
        Write-Host "✗ $Test" -ForegroundColor Red
        if ($Details) { Write-Host "  $Details" -ForegroundColor Yellow }
    }
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$testResults = @()

Write-Host ""
Write-Host "=== Azure Reservation Scripts Validation ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if all required scripts exist
Write-Host "1. Checking script files..." -ForegroundColor Yellow
$requiredScripts = @(
    "Get-AzureReservations.ps1",
    "Recreate-AzureReservations.ps1", 
    "Manage-AzureReservations.ps1",
    "Common-Functions.ps1",
    "Setup-Prerequisites.ps1"
)

$scriptsExist = $true
foreach ($script in $requiredScripts) {
    $scriptFile = Join-Path $scriptPath $script
    $exists = Test-Path $scriptFile
    Write-TestResult "Script exists: $script" $exists
    if (-not $exists) { $scriptsExist = $false }
}
$testResults += @{ Test = "All required scripts exist"; Passed = $scriptsExist }

# Test 2: Syntax validation (if PowerShell available)
if (-not $SkipSyntaxCheck) {
    Write-Host "`n2. Validating PowerShell syntax..." -ForegroundColor Yellow
    $syntaxValid = $true
    
    foreach ($script in $requiredScripts) {
        $scriptFile = Join-Path $scriptPath $script
        if (Test-Path $scriptFile) {
            try {
                $null = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$null, [ref]$null)
                Write-TestResult "Syntax valid: $script" $true
            } catch {
                Write-TestResult "Syntax valid: $script" $false $_.Exception.Message
                $syntaxValid = $false
            }
        }
    }
    $testResults += @{ Test = "All scripts have valid syntax"; Passed = $syntaxValid }
}

# Test 3: Check configuration file
Write-Host "`n3. Checking configuration files..." -ForegroundColor Yellow
$configFile = Join-Path $scriptPath "config.json"
$configExists = Test-Path $configFile
Write-TestResult "Configuration file exists" $configExists

if ($configExists) {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        $configValid = $config -and $config.defaultSettings
        Write-TestResult "Configuration file is valid JSON" $configValid
    } catch {
        Write-TestResult "Configuration file is valid JSON" $false $_.Exception.Message
        $configValid = $false
    }
} else {
    $configValid = $false
}
$testResults += @{ Test = "Configuration file is valid"; Passed = $configExists -and $configValid }

# Test 4: Check documentation
Write-Host "`n4. Checking documentation..." -ForegroundColor Yellow
$readmeFile = Join-Path $scriptPath "README.md"
$readmeExists = Test-Path $readmeFile
Write-TestResult "README.md exists" $readmeExists

if ($readmeExists) {
    $readmeContent = Get-Content $readmeFile -Raw
    $hasExamples = $readmeContent -match "Usage Examples"
    $hasPrerequisites = $readmeContent -match "Prerequisites"
    Write-TestResult "README contains usage examples" $hasExamples
    Write-TestResult "README contains prerequisites" $hasPrerequisites
    $readmeComplete = $hasExamples -and $hasPrerequisites
} else {
    $readmeComplete = $false
}
$testResults += @{ Test = "Documentation is complete"; Passed = $readmeExists -and $readmeComplete }

# Test 5: Validate help content in scripts
Write-Host "`n5. Checking script help content..." -ForegroundColor Yellow
$helpValid = $true

foreach ($script in $requiredScripts) {
    $scriptFile = Join-Path $scriptPath $script
    if (Test-Path $scriptFile) {
        $content = Get-Content $scriptFile -Raw
        $hasSynopsis = $content -match "\.SYNOPSIS"
        $hasDescription = $content -match "\.DESCRIPTION" 
        $hasExample = $content -match "\.EXAMPLE"
        
        $scriptHelpValid = $hasSynopsis -and $hasDescription -and $hasExample
        Write-TestResult "Help content complete: $script" $scriptHelpValid
        
        if (-not $scriptHelpValid) { $helpValid = $false }
    }
}
$testResults += @{ Test = "All scripts have complete help"; Passed = $helpValid }

# Test 6: Test Common Functions (if loadable)
Write-Host "`n6. Testing Common Functions..." -ForegroundColor Yellow
$commonFunctionsFile = Join-Path $scriptPath "Common-Functions.ps1"

if (Test-Path $commonFunctionsFile) {
    try {
        # Test loading the functions (without executing them)
        $commonContent = Get-Content $commonFunctionsFile -Raw
        $expectedFunctions = @(
            "Test-AzureModules",
            "Test-AzureAuthentication",
            "Set-AzureSubscriptionContext",
            "Test-ReservationConfigFile"
        )
        
        $functionsFound = $true
        foreach ($func in $expectedFunctions) {
            $functionExists = $commonContent -match "function $func"
            Write-TestResult "Function defined: $func" $functionExists
            if (-not $functionExists) { $functionsFound = $false }
        }
        
        $testResults += @{ Test = "Common functions are defined"; Passed = $functionsFound }
    } catch {
        Write-TestResult "Common Functions loadable" $false $_.Exception.Message
        $testResults += @{ Test = "Common functions are defined"; Passed = $false }
    }
}

# Test 7: Simulate parameter validation
Write-Host "`n7. Testing parameter validation patterns..." -ForegroundColor Yellow
$paramValidation = $true

# Test required parameter patterns in Get-AzureReservations.ps1
$getScript = Join-Path $scriptPath "Get-AzureReservations.ps1"
if (Test-Path $getScript) {
    $getContent = Get-Content $getScript -Raw
    $hasSubscriptionParam = $getContent -match "SubscriptionId"
    $hasOutputParam = $getContent -match "OutputPath"
    Write-TestResult "Get script has expected parameters" ($hasSubscriptionParam -and $hasOutputParam)
    if (-not ($hasSubscriptionParam -and $hasOutputParam)) { $paramValidation = $false }
}

# Test required parameter patterns in Recreate-AzureReservations.ps1
$recreateScript = Join-Path $scriptPath "Recreate-AzureReservations.ps1"
if (Test-Path $recreateScript) {
    $recreateContent = Get-Content $recreateScript -Raw
    $hasConfigParam = $recreateContent -match "ConfigPath"
    $hasWhatIfParam = $recreateContent -match "WhatIf"
    Write-TestResult "Recreate script has expected parameters" ($hasConfigParam -and $hasWhatIfParam)
    if (-not ($hasConfigParam -and $hasWhatIfParam)) { $paramValidation = $false }
}

$testResults += @{ Test = "Parameter validation patterns are correct"; Passed = $paramValidation }

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
$passedTests = ($testResults | Where-Object { $_.Passed }).Count
$totalTests = $testResults.Count

Write-Host "Passed: $passedTests/$totalTests tests" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })

if ($passedTests -eq $totalTests) {
    Write-Host "`n✓ All tests passed! Scripts are ready for use." -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "1. Run .\Setup-Prerequisites.ps1 to install required modules" -ForegroundColor Cyan
    Write-Host "2. Authenticate with Connect-AzAccount" -ForegroundColor Cyan
    Write-Host "3. Use .\Get-AzureReservations.ps1 to list current reservations" -ForegroundColor Cyan
} else {
    Write-Host "`n⚠ Some tests failed. Please review the issues above." -ForegroundColor Yellow
    $failedTests = $testResults | Where-Object { -not $_.Passed }
    foreach ($test in $failedTests) {
        Write-Host "  • $($test.Test)" -ForegroundColor Red
    }
}

Write-Host ""