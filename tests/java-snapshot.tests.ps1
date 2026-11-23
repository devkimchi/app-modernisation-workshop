. (Join-Path $PSScriptRoot '..\scripts\powershell-bootstrap.ps1')
$bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters @{} -RemainingArguments $args -DotSourced ($MyInvocation.InvocationName -eq '.')
if ($bootstrap.Handled) { exit $bootstrap.Code }

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$temporary = Join-Path $root ('.test-output\java-snapshot-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporary) | Out-Null
$script:Passed = 0

function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAILED: $Name" }
    $script:Passed++
}
function New-Fixture([string]$Name) {
    $fixture = Join-Path $temporary $Name
    foreach ($path in @('scripts', 'snapshots\java\03\web', 'snapshots\java\03\worker', 'java\web', 'java\worker')) {
        [IO.Directory]::CreateDirectory((Join-Path $fixture $path)) | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $root 'scripts\apply-java-03-snapshot.ps1') -Destination (Join-Path $fixture 'scripts')
    Copy-Item -LiteralPath (Join-Path $root 'scripts\powershell-bootstrap.ps1') -Destination (Join-Path $fixture 'scripts')
    Set-Content -LiteralPath (Join-Path $fixture 'snapshots\java\03\pom.xml') -Value snapshot -NoNewline
    Set-Content -LiteralPath (Join-Path $fixture 'snapshots\java\03\web\marker.txt') -Value snapshot-web -NoNewline
    Set-Content -LiteralPath (Join-Path $fixture 'snapshots\java\03\.snapshot-hidden') -Value snapshot-hidden -NoNewline
    Set-Content -LiteralPath (Join-Path $fixture 'java\pom.xml') -Value original -NoNewline
    Set-Content -LiteralPath (Join-Path $fixture 'java\web\marker.txt') -Value original-web -NoNewline
    return $fixture
}
function Invoke-SnapshotScript([string]$Fixture) {
    $scriptPath = Join-Path $Fixture 'scripts\apply-java-03-snapshot.ps1'
    Push-Location $Fixture
    try {
        $result = & pwsh -NoLogo -NoProfile -File $scriptPath 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    return [pscustomobject]@{ Code = $code; Output = ($result -join "`n") }
}

try {
    $success = New-Fixture 'success'
    $result = Invoke-SnapshotScript $success
    Assert-True ($result.Code -eq 0) "successful apply exit code: $($result.Output)"
    Assert-True ((Get-Content -LiteralPath (Join-Path $success 'java-03\pom.xml') -Raw) -eq 'original') 'original app is backed up'
    Assert-True ((Get-Content -LiteralPath (Join-Path $success 'java\pom.xml') -Raw) -eq 'snapshot') 'snapshot replaces app'
    Assert-True ((Get-Content -LiteralPath (Join-Path $success 'java\.snapshot-hidden') -Raw) -eq 'snapshot-hidden') 'hidden files are copied'
    Assert-True ((Get-Content -LiteralPath (Join-Path $success 'snapshots\java\03\pom.xml') -Raw) -eq 'snapshot') 'snapshot source is preserved'

    $existingBackup = New-Fixture 'existing-backup'
    [IO.Directory]::CreateDirectory((Join-Path $existingBackup 'java-03')) | Out-Null
    Set-Content -LiteralPath (Join-Path $existingBackup 'java-03\marker.txt') -Value do-not-overwrite -NoNewline
    $result = Invoke-SnapshotScript $existingBackup
    Assert-True ($result.Code -ne 0) 'existing backup is rejected'
    Assert-True ((Get-Content -LiteralPath (Join-Path $existingBackup 'java-03\marker.txt') -Raw) -eq 'do-not-overwrite') 'existing backup is preserved'
    Assert-True ((Get-Content -LiteralPath (Join-Path $existingBackup 'java\pom.xml') -Raw) -eq 'original') 'app is unchanged after rejection'

    Write-Host "PASS: $script:Passed Java snapshot checks"
}
finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction Stop
}
