. (Join-Path $PSScriptRoot '..\scripts\powershell-bootstrap.ps1')
# Regression entrypoints mock the host platform; they never enable OS features.
function Test-WorkshopWsl2 { return $true }
$bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters @{} -RemainingArguments $args -DotSourced ($MyInvocation.InvocationName -eq '.')
if ($bootstrap.Handled) { exit $bootstrap.Code }

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
    function Test-WorkshopBootstrapInteractive { return $true }
    $script:InstallCalls = [Collections.Generic.List[string]]::new()
    $script:Approved = $false
    $script:NodeSuccess = $true
    $script:NodeUpdates = [Collections.Generic.List[bool]]::new()
    function Install-WorkshopNode { param([switch]$Update); $script:NodeUpdates.Add([bool]$Update); return $script:NodeSuccess }
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
    Assert-True ($script:InstallCalls.Count -eq 1) 'only missing Azure tools installed'
    Assert-True (@($script:InstallCalls | Where-Object { $_ -like '*OpenJS.NodeJS.LTS*' }).Count -eq 0) 'standalone Node package never selected'
    Assert-True ($script:NodeUpdates.Count -eq 2 -and -not $script:NodeUpdates[0]) '.NET Node uses shared nvm installer without update by default'
    Assert-True (@($script:InstallCalls | Where-Object { $_ -like '*Microsoft.Azd*' }).Count -eq 1) 'azd package selected'
    Assert-True (@($script:InstallCalls | Where-Object { $_ -like '*Microsoft.AzureCLI*' }).Count -eq 0) 'existing Azure CLI skipped'
    $Update = $true
    Assert-True (Install-WindowsTools dotnet) '.NET update succeeds'
    Assert-True ($script:NodeUpdates[2]) '.NET forwards update to nvm'
    Assert-True (Install-WindowsTools java) 'Java uses same nvm installer'
    Assert-True ($script:NodeUpdates[3]) 'Java forwards update to nvm'
    $script:NodeSuccess = $false
    Assert-True (-not (Install-WindowsTools dotnet)) '.NET nvm failure propagates'
    Assert-True (@($script:InstallCalls | Where-Object { $_ -like '*Microsoft.Azd*' }).Count -eq 3) 'Node failure does not block independent missing Azure tools'
    $script:NodeSuccess = $true
    function winget { $global:LASTEXITCODE=1 }
    Assert-True (-not (Install-WindowsTools dotnet)) 'installer failure propagates'
    foreach ($name in @('Get-Command','Confirm-ToolInstall','winget','Update-ProcessPath','Install-WorkshopNode')) { Remove-Item "Function:\$name" }
    $Update = $false
    $Track = 'dotnet'
    $script:PreparationSuccess = $true
    $script:ToolsSuccess = $true
    $script:MainCalls = [Collections.Generic.List[string]]::new()
    function Install-WindowsTools { $script:MainCalls.Add('install'); return $script:ToolsSuccess }
    function Initialize-AzureEnvironment { $script:MainCalls.Add('prepare'); return $script:PreparationSuccess }
    function Invoke-PrerequisiteMain { $script:MainCalls.Add('check'); return 0 }
    function Invoke-ToolProbe { return [pscustomobject]@{ Code = 0; Text = 'v22.0.0' } }
    Assert-True ((Invoke-InstallPrerequisiteMain) -eq 0) '.NET preparation and final check succeed'
    Assert-True (($script:MainCalls -join ',') -eq 'install,prepare,check') '.NET preparation occurs only after installation and before final check'
    $script:MainCalls.Clear()
    $script:PreparationSuccess = $false
    Assert-True ((Invoke-InstallPrerequisiteMain) -eq 1) 'Azure preparation failure survives successful final check'
    $script:MainCalls.Clear()
    $script:ToolsSuccess = $false
    Assert-True ((Invoke-InstallPrerequisiteMain) -eq 1) 'tool failure prevents preparation'
    Assert-True (($script:MainCalls -join ',') -eq 'install') 'failed tool setup skips Azure actions and probes'
    $script:MainCalls.Clear()
    $script:ToolsSuccess = $true
    $Track = 'java'
    Assert-True ((Invoke-InstallPrerequisiteMain) -eq 0) 'Java Windows host setup succeeds without Azure preparation'
    Assert-True (($script:MainCalls -join ',') -eq 'install') 'Java Azure preparation remains in WSL'
    foreach ($name in @('Install-WindowsTools','Initialize-AzureEnvironment','Invoke-PrerequisiteMain','Invoke-ToolProbe')) { Remove-Item "Function:\$name" }
    . (Join-Path $root 'scripts\powershell-bootstrap.ps1')
}

$savedCI = $env:CI
try {
    $env:CI='1'
    $Track='dotnet'
    if ($IsWindows) { Assert-True ((Invoke-InstallPrerequisiteMain) -eq 1) 'CI installation rejected' }
}
finally { $env:CI=$savedCI }
Write-Host "PASS: $script:Passed installation PowerShell assertions"
