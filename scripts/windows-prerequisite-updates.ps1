. (Join-Path $PSScriptRoot 'powershell-bootstrap.ps1')
$bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters @{} -RemainingArguments $args -DotSourced ($MyInvocation.InvocationName -eq '.')
if ($bootstrap.Handled) { exit $bootstrap.Code }

function Get-WorkshopReleaseVersion {
    param($Probe)
    if ($Probe.Code -eq 0 -and $Probe.Text.Trim() -match '^v?(\d+\.\d+\.\d+)$') {
        return [version]$Matches[1]
    }
}

function Test-WorkshopNvmOwnership {
    param([string]$NodePath)
    $nvm = Get-Command nvm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $nvm -or -not $env:NVM_HOME -or -not $env:NVM_SYMLINK) { return $false }
    if ([IO.Path]::GetFullPath($nvm.Source) -ine [IO.Path]::GetFullPath((Join-Path $env:NVM_HOME 'nvm.exe'))) { return $false }
    if (-not (Get-WorkshopReleaseVersion (Invoke-ToolProbe nvm @('version')))) { return $false }
    $settings = Join-Path $env:NVM_HOME 'settings.txt'
    if (-not (Test-Path -LiteralPath $settings -PathType Leaf)) { return $false }
    $lines = Get-Content -LiteralPath $settings
    $root = @($lines | Where-Object { $_ -match '^root:\s*(.+)$' } | ForEach-Object { $_ -replace '^root:\s*', '' })
    $path = @($lines | Where-Object { $_ -match '^path:\s*(.+)$' } | ForEach-Object { $_ -replace '^path:\s*', '' })
    if ($root.Count -ne 1 -or $path.Count -ne 1 -or
        $root[0].TrimEnd('\') -ine $env:NVM_HOME.TrimEnd('\') -or
        $path[0].TrimEnd('\') -ine $env:NVM_SYMLINK.TrimEnd('\')) { return $false }
    $link = Get-Item -LiteralPath $env:NVM_SYMLINK -Force -ErrorAction SilentlyContinue
    if ($link) {
        if ($link.LinkType -ne 'SymbolicLink') { return $false }
        $targets = @($link.Target)
        if ($targets.Count -ne 1) { return $false }
        $target = [IO.Path]::GetFullPath($targets[0])
        if ((Split-Path $target -Parent) -ine $env:NVM_HOME.TrimEnd('\') -or
            (Split-Path $target -Leaf) -notmatch '^v\d+\.\d+\.\d+$') { return $false }
    }
    if ($NodePath) {
        if (-not $link -or [IO.Path]::GetFullPath($NodePath) -ine
            [IO.Path]::GetFullPath((Join-Path $env:NVM_SYMLINK 'node.exe'))) { return $false }
        $active = Get-WorkshopReleaseVersion (Invoke-ToolProbe node @('--version'))
        if (-not $active -or (Split-Path $target -Leaf) -ine "v$active") { return $false }
    }
    return $true
}

function Get-WorkshopNodeRelease {
    param([int]$Major)
    $releases = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -TimeoutSec 30 -ErrorAction Stop
    return @($releases | Where-Object { $_.version -match "^v$Major\.\d+\.\d+$" } |
        ForEach-Object { [version]$_.version.TrimStart('v') } | Sort-Object -Descending | Select-Object -First 1)[0]
}

function Install-WorkshopJavaNode {
    param([switch]$Update)
    if (-not (Test-WorkshopBootstrapInteractive)) { return $false }
    Update-ProcessPath
    $node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $current = if ($node) { Get-WorkshopReleaseVersion (Invoke-ToolProbe node @('--version')) }
    $nvm = Get-Command nvm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $nvm) {
        # nvm's installer may offer to take over an existing Node installation.
        # Do not even launch it when ownership or its default link is ambiguous.
        $defaultLink = if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'nodejs' }
        if ($node -or $env:NVM_HOME -or $env:NVM_SYMLINK -or
            ($defaultLink -and (Test-Path -LiteralPath $defaultLink))) {
            Write-Host '[MANUAL] 기존 Node.js/NVM 경로를 보존합니다. 원래 설치 관리자를 확인하고 nvm-windows 전환을 직접 준비하세요.'
            return $false
        }
        if (-not (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)) {
            Write-Host '[MANUAL] nvm-windows 설치에 기존 winget이 필요합니다.'
            return $false
        }
        if (-not (Confirm-ToolInstall 'winget의 CoreyButler.NVMforWindows를 설치합니다. 네트워크/관리자 승인과 약관 확인이 필요할 수 있습니다.')) { return $false }
        & winget install --id CoreyButler.NVMforWindows --exact --source winget | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-Host '[FAIL] nvm-windows 설치 실패.'; return $false }
        Update-ProcessPath
    }
    if (-not (Test-WorkshopNvmOwnership $node.Source)) {
        Write-Host '[MANUAL] nvm.exe/settings.txt/NVM_HOME/NVM_SYMLINK 또는 활성 Node.js의 관리 출처가 불명확합니다. 경로를 삭제하거나 덮어쓰지 않습니다.'
        return $false
    }
    if ($node -and -not $current) { Write-Host '[FAIL] Node.js 정식 버전 확인 실패.'; return $false }
    if ($current -and -not $Update) {
        Write-Host "[INFO] Node.js $current 유지 (-Update 없음)."
        return $current.Major -ge 22
    }
    $major = if ($current -and $current.Major -ge 22) { $current.Major } else { 22 }
    if (-not (Confirm-ToolInstall "nvm으로 Node.js 최신 $major.x를 조회하고 필요하면 추가 설치합니다. 기존 버전은 보존합니다.")) {
        return ($current -and $current.Major -ge 22)
    }
    try { $latest = Get-WorkshopNodeRelease $major }
    catch { Write-Host "[FAIL] Node.js 릴리스 조회 실패: $($_.Exception.Message)"; return $false }
    if (-not $latest -or $latest.Major -ne $major) { Write-Host '[FAIL] 정식 Node.js 릴리스를 확인하지 못했습니다.'; return $false }
    if ($current -and $current -ge $latest) { Write-Host "[PASS] Node.js $current 유지 (다운그레이드 없음)."; return $true }
    $installedNode = Join-Path $env:NVM_HOME "v$latest\node.exe"
    if (-not (Test-Path -LiteralPath $installedNode -PathType Leaf)) {
        $install = Invoke-ToolProbe nvm @('install', "$latest")
        if ($install.Code -ne 0) { Write-Host "[FAIL] nvm install 실패: $($install.Text)"; return $false }
    }
    $probe = Invoke-ToolProbe $installedNode @('--version')
    if ((Get-WorkshopReleaseVersion $probe) -ne $latest) { Write-Host '[FAIL] 설치된 Node.js 버전 검증 실패.'; return $false }
    if (-not (Confirm-ToolInstall "nvm use $latest 실행: Windows 공용 Node.js 링크를 변경합니다. 관리자 승인이 필요할 수 있습니다.")) {
        Write-Host "[INFO] 활성화하지 않았습니다. 필요하면 직접 nvm use $latest 실행 후 점검하세요."
        return ($current -and $current.Major -ge 22)
    }
    # Recheck immediately before a link change; never take over a new collision.
    $liveNode = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $liveVersion = if ($liveNode) { Get-WorkshopReleaseVersion (Invoke-ToolProbe node @('--version')) }
    if (-not (Test-WorkshopNvmOwnership $liveNode.Source) -or $liveVersion -ne $current) {
        Write-Host '[MANUAL] Node.js 경로 충돌 또는 활성 버전 변경을 발견했습니다. 활성화하지 않습니다.'
        return $false
    }
    $use = Invoke-ToolProbe nvm @('use', "$latest")
    Update-ProcessPath
    $activeNode = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($use.Code -ne 0 -or -not $activeNode -or
        -not (Test-WorkshopNvmOwnership $activeNode.Source) -or
        (Get-WorkshopReleaseVersion (Invoke-ToolProbe node @('--version'))) -ne $latest) {
        Write-Host '[FAIL] nvm 활성화/실행 버전 검증 실패. 새 터미널에서 PATH와 nvm current를 확인하세요.'
        return $false
    }
    Write-Host "[PASS] [Windows 호스트] nvm Node.js $latest"
    return $true
}

function Get-WorkshopWslVersion {
    $probe = Invoke-ToolProbe (Get-WorkshopWslExecutable) @('--version')
    $first = ($probe.Text -replace "`0", '' -split '\r?\n')[0]
    if ($probe.Code -eq 0 -and $first -match ':\s*(\d+\.\d+\.\d+(?:\.\d+)?)\s*$') { return [version]$Matches[1] }
}

function Get-WorkshopManagedPowerShell {
    $executable = Join-Path $PSHOME 'pwsh.exe'
    $installed = Invoke-ToolProbe winget @('list', '--id', 'Microsoft.PowerShell', '--exact', '--source', 'winget', '--disable-interactivity')
    if ($installed.Code -ne 0 -or $installed.Text -notmatch '(?m)\bMicrosoft\.PowerShell\s+7\.\d+\.\d+\b') { return }
    $entries = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue)
    foreach ($entry in $entries) {
        if ($entry.Publisher -eq 'Microsoft Corporation' -and $entry.DisplayName -match '^PowerShell 7(?:\.\d+)*-(?:x64|arm64|x86)$' -and
            $entry.InstallLocation -and
            [IO.Path]::GetFullPath((Join-Path $entry.InstallLocation 'pwsh.exe')) -ieq [IO.Path]::GetFullPath($executable)) {
            $version = Get-WorkshopReleaseVersion (Invoke-ToolProbe $executable @('-NoProfile', '-NonInteractive', '-Command', '$PSVersionTable.PSVersion.ToString()'))
            if ($version -and $version.Major -eq 7 -and "$version" -eq $entry.DisplayVersion) {
                return [pscustomobject]@{ Path = $executable; Version = $version }
            }
        }
    }
}

function Start-WorkshopPowerShellUpdate {
    param([string]$Executable, [version]$Version)
    $winget = (Get-Command winget -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $worker = @'
$ErrorActionPreference = 'Stop'
try {
    Wait-Process -Id __PID__ -ErrorAction SilentlyContinue
    & '__WINGET__' upgrade --id Microsoft.PowerShell --exact --source winget --version '__VERSION__' --disable-interactivity | Out-Host
    if ($LASTEXITCODE -in @(1641, 3010)) { Write-Host '[WARN] Restart Windows manually, then verify pwsh --version.'; exit 1 }
    if ($LASTEXITCODE -ne 0) { throw "winget failed: $LASTEXITCODE" }
    $actual = & '__EXE__' -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()'
    if ($LASTEXITCODE -ne 0 -or "$actual".Trim() -ne '__VERSION__') { throw 'Installed PowerShell version verification failed.' }
    Write-Host '[PASS] PowerShell __VERSION__ updated. Open a new terminal.'
}
catch { Write-Host "[FAIL] $($_.Exception.Message) Update was not verified; check the original installer manually."; exit 1 }
'@
    $worker = $worker.Replace('__PID__', "$PID").Replace('__WINGET__', $winget.Replace("'", "''")).
        Replace('__EXE__', $Executable.Replace("'", "''")).Replace('__VERSION__', "$Version")
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($worker))
    # The independent Windows PowerShell worker waits until this pwsh exits,
    # avoiding an MSI replacement of the executing binary and update recursion.
    Start-Process -NoNewWindow -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList @(
        '-NoLogo', '-NoProfile', '-EncodedCommand', $encoded) -ErrorAction Stop | Out-Null
}

function Update-WorkshopWindowsHost {
    if (-not (Test-WorkshopBootstrapInteractive)) { return 1 }
    $failed = $false
    $before = Get-WorkshopWslVersion
    if (-not $before) {
        Write-Host '[MANUAL] WSL --version 확인 불가 (inbox WSL 포함). 원래 설치 방식으로 수동 업데이트하세요. 배포판은 변경하지 않습니다.'
        $failed = $true
    }
    elseif (Confirm-ToolInstall "WSL $before 플랫폼을 wsl.exe --update로 업데이트합니다. 네트워크/관리자 승인이 필요할 수 있습니다. 배포판 업데이트/삭제나 자동 재부팅은 하지 않습니다.") {
        $result = Invoke-ToolProbe (Get-WorkshopWslExecutable) @('--update')
        $after = Get-WorkshopWslVersion
        if ($result.Code -ne 0 -or -not $after -or $after -lt $before -or -not (Test-WorkshopWsl2)) {
            Write-Host "[FAIL] WSL 업데이트 검증 실패 (종료 코드 $($result.Code)). 필요하면 직접 재부팅 후 점검하세요."
            $failed = $true
        }
        else { Write-Host "[PASS] WSL 플랫폼 $before -> $after (동일 버전이면 최신 상태)." }
    }
    $managed = Get-WorkshopManagedPowerShell
    if (-not $managed) {
        Write-Host '[MANUAL] 실행 중인 PowerShell 7의 winget/MSI 관리 출처를 확인하지 못했습니다. 원래 설치 관리자로 업데이트하세요.'
        return 1
    }
    $show = Invoke-ToolProbe winget @('show', '--id', 'Microsoft.PowerShell', '--exact', '--source', 'winget', '--versions', '--disable-interactivity')
    # Version-only rows avoid parsing localized winget field labels.
    $versions = @([regex]::Matches($show.Text, '(?m)^\s*(7\.\d+\.\d+)\s*$') |
        ForEach-Object { [version]$_.Groups[1].Value } | Sort-Object -Descending)
    if ($show.Code -ne 0 -or -not $versions.Count) {
        Write-Host '[FAIL] winget PowerShell 7 정식 최신 버전 확인 실패.'
        return 1
    }
    $latest = $versions[0]
    if ($latest -gt $managed.Version -and (Confirm-ToolInstall "winget Microsoft.PowerShell $($managed.Version) -> $latest 업데이트를 별도 Windows PowerShell 프로세스에 예약합니다. 네트워크/관리자 승인이 필요할 수 있습니다. 현재 pwsh 종료 후 실행하며 새 터미널이 필요합니다.")) {
        try { Start-WorkshopPowerShellUpdate $managed.Path $latest }
        catch { Write-Host "[FAIL] PowerShell 업데이트 프로세스 시작 실패: $($_.Exception.Message)"; return 1 }
        Write-Host '[WARN] PowerShell 업데이트 예약됨 (아직 성공 아님). 이 pwsh가 종료되어야 실행됩니다. 작업 프로세스의 PASS/FAIL을 확인하고 새 터미널에서 다시 실행하세요.'
        return 3010
    }
    if ($failed) { return 1 }
    return 0
}
