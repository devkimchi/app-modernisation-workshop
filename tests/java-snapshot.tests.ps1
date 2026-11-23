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
function New-Fixture([string]$Name, [string]$Version) {
    $fixture = Join-Path $temporary $Name
    foreach ($path in @('scripts', "snapshots\java\$Version\web", "snapshots\java\$Version\worker", 'java\web', 'java\worker')) {
        [IO.Directory]::CreateDirectory((Join-Path $fixture $path)) | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $root "scripts\apply-java-$Version-snapshot.ps1") -Destination (Join-Path $fixture 'scripts')
    Copy-Item -LiteralPath (Join-Path $root 'scripts\powershell-bootstrap.ps1') -Destination (Join-Path $fixture 'scripts')
    Set-Content -LiteralPath (Join-Path $fixture "snapshots\java\$Version\pom.xml") -Value snapshot -NoNewline
    Set-Content -LiteralPath (Join-Path $fixture "snapshots\java\$Version\web\marker.txt") -Value snapshot-web -NoNewline
    Set-Content -LiteralPath (Join-Path $fixture "snapshots\java\$Version\.snapshot-hidden") -Value snapshot-hidden -NoNewline
    Set-Content -LiteralPath (Join-Path $fixture 'java\pom.xml') -Value original -NoNewline
    Set-Content -LiteralPath (Join-Path $fixture 'java\web\marker.txt') -Value original-web -NoNewline
    return $fixture
}
function Invoke-SnapshotScript([string]$Fixture) {
    $scriptFile = Get-ChildItem -LiteralPath (Join-Path $Fixture 'scripts') -Filter 'apply-java-*-snapshot.ps1' | Select-Object -First 1
    $scriptPath = $scriptFile.FullName
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
    foreach ($version in @('03', '04-1', '04-2', '05')) {
        $success = New-Fixture "success-$version" $version
        $result = Invoke-SnapshotScript $success
        Assert-True ($result.Code -eq 0) "$version successful apply exit code: $($result.Output)"
        Assert-True ((Get-Content -LiteralPath (Join-Path $success "java-$version\pom.xml") -Raw) -eq 'original') "$version original app is backed up"
        Assert-True ((Get-Content -LiteralPath (Join-Path $success 'java\pom.xml') -Raw) -eq 'snapshot') "$version snapshot replaces app"
        Assert-True ((Get-Content -LiteralPath (Join-Path $success 'java\.snapshot-hidden') -Raw) -eq 'snapshot-hidden') "$version hidden files are copied"
        Assert-True ((Get-Content -LiteralPath (Join-Path $success "snapshots\java\$version\pom.xml") -Raw) -eq 'snapshot') "$version snapshot source is preserved"

        $existingBackup = New-Fixture "existing-backup-$version" $version
        [IO.Directory]::CreateDirectory((Join-Path $existingBackup "java-$version")) | Out-Null
        Set-Content -LiteralPath (Join-Path $existingBackup "java-$version\marker.txt") -Value do-not-overwrite -NoNewline
        $result = Invoke-SnapshotScript $existingBackup
        Assert-True ($result.Code -ne 0) "$version existing backup is rejected"
        Assert-True ((Get-Content -LiteralPath (Join-Path $existingBackup "java-$version\marker.txt") -Raw) -eq 'do-not-overwrite') "$version existing backup is preserved"
        Assert-True ((Get-Content -LiteralPath (Join-Path $existingBackup 'java\pom.xml') -Raw) -eq 'original') "$version app is unchanged after rejection"
    }

    . (Join-Path $root 'scripts\apply-java-04-2-snapshot.ps1')
    $retrySource = Join-Path $temporary 'retry-source'
    $retryDestination = Join-Path $temporary 'retry-destination'
    [IO.Directory]::CreateDirectory($retrySource) | Out-Null
    $script:MoveAttempts = 0
    function Move-JavaSnapshotDirectory([string]$Source, [string]$Destination) {
        $script:MoveAttempts++
        if ($script:MoveAttempts -le 2) {
            throw [UnauthorizedAccessException]::new('Temporary access denied')
        }
        [IO.Directory]::Move($Source, $Destination)
    }
    Move-JavaSnapshotWithRetry $retrySource $retryDestination
    Assert-True ($script:MoveAttempts -eq 3) '04-2 retries transient access errors'
    Assert-True (Test-Path -LiteralPath $retryDestination -PathType Container) '04-2 retry moves the snapshot'

    $retrySource = Join-Path $temporary 'non-retry-source'
    [IO.Directory]::CreateDirectory($retrySource) | Out-Null
    $script:MoveAttempts = 0
    function Move-JavaSnapshotDirectory([string]$Source, [string]$Destination) {
        $script:MoveAttempts++
        throw [IO.IOException]::new('Non-retryable error')
    }
    $failed = $false
    try {
        Move-JavaSnapshotWithRetry $retrySource (Join-Path $temporary 'non-retry-destination')
    }
    catch {
        $failed = $true
    }
    Assert-True ($failed -and $script:MoveAttempts -eq 1) '04-2 reports non-retryable errors immediately'

    $conflictDestination = Join-Path $temporary 'conflicting-destination'
    $script:MoveAttempts = 0
    function Move-JavaSnapshotDirectory([string]$Source, [string]$Destination) {
        $script:MoveAttempts++
        [IO.Directory]::CreateDirectory($Destination) | Out-Null
        throw [UnauthorizedAccessException]::new('Destination appeared')
    }
    $failed = $false
    try {
        Move-JavaSnapshotWithRetry $retrySource $conflictDestination
    }
    catch {
        $failed = $true
    }
    Assert-True ($failed -and $script:MoveAttempts -eq 1 -and
        (Test-Path -LiteralPath $conflictDestination -PathType Container)) '04-2 does not retry or overwrite a conflicting destination'

    $failureFixture = New-Fixture 'persistent-move-failure-04-2' '04-2'
    . (Join-Path $failureFixture 'scripts\apply-java-04-2-snapshot.ps1')
    $script:MoveAttempts = 0
    function Move-JavaSnapshotDirectory([string]$Source, [string]$Destination) {
        $script:MoveAttempts++
        throw [UnauthorizedAccessException]::new('Persistent access denied')
    }
    $failureMessage = ''
    Push-Location $failureFixture
    try {
        Invoke-ApplyJava042Snapshot
    }
    catch {
        $failureMessage = $_.Exception.Message
    }
    finally {
        Pop-Location
    }
    Assert-True ($script:MoveAttempts -eq 10 -and $failureMessage -like '*Persistent access denied*') '04-2 reports persistent access errors after bounded retries'
    Assert-True ((Get-Content -LiteralPath (Join-Path $failureFixture 'java\pom.xml') -Raw) -eq 'original') '04-2 restores the original app after persistent failure'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $failureFixture 'java-04-2'))) '04-2 removes backup name after restoring the original'

    Write-Host "PASS: $script:Passed Java snapshot checks"
}
finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction Stop
}
