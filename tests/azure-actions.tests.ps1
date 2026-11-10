. (Join-Path $PSScriptRoot '..\scripts\powershell-bootstrap.ps1')
# Regression entrypoints mock the host platform; they never enable OS features.
function Test-WorkshopWsl2 { return $true }
$bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters @{} -RemainingArguments $args -DotSourced ($MyInvocation.InvocationName -eq '.')
if ($bootstrap.Handled) { exit $bootstrap.Code }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\check-prerequisites.ps1')
$script:CheckResults = [Collections.Generic.List[object]]::new()
$script:Calls = [Collections.Generic.List[string]]::new()
$script:Approved = $false
$script:LoggedIn = $false
$script:Selected = 'id-two'
$script:ActionFails = $false
function Assert-Action([bool]$Condition) { if (-not $Condition) { throw 'Azure action assertion failed' } }
function Test-AzurePrompt { return $true }
function Confirm-AzureAction { return $script:Approved }
function Read-Host { return $script:Selected }
function Invoke-ToolProbe {
    param([string]$Name, [string[]]$Arguments)
    $text = ''; $code = 0
    switch ("$Name $($Arguments -join ' ')") {
        'az account show --query state --output tsv' {
            if ($script:LoggedIn) { $text = 'Enabled' } else { $code = 1; $text = 'fixture auth error' }
        }
        'az account list --query [].[id,name] --output tsv' { $text = "id-one`tFirst`nid-two`tSecond" }
        'az extension show --name containerapp --query version --output tsv' { $code = 1 }
        'azd auth login --check-status' { $code = 1 }
        default { throw "Unexpected probe: $Name $Arguments" }
    }
    return [pscustomobject]@{ Code = $code; Text = $text }
}
function Invoke-AzureAction {
    param([string]$Name, [string[]]$Arguments)
    $script:Calls.Add("$Name $($Arguments -join ' ')")
    $script:LoggedIn = $true
    return -not $script:ActionFails
}
Initialize-AzureAccount
Initialize-ContainerappExtension
Initialize-AzdLogin
Assert-Action ($script:Calls.Count -eq 0)
$script:Approved = $true
Initialize-AzureAccount
Assert-Action (($script:Calls -join ';') -eq 'az login;az account set --subscription id-two')
$script:Calls.Clear()
$script:Selected = 'invalid'
Initialize-AzureAccount
Assert-Action ($script:Calls.Count -eq 0)
Initialize-ContainerappExtension
Initialize-AzdLogin
Assert-Action (($script:Calls -join ';') -eq 'az extension add --name containerapp --upgrade;azd auth login')
$script:Calls.Clear()
$script:ActionFails = $true
$script:LoggedIn = $false
Initialize-AzureAccount
Assert-Action (($script:Calls -join ';') -eq 'az login')
$script:Calls.Clear()
function Test-AzurePrompt { return $false }
Initialize-AzureAccount
Initialize-ContainerappExtension
Initialize-AzdLogin
Assert-Action ($script:Calls.Count -eq 0)
Remove-Item Function:\Read-Host
. (Join-Path $PSScriptRoot '..\scripts\check-prerequisites.ps1')
function Test-AzurePrompt { return $true }
function Confirm-AzureAction { return $script:Approved }
$script:Registered = $false
$script:QueryFails = $false
$script:Approved = $true
function Invoke-ToolProbe {
    param([string]$Name, [string[]]$Arguments)
    return [pscustomobject]@{
        Code = $(if ($script:QueryFails) { 1 } else { 0 })
        Text = $(if ($script:Registered) { 'Registered' } else { 'NotRegistered' })
    }
}
function Invoke-AzureAction {
    param([string]$Name, [string[]]$Arguments)
    $script:Calls.Add("$Name $($Arguments -join ' ')")
    $script:Registered = $true
    return $true
}
Test-AzureProvider Microsoft.App
Assert-Action (($script:Calls -join ';') -eq 'az provider register --namespace Microsoft.App --wait')
$script:Calls.Clear()
Test-AzureProvider Microsoft.App
Assert-Action ($script:Calls.Count -eq 0)
$script:Registered = $false
$script:QueryFails = $true
Test-AzureProvider Microsoft.App
Assert-Action ($script:Calls.Count -eq 0)
Assert-Action ($script:CheckResults[-1].Status -eq 'FAIL')
$script:QueryFails = $false
$script:Approved = $false
Test-AzureProvider Microsoft.App
Assert-Action ($script:Calls.Count -eq 0)
. (Join-Path $PSScriptRoot '..\scripts\check-prerequisites.ps1')
$savedCI = $env:CI
try {
    $env:CI = '1'
    Assert-Action (-not (Confirm-AzureAction 'must not prompt'))
}
finally { $env:CI = $savedCI }
Write-Host 'PASS: Azure action approval, selection, failure and noninteractive cases'
