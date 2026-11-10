# Keep this helper compatible with Windows PowerShell 5.1.
function Test-WorkshopPowerShellExecutable {
    param([string]$Path)
    try {
        $major = & $Path -NoLogo -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.Major' 2>$null
        return $LASTEXITCODE -eq 0 -and "$major".Trim() -match '^\d+$' -and [int]"$major".Trim() -ge 7
    }
    catch { return $false }
}

function Find-WorkshopPowerShell {
    $candidates = @(
        Get-Command pwsh -CommandType Application -All -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Source }
    )
    # winget can finish before the current shell sees the updated PATH.
    foreach ($base in @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($base) { $candidates += Join-Path $base 'PowerShell\7\pwsh.exe' }
    }
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA 'Microsoft\PowerShell\7\pwsh.exe'
    }
    foreach ($scope in @('Machine', 'User')) {
        foreach ($directory in ([Environment]::GetEnvironmentVariable('Path', $scope) -split ';')) {
            if ($directory) {
                $candidates += Join-Path ([Environment]::ExpandEnvironmentVariables($directory.Trim().Trim('"'))) 'pwsh.exe'
            }
        }
    }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if ((Test-Path -LiteralPath $candidate -PathType Leaf) -and (Test-WorkshopPowerShellExecutable $candidate)) {
            return $candidate
        }
    }
}

function Get-WorkshopWslExecutable {
    $command = Get-Command wsl.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    foreach ($directory in @('Sysnative', 'System32')) {
        if ($env:SystemRoot) {
            $path = Join-Path $env:SystemRoot "$directory\wsl.exe"
            if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
        }
    }
}

function Test-WorkshopWsl2 {
    $executable = Get-WorkshopWslExecutable
    if (-not $executable) { return $false }
    try {
        # This read-only feature query needs no elevation. Do not equate an
        # installed wsl.exe (or a WSL1 distro) with an enabled WSL2 platform.
        $feature = Get-CimInstance Win32_OptionalFeature -Filter "Name='VirtualMachinePlatform'" -ErrorAction Stop
        if (-not $feature -or $feature.InstallState -ne 1) { return $false }
        & $executable --status 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch { return $false }
}

function Get-WorkshopHostPrerequisites {
    $windows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    $executable = if ($PSVersionTable.PSVersion.Major -ge 7) {
        Join-Path $PSHOME $(if ($windows) { 'pwsh.exe' } else { 'pwsh' })
    }
    else { Find-WorkshopPowerShell }
    $wsl2 = if ($windows) { Test-WorkshopWsl2 } else { $true }
    return [pscustomobject]@{ Windows = $windows; PowerShell = $executable; Wsl2 = $wsl2 }
}

function Write-WorkshopHostGuidance {
    param($State)
    Write-Host '[FAIL] PowerShell 7 and WSL2 are required on Windows. No workshop actions were performed.'
    $powerShellStatus = if ($State.PowerShell) { 'PASS' } else { 'FAIL' }
    $wslStatus = if ($State.Wsl2) { 'PASS' } else { 'FAIL' }
    Write-Host "[$powerShellStatus] PowerShell 7"
    Write-Host "[$wslStatus] WSL2 platform (a Linux distribution is checked separately for Java)"
    Write-Host 'PowerShell 7: https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows'
    Write-Host 'Manual installation: winget install --id Microsoft.PowerShell --exact --source winget'
    Write-Host 'WSL2: https://learn.microsoft.com/windows/wsl/install'
    Write-Host 'Manual platform installation (administrator terminal): wsl.exe --install --no-distribution'
    Write-Host 'WSL2 may require enabling virtualization, Windows Update and a reboot. Restart manually, then rerun.'
    Write-Host 'Installer: powershell.exe -File .\scripts\install-prerequisites.ps1 -Track java|dotnet'
}

function Test-WorkshopBootstrapInteractive {
    $nonInteractive = @([Environment]::GetCommandLineArgs() | Where-Object { $_ -like '-NonI*' }).Count -gt 0
    return -not ($env:CI -or $nonInteractive -or -not [Environment]::UserInteractive -or
        [Console]::IsInputRedirected -or [Console]::IsOutputRedirected)
}

function Confirm-WorkshopPowerShellInstall {
    Write-Host 'PowerShell 7 is missing. Install Microsoft.PowerShell using winget on this Windows host?'
    Write-Host 'Network access and administrator approval may be required. Review the winget agreements yourself.'
    $answer = Read-Host 'Install PowerShell 7? [y/N]'
    return $answer -ceq 'y' -or $answer -ceq 'Y'
}

function Install-WorkshopPowerShell {
    if (-not (Test-WorkshopBootstrapInteractive)) {
        Write-Host '[FAIL] Noninteractive/CI sessions cannot install PowerShell 7.'
        return
    }
    if (-not (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Host '[FAIL] winget is unavailable. Install PowerShell 7 manually.'
        return
    }
    if (-not (Confirm-WorkshopPowerShellInstall)) { return }
    try {
        & winget install --id Microsoft.PowerShell --exact --source winget | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] PowerShell 7 installation failed (exit code $LASTEXITCODE)."
            return
        }
    }
    catch {
        Write-Host "[FAIL] PowerShell 7 installation failed: $($_.Exception.Message)"
        return
    }
    $executable = Find-WorkshopPowerShell
    if (-not $executable) {
        Write-Host '[FAIL] Installed PowerShell 7 could not be located or started. Open a new terminal and retry.'
    }
    return $executable
}

function Confirm-WorkshopWsl2Install {
    Write-Host 'WSL2 is missing. Enable/install the WSL2 platform with wsl.exe --install --no-distribution?'
    Write-Host 'This changes Windows features, may download WSL, requires administrator approval and may require a reboot.'
    Write-Host 'No Linux distribution will be installed. This script will not restart Windows.'
    $answer = Read-Host 'Install WSL2 platform? [y/N]'
    return $answer -ceq 'y' -or $answer -ceq 'Y'
}

function Install-WorkshopWsl2 {
    if (-not (Test-WorkshopBootstrapInteractive)) {
        Write-Host '[FAIL] Noninteractive/CI sessions cannot install WSL2.'
        return $false
    }
    $executable = Get-WorkshopWslExecutable
    if (-not $executable) {
        Write-Host '[FAIL] wsl.exe is unavailable. Follow the WSL2 manual installation guidance.'
        return $false
    }
    if (-not (Confirm-WorkshopWsl2Install)) { return $false }
    try {
        & $executable --install --no-distribution | Out-Host
        if ($LASTEXITCODE -notin @(0, 1641, 3010)) {
            Write-Host "[FAIL] WSL2 installation failed (exit code $LASTEXITCODE). Use an administrator terminal and check Windows support."
            return $false
        }
    }
    catch {
        Write-Host "[FAIL] WSL2 installation failed: $($_.Exception.Message)"
        return $false
    }
    Write-Host '[INFO] WSL2 installation requested. Restart Windows manually if required, then rerun this script.'
    return $true
}

function Initialize-WorkshopScript {
    param(
        [string]$ScriptPath,
        [System.Collections.IDictionary]$BoundParameters,
        [object[]]$RemainingArguments,
        [bool]$DotSourced = $false,
        [switch]$AllowInstall
    )
    if ($DotSourced) {
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            throw 'Dot-sourcing requires a PowerShell 7 session (pwsh). Run the script normally from Windows PowerShell 5.1 to delegate, or dot-source it inside pwsh.'
        }
        return [pscustomobject]@{ Handled = $false; Code = 0 }
    }
    $state = Get-WorkshopHostPrerequisites
    $wslChanged = $false
    $validEngine = (-not $BoundParameters['ContainerEngine'] -or $BoundParameters['ContainerEngine'] -cin @('docker', 'podman')) -and
        (-not $env:AZD_CONTAINER_RUNTIME -or $env:AZD_CONTAINER_RUNTIME -cin @('docker', 'podman')) -and
        (-not $BoundParameters['ContainerEngine'] -or -not $env:AZD_CONTAINER_RUNTIME -or
            $BoundParameters['ContainerEngine'] -ceq $env:AZD_CONTAINER_RUNTIME)
    if ($AllowInstall -and $BoundParameters['Track'] -cin @('java', 'dotnet') -and
        -not $BoundParameters['Help'] -and $validEngine) {
        if (-not $state.PowerShell) { $null = Install-WorkshopPowerShell }
        if ($state.Windows -and -not $state.Wsl2) { $wslChanged = Install-WorkshopWsl2 }
        $state = Get-WorkshopHostPrerequisites
    }
    if (-not $state.PowerShell -or ($state.Windows -and -not $state.Wsl2) -or $wslChanged) {
        Write-WorkshopHostGuidance $state
        return [pscustomobject]@{ Handled = $true; Code = 1 }
    }
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $code = Invoke-WorkshopPowerShell -ScriptPath $ScriptPath -BoundParameters $BoundParameters -RemainingArguments $RemainingArguments
        return [pscustomobject]@{ Handled = $true; Code = $code }
    }
    return [pscustomobject]@{ Handled = $false; Code = 0 }
}

function Invoke-WorkshopPowerShell {
    param(
        [string]$ScriptPath,
        [System.Collections.IDictionary]$BoundParameters,
        [object[]]$RemainingArguments
    )
    $executable = Find-WorkshopPowerShell
    if (-not $executable) {
        $state = Get-WorkshopHostPrerequisites
        $state.PowerShell = $null
        Write-WorkshopHostGuidance $state
        return 1
    }

    # Serialize bound values rather than rebuilding a native command line. This
    # preserves spaces, Unicode, quotes, arrays and explicitly false switches in 5.1.
    $parameters = @{}
    foreach ($key in $BoundParameters.Keys) {
        $value = $BoundParameters[$key]
        if ($value -is [Management.Automation.SwitchParameter]) { $value = [bool]$value }
        $parameters[$key] = $value
    }
    $payload = [Management.Automation.PSSerializer]::Serialize(@{
        Path = $ScriptPath; Parameters = $parameters; Arguments = $RemainingArguments
    })
    $data = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($payload))
    $command = @'
$payload = [Management.Automation.PSSerializer]::Deserialize([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('__DATA__')))
$parameters = $payload.Parameters
$arguments = @()
if ($null -ne $payload.Arguments) { $arguments = @($payload.Arguments) }
$global:LASTEXITCODE = 0
& $payload.Path @parameters @arguments
$succeeded = $?
if ($succeeded) { exit 0 }
if ($LASTEXITCODE -eq 0) { exit 1 }
exit $LASTEXITCODE
'@
    $command = $command.Replace('__DATA__', $data)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $workerArguments = @('-NoLogo', '-NoProfile', '-InputFormat', 'Text', '-OutputFormat', 'Text')
    $interactive = Test-WorkshopBootstrapInteractive
    if (-not $interactive) { $workerArguments += '-NonInteractive' }
    $workerArguments += @('-EncodedCommand', $encoded)
    if ($interactive) {
        # Inherit console handles instead of redirecting the worker through a pipeline.
        $worker = Start-Process -FilePath $executable -ArgumentList $workerArguments -NoNewWindow -Wait -PassThru -ErrorAction Stop
        return $worker.ExitCode
    }
    & $executable @workerArguments | Out-Host
    return $LASTEXITCODE
}

if ($MyInvocation.InvocationName -ne '.') {
    $bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters @{} -RemainingArguments $args
    if ($bootstrap.Handled) { exit $bootstrap.Code }
}
