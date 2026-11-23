[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'powershell-bootstrap.ps1')
$bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters $PSBoundParameters -RemainingArguments $args -DotSourced ($MyInvocation.InvocationName -eq '.')
if ($bootstrap.Handled) { exit $bootstrap.Code }

function Invoke-ApplyJava042Snapshot {
    $workshopRoot = Split-Path $PSScriptRoot -Parent
    $appRoot = Join-Path $workshopRoot 'java'
    $snapshot = Join-Path $workshopRoot 'snapshots\java\04-2'
    $backup = Join-Path $workshopRoot 'java-04-2'
    $currentDirectory = [IO.Path]::GetFullPath((Get-Location).ProviderPath).TrimEnd('\', '/')
    $expectedDirectory = [IO.Path]::GetFullPath($workshopRoot).TrimEnd('\', '/')
    if (-not [string]::Equals($currentDirectory, $expectedDirectory, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Run this script from the workshop repository root.'
    }

    $appItem = Get-Item -LiteralPath $appRoot -Force -ErrorAction Stop
    if (-not $appItem.PSIsContainer -or ($appItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        -not (Test-Path -LiteralPath (Join-Path $appRoot 'pom.xml') -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $appRoot 'web') -PathType Container) -or
        -not (Test-Path -LiteralPath (Join-Path $appRoot 'worker') -PathType Container)) {
        throw 'The Java application directory is missing or does not have the expected structure.'
    }
    if (-not (Test-Path -LiteralPath $snapshot -PathType Container) -or
        -not (Test-Path -LiteralPath (Join-Path $snapshot 'pom.xml') -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $snapshot 'web') -PathType Container) -or
        -not (Test-Path -LiteralPath (Join-Path $snapshot 'worker') -PathType Container)) {
        throw 'The Java 04-2 snapshot is missing or does not have the expected structure.'
    }
    if (Test-Path -LiteralPath $backup) {
        throw 'The java-04-2 backup already exists. It will not be overwritten.'
    }

    $staging = Join-Path $workshopRoot ('.java-snapshot-04-2-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($staging) | Out-Null
    try {
        Get-ChildItem -LiteralPath $snapshot -Force -ErrorAction Stop |
            Copy-Item -Destination $staging -Recurse -Force -ErrorAction Stop
        [IO.Directory]::Move($appRoot, $backup)
        try {
            [IO.Directory]::Move($staging, $appRoot)
        }
        catch {
            try {
                [IO.Directory]::Move($backup, $appRoot)
            }
            catch {
                throw "Could not apply the snapshot or restore the original application. The original remains in java-04-2. $($_.Exception.Message)"
            }
            throw 'Could not apply the snapshot. The original application has been restored.'
        }
        Write-WorkshopMessage '[PASS] The original Java application is backed up in java-04-2.'
        Write-WorkshopMessage '[PASS] The Java 04-2 snapshot is now the java application.'
    }
    finally {
        if (Test-Path -LiteralPath $staging) {
            Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction Stop
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ApplyJava042Snapshot
        exit 0
    }
    catch {
        Write-WorkshopMessage "[FAIL] $($_.Exception.Message)"
        exit 1
    }
}
