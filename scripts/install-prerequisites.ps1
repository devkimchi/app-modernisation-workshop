[CmdletBinding()]
param(
    [string]$Track,
    [string]$ContainerEngine,
    [switch]$Update,
    [switch]$Help
)

. (Join-Path $PSScriptRoot 'powershell-bootstrap.ps1')
$bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters $PSBoundParameters -RemainingArguments $args -DotSourced ($MyInvocation.InvocationName -eq '.') -AllowInstall
if ($bootstrap.Handled) { exit $bootstrap.Code }

. (Join-Path $PSScriptRoot 'check-prerequisites.ps1') -Track $Track -ContainerEngine $ContainerEngine -Help:$Help

function Test-AzurePrompt {
    return (Test-WorkshopBootstrapInteractive) -and $Host.Name -eq 'ConsoleHost'
}

function Confirm-AzureAction {
    param([string]$Message)
    if (-not (Test-AzurePrompt)) { return $false }
    return (Read-Host "$Message [y/N]") -cmatch '^[yY]$'
}

function Invoke-AzureAction {
    param([string]$Name, [string[]]$Arguments)
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { Add-Check FAIL 'azure-action' "$Name 실행 파일을 찾지 못했습니다."; return $false }
    & $command.Source @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { Add-Check FAIL 'azure-action' "$Name 실행 실패 (종료 코드 $LASTEXITCODE). 위 오류를 확인하세요."; return $false }
    return $true
}

function Initialize-AzureAccount {
    if (-not (Test-AzurePrompt)) { return }
    $account = Invoke-ToolProbe az @('account', 'show', '--query', 'state', '--output', 'tsv')
    if ($account.Code -ne 0 -or $account.Text -ne 'Enabled') {
        Add-Check WARN 'az-login' "활성 구독 확인 실패 (종료 코드 $($account.Code)): $($account.Text). 미로그인 외에 권한 또는 네트워크 문제일 수도 있습니다."
        if (Confirm-AzureAction '이 셸의 Azure CLI에서 az login을 실행하시겠습니까?') {
            if (-not (Invoke-AzureAction az @('login'))) { return }
        }
    }
    if (Confirm-AzureAction '구독 목록을 조회하고 실습 구독을 직접 선택하시겠습니까?') {
        $subscriptions = Invoke-ToolProbe az @('account', 'list', '--query', '[].[id,name]', '--output', 'tsv')
        if ($subscriptions.Code -ne 0 -or -not $subscriptions.Text) {
            Add-Check WARN 'azure-subscription' "구독 목록 조회 실패: $($subscriptions.Text)"
            return
        }
        Write-Host "구독 ID / 이름:`n$($subscriptions.Text)"
        $selected = Read-Host '변경할 구독 ID (Enter: 유지)'
        if (-not $selected) { return }
        $ids = @($subscriptions.Text -split '\r?\n' | ForEach-Object { ($_ -split "`t", 2)[0] })
        if ($selected -in $ids) { $null = Invoke-AzureAction az @('account', 'set', '--subscription', $selected) }
        else { Add-Check WARN 'azure-subscription' '목록에 없는 구독 ID입니다. 구독을 변경하지 않았습니다.' }
    }
}

function Initialize-ContainerappExtension {
    if (-not (Test-AzurePrompt)) { return }
    $extension = Invoke-ToolProbe az @('extension', 'show', '--name', 'containerapp', '--query', 'version', '--output', 'tsv')
    if ($extension.Code -ne 0 -or -not $extension.Text) {
        Add-Check WARN 'az-containerapp' "확장 조회 실패 (종료 코드 $($extension.Code)): $($extension.Text)"
        if (Confirm-AzureAction 'containerapp 확장을 설치하거나 업데이트하시겠습니까? 로컬 Azure CLI 확장 파일이 변경됩니다.') {
            $null = Invoke-AzureAction az @('extension', 'add', '--name', 'containerapp', '--upgrade')
        }
    }
}

function Initialize-AzdLogin {
    if (-not (Test-AzurePrompt)) { return }
    $login = Invoke-ToolProbe azd @('auth', 'login', '--check-status')
    if ($login.Code -ne 0) {
        Add-Check WARN 'azd-login' "인증 확인 실패 (종료 코드 $($login.Code)): $($login.Text)"
        if (Confirm-AzureAction '이 셸에서 azd auth login을 실행하시겠습니까? Azure CLI 로그인과 별개입니다.') {
            $null = Invoke-AzureAction azd @('auth', 'login')
        }
    }
}

function Initialize-AzureProvider {
    param([string]$Provider)
    if (-not (Test-AzurePrompt)) { return }
    $state = Invoke-ToolProbe az @('provider', 'show', '--namespace', $Provider, '--query', 'registrationState', '--output', 'tsv')
    if ($state.Code -eq 0 -and $state.Text -eq 'Registered') { Add-Check PASS $Provider 'Registered'; return }
    Add-Check WARN $Provider "등록 상태 (종료 코드 $($state.Code)): $($state.Text)"
    if ($state.Code -eq 0 -and $state.Text -in @('NotRegistered', 'Unregistered', 'Registering')) {
        if (Confirm-AzureAction "현재 Azure CLI 구독에 $Provider 공급자를 등록하고 완료를 기다리시겠습니까? 구독 설정이 변경되며 등록 권한이 필요합니다.") {
            $null = Invoke-AzureAction az @('provider', 'register', '--namespace', $Provider, '--wait')
            $state = Invoke-ToolProbe az @('provider', 'show', '--namespace', $Provider, '--query', 'registrationState', '--output', 'tsv')
        }
    }
    if ($state.Code -eq 0 -and $state.Text -eq 'Registered') { Add-Check PASS $Provider 'Registered' }
    else { Add-Check FAIL $Provider "등록을 확인하지 못했습니다 (종료 코드 $($state.Code)): $($state.Text). 대상 구독과 등록 권한을 확인하세요." }
}

function Initialize-AzureEnvironment {
    param([string]$SelectedTrack = 'dotnet')
    $script:CheckResults = [Collections.Generic.List[object]]::new()
    $script:CheckContext = 'Windows PowerShell'
    $previousDynamic = $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL
    try {
        $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = 'no'
        if ((Invoke-ToolProbe az @('version', '--output', 'json')).Code -eq 0) {
            Initialize-AzureAccount
            Initialize-ContainerappExtension
            $account = Invoke-ToolProbe az @('account', 'show', '--query', 'state', '--output', 'tsv')
            if ($account.Code -eq 0 -and $account.Text -eq 'Enabled') {
                Show-AzureIdentity
                $providers = @('Microsoft.App', 'Microsoft.OperationalInsights', 'Microsoft.Storage', 'Microsoft.ContainerRegistry', 'Microsoft.ServiceBus')
                $providers += if ($SelectedTrack -eq 'java') { 'Microsoft.DBforPostgreSQL' } else { 'Microsoft.Sql' }
                foreach ($provider in $providers) {
                    Initialize-AzureProvider $provider
                }
            }
        }
        if ((Invoke-ToolProbe azd @('version')).Code -eq 0) { Initialize-AzdLogin }
    }
    finally { $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = $previousDynamic }
    return @($script:CheckResults | Where-Object Status -eq 'FAIL').Count -eq 0
}

function Confirm-ToolInstall {
    param([string]$Description)
    if (-not (Test-WorkshopBootstrapInteractive)) { return $false }
    Write-Host $Description
    $answer = Read-Host '이 작업을 실행하시겠습니까? [y/N]'
    return $answer -ceq 'y' -or $answer -ceq 'Y'
}

function Update-ProcessPath {
    $existing = @($env:PATH -split ';' | Where-Object { $_ })
    foreach ($scope in @('Machine', 'User')) {
        $paths = [Environment]::GetEnvironmentVariable('Path', $scope) -split ';'
        foreach ($path in $paths) {
            $expanded = [Environment]::ExpandEnvironmentVariables($path.Trim())
            if ($expanded -and $expanded -notin $existing) { $existing += $expanded }
        }
    }
    $env:PATH = $existing -join ';'
    foreach ($name in @('NVM_HOME', 'NVM_SYMLINK')) {
        if (-not [Environment]::GetEnvironmentVariable($name, 'Process')) {
            foreach ($scope in @('User', 'Machine')) {
                $value = [Environment]::GetEnvironmentVariable($name, $scope)
                if ($value) {
                    [Environment]::SetEnvironmentVariable($name, [Environment]::ExpandEnvironmentVariables($value), 'Process')
                    break
                }
            }
        }
    }
}

. (Join-Path $PSScriptRoot 'windows-prerequisite-updates.ps1')

function Install-WorkshopDotnetSdk {
    param([switch]$Update)
    if (-not (Test-WorkshopBootstrapInteractive)) { return $false }
    $sdks = Invoke-ToolProbe dotnet @('--list-sdks')
    $installed = @()
    if ($sdks.Code -eq 0) {
        $installed = @([regex]::Matches($sdks.Text, '(?m)^(10\.\d+\.\d+)\s+\[') |
            ForEach-Object { [version]$_.Groups[1].Value } | Sort-Object -Descending)
    }
    if ($installed.Count -and -not $Update) {
        Write-Host '[INFO] .NET 10 안정 SDK가 있습니다. -Update가 없으므로 업데이트하지 않습니다.'
        return $true
    }
    if (-not $installed.Count) {
        Write-Host "[INFO] .NET 10 안정 SDK를 확인하지 못했습니다 (종료 코드 $($sdks.Code)): $($sdks.Text)"
    }
    if (-not (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Host '[WARN] .NET 10 SDK 자동 설치에는 winget이 필요합니다. 공식 설치 안내: https://dotnet.microsoft.com/download/dotnet/10.0'
        return $true
    }
    $arguments = @('install', '--id', 'Microsoft.DotNet.SDK.10', '--exact', '--source', 'winget')
    $target = $null
    if ($Update) {
        $show = Invoke-ToolProbe winget @('show', '--id', 'Microsoft.DotNet.SDK.10', '--exact', '--source', 'winget', '--versions', '--disable-interactivity')
        $versions = @([regex]::Matches($show.Text, '(?m)^\s*(10\.\d+\.\d+)\s*$') |
            ForEach-Object { [version]$_.Groups[1].Value } | Sort-Object -Descending)
        if ($show.Code -ne 0 -or -not $versions.Count) {
            Write-Host "[FAIL] winget .NET 10 정식 SDK 최신 버전 확인 실패 (종료 코드 $($show.Code)): $($show.Text)"
            return $false
        }
        $target = $versions[0]
        if ($installed.Count -and $installed[0] -ge $target) {
            Write-Host "[PASS] .NET SDK $($installed[0]) 유지 (다운그레이드 없음)."
            return $true
        }
        $arguments += @('--version', "$target")
    }
    if (-not (Confirm-ToolInstall ".NET 10 SDK $target`: Windows 호스트에 winget 패키지 Microsoft.DotNet.SDK.10을 설치하거나 업데이트합니다. 다른 메이저 SDK와 global.json은 변경하지 않습니다. 같은 기능 밴드의 이전 패치는 설치 관리자에 의해 교체될 수 있습니다. 네트워크와 관리자 승인이 필요할 수 있습니다. winget에서 표시하는 약관은 직접 확인하세요.")) {
        Write-Host '[INFO] .NET 10 SDK 설치 또는 업데이트를 건너뜁니다.'
        return $true
    }
    & winget @arguments | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] .NET 10 SDK 설치 실패 (종료 코드 $LASTEXITCODE)."
        return $false
    }
    Update-ProcessPath
    $sdks = Invoke-ToolProbe dotnet @('--list-sdks')
    if ($sdks.Code -ne 0 -or $sdks.Text -notmatch '(?m)^10\.\d+\.\d+\s+\[') {
        Write-Host "[FAIL] 설치 후 .NET 10 안정 SDK를 확인하지 못했습니다 (종료 코드 $($sdks.Code)): $($sdks.Text). PATH와 설치 상태를 확인하세요."
        return $false
    }
    if ($target -and "$($sdks.Text)`n" -notmatch "(?m)^$([regex]::Escape($target.ToString()))\s+\[") {
        Write-Host "[FAIL] 요청한 .NET SDK $target 설치를 확인하지 못했습니다: $($sdks.Text)"
        return $false
    }
    Write-Host '[PASS] .NET 10 안정 SDK 설치를 확인했습니다.'
    return $true
}

function Install-WorkshopJava {
    param([int]$Major, [switch]$Update)
    if (-not (Test-WorkshopBootstrapInteractive)) { return $false }
    if ($Major -notin @(8, 25)) { Write-Host '[FAIL] 지원하는 JDK는 8과 25입니다.'; return $false }
    $existing = Find-WorkshopJava -Major $Major
    if ($existing -and -not $Update) {
        Write-Host "[INFO] Temurin JDK $Major 유지: $($existing.Home)"
        return $true
    }
    if (-not (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Host '[WARN] Temurin 자동 설치에는 winget이 필요합니다. https://adoptium.net/temurin/releases/ 에서 직접 설치하세요.'
        return $true
    }
    $package = "EclipseAdoptium.Temurin.$Major.JDK"
    if (-not (Confirm-ToolInstall "Temurin JDK $Major`: winget $package 패키지를 설치하거나 업데이트합니다. 관리자 승인이 필요하며, ADDLOCAL=FeatureMain으로 시스템 PATH, JAVA_HOME과 파일 연결을 변경하지 않습니다.")) {
        Write-Host "[INFO] Temurin JDK $Major 설치 또는 업데이트를 건너뜁니다."
        return $true
    }
    $verb = if ($existing) { 'upgrade' } else { 'install' }
    & winget $verb --id $package --exact --source winget --custom 'ADDLOCAL=FeatureMain' | Out-Host
    $code = $LASTEXITCODE
    # WinGet reports this status when an installed package is already current.
    if ($code -ne 0 -and -not ($existing -and $code -eq -1978335189)) {
        Write-Host "[FAIL] Temurin JDK $Major 설치 실패 (종료 코드 $code)."
        return $false
    }
    if (-not (Find-WorkshopJava -Major $Major)) {
        Write-Host "[FAIL] 설치 후 Temurin JDK $Major 의 java와 javac를 확인하지 못했습니다."
        return $false
    }
    Write-Host "[PASS] Temurin JDK $Major 설치를 확인했습니다."
    return $true
}

function Install-WindowsTools {
    param([string]$SelectedTrack)
    if (-not (Test-WorkshopBootstrapInteractive)) { return $false }
    $nodeInstalled = Install-WorkshopNode -Update:$Update
    $tools =
        @(
            @{ Command='az'; Package='Microsoft.AzureCLI'; Name='Azure CLI' },
            @{ Command='azd'; Package='Microsoft.Azd'; Name='Azure Developer CLI' },
            @{ Command='gh'; Package='GitHub.cli'; Name='GitHub CLI' },
            @{ Command='modernize'; Package='GitHub.Copilot.modernization.agent'; Name='Modernize CLI' }
        )
    $sdkInstalled = $true
    if ($SelectedTrack -eq 'java') {
        foreach ($major in @(8, 25)) {
            if (-not (Install-WorkshopJava -Major $major -Update:$Update)) { $sdkInstalled = $false }
        }
    }
    else { $sdkInstalled = Install-WorkshopDotnetSdk -Update:$Update }
    $failed = -not $nodeInstalled -or -not $sdkInstalled
    foreach ($tool in $tools) {
        $existing = Get-Command $tool.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($existing) {
            Write-Host "[INFO] $($tool.Name): PATH에서 발견했습니다 ($($existing.Source)). 설치하거나 업데이트하지 않습니다."
            continue
        }
        if (-not (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)) {
            Write-Host "[WARN] $($tool.Name) 자동 설치에는 Windows 패키지 관리자 winget이 필요합니다."
            continue
        }
        if (Confirm-ToolInstall "$($tool.Name): Windows 호스트에 winget 패키지 $($tool.Package)을 설치합니다. 네트워크와 관리자 승인이 필요할 수 있습니다. winget에서 표시하는 약관은 직접 확인하세요.") {
            & winget install --id $tool.Package --exact --source winget | Out-Host
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[FAIL] $($tool.Name) 설치 실패 (종료 코드 $LASTEXITCODE)."
                $failed = $true
            }
            else { Update-ProcessPath }
        }
    }
    return (-not $failed)
}

function Invoke-InstallPrerequisiteMain {
    if ($Help) {
        Write-Host './scripts/install-prerequisites.ps1 -Track java|dotnet [-ContainerEngine docker|podman] [-Update]'
        return 0
    }
    if ($Track -cnotin @('java', 'dotnet')) { Write-Host '[FAIL] -Track java 또는 -Track dotnet을 지정하세요.'; return 2 }
    if (-not $IsWindows) { Write-Host '[FAIL] 이 설치 도우미는 Windows 전용입니다. Java 트랙은 ./scripts/install-prerequisites.sh를 실행하세요.'; return 1 }
    try { $engine = Resolve-ContainerEngine $ContainerEngine }
    catch [ArgumentException] { Write-Host "[FAIL] $($_.Exception.Message)"; return 2 }
    if (-not (Test-WorkshopBootstrapInteractive)) {
        Write-Host '[FAIL] 설치는 대화형 터미널에서만 가능합니다. 비대화형 환경에서는 설치하지 않습니다.'
        return 1
    }
    $hostResult = 0
    if ($Update) {
        $hostResult = Update-WorkshopWindowsHost
        if ($hostResult -eq 3010) { return 1 }
    }
    Write-Host '설치 대상: Windows 호스트. -Update가 없으면 기존 도구는 업데이트하지 않습니다.'
    $installed = Install-WindowsTools $Track
    if ($hostResult -ne 0) { $installed = $false }
    if (-not $installed) {
        Write-Host '[FAIL] 설치 또는 업데이트를 완료하지 못했습니다. 위 안내를 해결한 뒤 다시 실행하세요. 추가 도구 실행은 건너뜁니다.'
        return 1
    }
    $prepared = Initialize-AzureEnvironment -SelectedTrack $Track
    Write-Host '설치와 Azure 준비 후 조회 전용 사전 점검을 실행합니다. 수동 항목은 직접 확인하세요.'
    $result = Invoke-PrerequisiteMain
    if (-not $installed -or -not $prepared -or $result -ne 0) { return 1 }
    return 0
}

if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-InstallPrerequisiteMain) }
