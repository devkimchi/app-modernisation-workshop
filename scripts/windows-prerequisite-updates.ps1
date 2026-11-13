. (Join-Path $PSScriptRoot 'powershell-bootstrap.ps1')
$bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters @{} -RemainingArguments $args -DotSourced ($MyInvocation.InvocationName -eq '.')
if ($bootstrap.Handled) { exit $bootstrap.Code }

function Get-WorkshopReleaseVersion {
    param($Probe)
    if ($Probe.Code -eq 0 -and $Probe.Text.Trim() -match '^v?(\d+\.\d+\.\d+)$') {
        return [version]$Matches[1]
    }
}

function Get-WorkshopNvmConfiguration {
    $probe = Invoke-ToolProbe nvm @('config', 'get', 'root', 'mode', 'auto_install', 'enabled', '--json')
    if ($probe.Code -ne 0) { Write-Host '[FAIL] Could not query nvm-windows 2 configuration.'; return }
    try { $config = $probe.Text | ConvertFrom-Json -ErrorAction Stop }
    catch [ArgumentException] { Write-Host '[FAIL] Invalid nvm-windows 2 configuration JSON.'; return }
    if ($config.root -isnot [string] -or -not [IO.Path]::IsPathFullyQualified($config.root) -or
        -not (Split-Path $config.root.TrimEnd('\') -Parent) -or
        $config.mode -cnotin @('shim', 'link') -or $config.enabled -isnot [bool] -or
        $config.auto_install -isnot [bool] -or -not $config.enabled -or $config.auto_install) {
        Write-Host '[MANUAL] Check nvm-windows 2 root/mode/enabled settings. This script will not continue with auto_install=true, to prevent installation without individual consent.'
        return
    }
    return $config
}

function Get-WorkshopNvmSelection {
    $list = Invoke-ToolProbe nvm @('list', '--json')
    if ($list.Code -ne 0 -or $list.Text.Trim() -notmatch '^\[[\s\S]*\]$') { Write-Host '[FAIL] Could not list installed nvm-windows 2 versions.'; return }
    try { $versions = @($list.Text | ConvertFrom-Json -ErrorAction Stop) }
    catch [ArgumentException] { Write-Host '[FAIL] Invalid nvm-windows 2 version list JSON.'; return }
    foreach ($entry in $versions) {
        if (-not (Get-WorkshopReleaseVersion ([pscustomobject]@{ Code=0; Text=[string]$entry.version })) -or
            $entry.installed -isnot [bool] -or $entry.default -isnot [bool]) {
            Write-Host '[FAIL] Invalid nvm-windows 2 version list format.'; return
        }
    }
    $defaults = @($versions | Where-Object { $_.installed -eq $true -and $_.default -eq $true })
    if ($defaults.Count -gt 1) { Write-Host '[FAIL] Multiple default nvm-windows 2 versions were found.'; return }
    return [pscustomobject]@{ Version = if ($defaults.Count) {
        Get-WorkshopReleaseVersion ([pscustomobject]@{ Code=0; Text=[string]$defaults[0].version })
    } else { $null } }
}

function Test-WorkshopNvmOwnership {
    param([string]$NodePath)
    $nvm = Get-Command nvm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $nvm) { return $false }
    $version = Get-WorkshopReleaseVersion (Invoke-ToolProbe nvm @('version'))
    if (-not $version) { return $false }
    if ($version.Major -eq 2) {
        $config = Get-WorkshopNvmConfiguration
        if (-not $config) { return $false }
        $root = [IO.Path]::GetFullPath($config.root).TrimEnd('\')
        $dataRoot = Split-Path $root -Parent
        $runtime = Join-Path $dataRoot '.nodejs'
        $link = Get-Item -LiteralPath $runtime -Force -ErrorAction SilentlyContinue
        if ($link) {
            if ($link.LinkType -notin @('Junction', 'SymbolicLink') -or @($link.Target).Count -ne 1) { return $false }
            $target = [IO.Path]::GetFullPath(@($link.Target)[0]).TrimEnd('\')
            if ($config.mode -eq 'shim') {
                if ($target -ine (Join-Path $dataRoot '.shim')) { return $false }
            }
            elseif ((Split-Path $target -Parent) -ine $root -or (Split-Path $target -Leaf) -notmatch '^v\d+\.\d+\.\d+$') { return $false }
        }
        if ($NodePath -and (-not $link -or
            [IO.Path]::GetFullPath($NodePath) -ine (Join-Path $runtime 'node.exe'))) { return $false }
        return $true
    }
    if ($version.Major -ne 1 -or -not $env:NVM_HOME -or -not $env:NVM_SYMLINK) { return $false }
    if ([IO.Path]::GetFullPath($nvm.Source) -ine [IO.Path]::GetFullPath((Join-Path $env:NVM_HOME 'nvm.exe'))) { return $false }
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

function Install-WorkshopNode {
    param([switch]$Update)
    if (-not (Test-WorkshopBootstrapInteractive)) { return $false }
    Update-ProcessPath
    $node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $nvm = Get-Command nvm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $nvm) {
        # nvm's installer may offer to take over an existing Node installation.
        # Do not even launch it when ownership or its default link is ambiguous.
        $defaultLink = if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'nodejs' }
        if ($node -or $env:NVM_HOME -or $env:NVM_SYMLINK -or
            ($defaultLink -and (Test-Path -LiteralPath $defaultLink))) {
            Write-Host '[MANUAL] Existing Node.js/NVM paths will be preserved. Identify the original installer and prepare the switch to nvm-windows manually.'
            return $false
        }
        if (-not (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)) {
            Write-Host '[MANUAL] winget must already be installed to install nvm-windows.'
            return $false
        }
        if (-not (Confirm-ToolInstall 'Install AuthorSoftware.NVMWindows through winget. Network access, administrator approval, and a review of the terms may be required.')) { return $false }
        & winget install --id AuthorSoftware.NVMWindows --exact --source winget | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-Host '[FAIL] nvm-windows installation failed.'; return $false }
        Update-ProcessPath
    }
    if (-not (Test-WorkshopNvmOwnership $node.Source)) {
        Write-Host '[MANUAL] Could not establish ownership of the nvm-windows configuration or active Node.js installation. No paths will be deleted or overwritten.'
        return $false
    }
    $nvmVersion = Get-WorkshopReleaseVersion (Invoke-ToolProbe nvm @('version'))
    if (-not $nvmVersion -or $nvmVersion.Major -notin @(1, 2)) { Write-Host '[FAIL] Could not verify a supported nvm-windows version.'; return $false }
    $root = $env:NVM_HOME
    $hasActive = [bool]$node
    if ($nvmVersion -and $nvmVersion.Major -eq 2) {
        $config = Get-WorkshopNvmConfiguration
        if (-not $config) { return $false }
        $root = $config.root
        $selection = Get-WorkshopNvmSelection
        if (-not $selection) { return $false }
        $hasActive = $null -ne $selection.Version
        if ($hasActive -and -not $node) { Write-Host '[MANUAL] The nvm-windows Node.js executable directory is not in PATH. Rerun in a new terminal.'; return $false }
    }
    if (-not $root) { Write-Host '[FAIL] Could not verify the nvm-windows installation root.'; return $false }
    $currentProbe = if ($node) { Invoke-ToolProbe node @('--version') }
    $current = if ($currentProbe) { Get-WorkshopReleaseVersion $currentProbe }
    if ($node -and -not $current -and ($hasActive -or $currentProbe.Code -eq 0)) { Write-Host '[FAIL] Could not verify a stable Node.js version.'; return $false }
    $hasActive = [bool]$current
    if ($current -and -not $Update) {
        Write-Host "[INFO] Keeping Node.js $current (no -Update)."
        return $current.Major -ge 22
    }
    $major = if ($current -and $current.Major -ge 22) { $current.Major } else { 22 }
    if (-not (Confirm-ToolInstall "Query the latest Node.js $major.x release through nvm and install it if needed. Existing versions will be preserved.")) {
        return ($current -and $current.Major -ge 22)
    }
    try { $latest = Get-WorkshopNodeRelease $major }
    catch { Write-Host "[FAIL] Could not query Node.js releases: $($_.Exception.Message)"; return $false }
    if (-not $latest -or $latest.Major -ne $major) { Write-Host '[FAIL] Could not verify a stable Node.js release.'; return $false }
    if ($current -and $current -ge $latest) { Write-Host "[PASS] Keeping Node.js $current (no downgrade)."; return $true }
    $installedNode = Join-Path $root "v$latest\node.exe"
    if (-not (Test-Path -LiteralPath $installedNode -PathType Leaf)) {
        $install = Invoke-ToolProbe nvm @('install', "$latest")
        if ($install.Code -ne 0) { Write-Host "[FAIL] nvm install failed: $($install.Text)"; return $false }
    }
    $probe = Invoke-ToolProbe $installedNode @('--version')
    if ((Get-WorkshopReleaseVersion $probe) -ne $latest) { Write-Host '[FAIL] Installed Node.js version verification failed.'; return $false }
    if (-not (Confirm-ToolInstall "Run nvm use $latest`: change the shared Windows Node.js selection (shim/link). This affects subsequent terminals, but not running Node.js processes. Administrator approval may be required.")) {
        Write-Host "[INFO] Activation skipped. If needed, run nvm use $latest manually and verify the result."
        return ($current -and $current.Major -ge 22)
    }
    # Recheck immediately before a link change; never take over a new collision.
    $liveNode = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not (Test-WorkshopNvmOwnership $liveNode.Source)) {
        Write-Host '[MANUAL] nvm-windows management settings changed. Activation will not proceed.'
        return $false
    }
    if ($nvmVersion.Major -eq 2) {
        $liveConfig = Get-WorkshopNvmConfiguration
        $liveSelection = Get-WorkshopNvmSelection
        if (-not $liveConfig -or -not $liveSelection -or $liveConfig.root -ine $root -or
            $liveConfig.mode -cne $config.mode -or $liveSelection.Version -ne $selection.Version) {
            Write-Host '[MANUAL] nvm-windows 2 configuration or default selection changed. Activation will not proceed.'
            return $false
        }
    }
    $liveVersion = if ($liveNode -and $hasActive) { Get-WorkshopReleaseVersion (Invoke-ToolProbe node @('--version')) }
    if ($liveVersion -ne $current) {
        Write-Host '[MANUAL] Detected a Node.js path conflict or active version change. Activation will not proceed.'
        return $false
    }
    $useArguments = @('use', "$latest")
    if ($nvmVersion -and $nvmVersion.Major -eq 2) { $useArguments += '--no-install' }
    $use = Invoke-ToolProbe nvm $useArguments
    Update-ProcessPath
    $activeNode = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($use.Code -ne 0 -or -not $activeNode -or
        -not (Test-WorkshopNvmOwnership $activeNode.Source) -or
        (Get-WorkshopReleaseVersion (Invoke-ToolProbe node @('--version'))) -ne $latest) {
        Write-Host '[FAIL] Could not verify nvm activation or the running Node.js version. Check PATH and nvm list in a new terminal.'
        return $false
    }
    Write-Host "[PASS] [Windows host] nvm Node.js $latest"
    return $true
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
    $managed = Get-WorkshopManagedPowerShell
    if (-not $managed) {
        Write-Host '[MANUAL] Could not verify that the running PowerShell 7 is managed by winget/MSI. Skipping automatic update; use the original installer. Required tool checks will continue.'
        return 0
    }
    $show = Invoke-ToolProbe winget @('show', '--id', 'Microsoft.PowerShell', '--exact', '--source', 'winget', '--versions', '--disable-interactivity')
    # Version-only rows avoid parsing localized winget field labels.
    $versions = @([regex]::Matches($show.Text, '(?m)^\s*(7\.\d+\.\d+)\s*$') |
        ForEach-Object { [version]$_.Groups[1].Value } | Sort-Object -Descending)
    if ($show.Code -ne 0 -or -not $versions.Count) {
        Write-Host '[FAIL] Could not query the latest stable PowerShell 7 version from winget.'
        return 1
    }
    $latest = $versions[0]
    if ($latest -gt $managed.Version -and (Confirm-ToolInstall "Schedule a winget Microsoft.PowerShell update from $($managed.Version) to $latest in a separate Windows PowerShell process. Network access and administrator approval may be required. The update runs after the current pwsh exits; a new terminal is required.")) {
        try { Start-WorkshopPowerShellUpdate $managed.Path $latest }
        catch { Write-Host "[FAIL] Could not start the PowerShell update process: $($_.Exception.Message)"; return 1 }
        Write-Host '[WARN] PowerShell update scheduled (not yet successful). It runs only after this pwsh exits. Check the worker process PASS/FAIL result and rerun in a new terminal.'
        return 3010
    }
    return 0
}
