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

    Write-Host "PASS: $script:Passed Java snapshot checks"
}
finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction Stop
}
