$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'scripts\install-prerequisites.ps1') -Track dotnet
$script:Passed = 0
function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAILED: $Name" }
    $script:Passed++
}

$tokens = $null; $errors = $null
$null = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'scripts\install-prerequisites.ps1'), [ref]$tokens, [ref]$errors)
Assert-True ($errors.Count -eq 0) 'PowerShell syntax'

if ($IsWindows) {
    $script:InstallCalls = [Collections.Generic.List[string]]::new()
    $script:Approved = $false
    function Get-Command {
        [CmdletBinding()]param($Name, $CommandType)
        if ($Name -eq 'winget' -or $Name -eq 'az') { return [pscustomobject]@{ Source="fixture-$Name" } }
    }
    function Confirm-ToolInstall { param($Description); return $script:Approved }
    function winget { $script:InstallCalls.Add(($args -join ' ')); Write-Output 'installer progress'; $global:LASTEXITCODE=0 }
    function Update-ProcessPath { }
    Assert-True (Install-WindowsTools dotnet) 'declining succeeds without installer failure'
    Assert-True ($script:InstallCalls.Count -eq 0) 'declined tools never installed'
    $script:Approved = $true
    Assert-True (Install-WindowsTools dotnet) 'approved installations succeed'
    Assert-True ($script:InstallCalls.Count -eq 2) 'only missing tools installed'
    Assert-True (@($script:InstallCalls | Where-Object { $_ -like '*OpenJS.NodeJS.LTS*' }).Count -eq 1) 'Node package selected'
    Assert-True (@($script:InstallCalls | Where-Object { $_ -like '*Microsoft.Azd*' }).Count -eq 1) 'azd package selected'
    Assert-True (@($script:InstallCalls | Where-Object { $_ -like '*Microsoft.AzureCLI*' }).Count -eq 0) 'existing Azure CLI skipped'
    $script:InstallCalls.Clear()
    Assert-True (Install-WindowsTools java) 'Java host install succeeds'
    Assert-True ($script:InstallCalls.Count -eq 1 -and $script:InstallCalls[0] -like '*OpenJS.NodeJS.LTS*') 'Java host only offers Node'
    function winget { $global:LASTEXITCODE=1 }
    Assert-True (-not (Install-WindowsTools java)) 'installer failure propagates'
    foreach ($name in @('Get-Command','Confirm-ToolInstall','winget','Update-ProcessPath')) { Remove-Item "Function:\$name" }
}

$savedCI = $env:CI
try {
    $env:CI='1'
    $Track='dotnet'
    if ($IsWindows) { Assert-True ((Invoke-InstallPrerequisiteMain) -eq 1) 'CI installation rejected' }
}
finally { $env:CI=$savedCI }
Write-Host "PASS: $script:Passed installation PowerShell assertions"
